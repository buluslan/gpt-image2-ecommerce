#!/usr/bin/env bash
# imagegen.sh - provider-agnostic image generation wrapper for the
# ecom-image2 skill. The skill's core value is prompt orchestration;
# WHERE images are generated is the user's choice, not baked in here.
#
# Modes:
#   api    (default) any OpenAI-compatible endpoint, env-configured:
#            IMAGE_API_BASE   (default https://api.openai.com)
#            IMAGE_API_KEY    (falls back to legacy $OPENAI_API_KEY)
#            IMAGE_MODEL      (default gpt-image-2.5-flare; e.g. gpt-image-2.5-sunburst)
#          Reference images ride in `image_urls` (data URLs); endpoints that
#          reject that form fall back to the official /v1/images/edits.
#   manual no API at all — exports a prompt pack (prompt.txt + request.json +
#          usage notes) to paste into ChatGPT or curl yourself.
#   cli    DEPRECATED legacy (codex exec).
#
# Other behaviors: 5-slot layered prompt assembly (Scene/Subject/Details/
# Use-case/Constraints); JSON envelope on stdout + JSONL progress on stderr;
# size validation (multiples of 16, side <=3840, ratio <=3:1, total pixels
# 655,360..8,294,400); large inline base64 always spills to a file;
# endpoint-reported cost surfaced in the envelope.
#
# Exit codes:
#   0  Success
#   1  API refused (model declined, content policy, etc.)
#   2  Invalid arguments (missing/invalid prompt, file not found, bad size)
#   3  Quota / rate limited
#   4  Network / service unavailable (HTTP down, timeout, curl failure)
#
# Out of scope: the platform-compliance checker is invoked by Claude
# separately in Step 7; this script stays decoupled from it.

set -euo pipefail

# ---------------------------------------------------------------------------
# Global result state (consumed by the EXIT-trap envelope emitter)
# ---------------------------------------------------------------------------
FINAL_OK=0              # 1 once generation succeeds
FINAL_EXIT_CODE=0       # exit code to report on failure (set by die)
FINAL_ERROR_MSG=""      # human-readable failure message (set by die)
FINAL_IMAGES=()         # collected output image paths / data URIs
SUPPRESS_ENVELOPE=0     # 1 = do NOT emit envelope (used by --help)
RETRY_DONE_INPUT_FIDELITY=0   # guard: retry at most once
MAX_INLINE_BASE64_BYTES=1048576  # 1 MiB; larger b64 spills to a temp file

# Scratch vars used to ferry results out of helper functions (bash 3.2 has no
# lexical scoping; these are intentionally global). Using globals instead of
# command substitution means die() runs in the main shell and can set
# FINAL_EXIT_CODE correctly (a subshell exit would not propagate).
CLI_LAST_OUT=""
CLI_LAST_RC=0
ASSEMBLED_PROMPT=""   # set by get_prompt_text
API_LAST_HTTP_CODE="" # set by api_post_generations* (edits-fallback decision)
API_LAST_BODY=""      # set by api_post_generations*
FINAL_COST=""         # relay-reported cost / official usage string (optional)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OUTPUT_DIR="${OUTPUT_DIR:-$PWD/generated_images}"

# Default e-commerce red-line Constraints injected when caller provides none.
# Covers: commercial quality, no extra text/watermark/logo, anti-AI-tell artifacts.
DEFAULT_CONSTRAINTS="Commercial e-commerce photography quality; sharp focus; realistic natural lighting; no extra text, watermark, or logo unless explicitly specified in the prompt; no AI-tell artifacts (plastic skin, asymmetry, fused edges, extra digits)"

usage() {
  cat << 'USAGE'
Usage: imagegen.sh [options]

Options:
  -p, --prompt <text>         Prompt text (JSON object or plain text)
  -f, --prompt-file <path>    Read prompt from file (JSON object or plain text)
  -i, --image <path>          Reference image path (can be repeated)
  -m, --mode <auto|api|manual|cli>  Generation mode (default: auto)
  -o, --output <path>         Prompt-pack directory (manual mode only;
                              other modes report actual image paths in the
                              envelope)
  -s, --size <WxH>            Output size, e.g. 1024x1024.
                              Constraints: multiples of 16, each side <=3840,
                              aspect ratio 1:3..3:1, total pixels 655,360..8,294,400.
                              >2048 side is experimental (warns).
  -q, --quality <level>       low|medium|high|xhigh|max|auto (GPT-Image-2.5 adds
                              xhigh/max; default: provider default / auto)
  -n, --count <n>             Number of images per request (1-4; endpoint
                              support varies — for larger sets loop the call)
  -t, --timeout <seconds>     Timeout in seconds (default: 180)
  -h, --help                  Show this help

Prompt formats:
  - JSON object: fields parsed into 5 slots (scene/subject/details/use_case/
    constraints). Unknown fields tolerated. See assemble_5slot below.
  - Plain text: passed through verbatim with default Constraints appended.

Modes:
  auto    - api if IMAGE_API_KEY (or legacy OPENAI_API_KEY) is set, else manual
  api     - Any OpenAI-compatible endpoint (official, relay, cloud gateway).
            Env: IMAGE_API_BASE (default https://api.openai.com),
            IMAGE_API_KEY (falls back to OPENAI_API_KEY),
            IMAGE_MODEL (default gpt-image-2.5-flare).
            Reference images go in `image_urls` (data URLs); endpoints that
            reject that form fall back to the official /v1/images/edits.
  manual  - No API call. Exports a prompt pack (prompt.txt + request.json +
            usage notes) to the output directory — paste into ChatGPT or
            curl any endpoint yourself.
  cli     - DEPRECATED legacy (codex exec).

Output (stdout):
  Single JSON envelope:
    success: {"ok":true, "data":{"images":["path1", ...], "cost":"..."}}
             (cost present only when the endpoint reports one)
    failure: {"ok":false, "error":{"code":<exit_code>, "message":"..."}}

  Progress / diagnostics are emitted to stderr as JSONL, one event per line:
    {"event":"submit", "ts":1700000000, "data":"mode=api"}

Exit codes (also mirrored in error.code):
  0  Success
  1  API refused (model declined, content policy)
  2  Invalid arguments (bad prompt / file / size / mode)
  3  Quota / rate limited
  4  Network / service unavailable
USAGE
}

# ---------------------------------------------------------------------------
# log_event: emit a JSONL progress event to stderr.
# Arguments: type [data-string]
# ---------------------------------------------------------------------------
log_event() {
  local type="$1"
  local data="${2:-}"
  local ts
  ts=$(date +%s 2>/dev/null || echo 0)
  if [[ -n "$data" ]]; then
    jq -nc --arg e "$type" --argjson ts "$ts" --arg d "$data" \
      '{event:$e, ts:$ts, data:$d}' >&2 2>/dev/null \
      || printf '{"event":"%s","ts":%s,"data":%s}\n' \
           "$type" "$ts" "$(printf '%s' "$data" | jq -Rs . 2>/dev/null || echo '""')" >&2
  else
    jq -nc --arg e "$type" --argjson ts "$ts" \
      '{event:$e, ts:$ts}' >&2 2>/dev/null \
      || printf '{"event":"%s","ts":%s}\n' "$type" "$ts" >&2
  fi
}

# ---------------------------------------------------------------------------
# emit_envelope: EXIT trap. Emits the final JSON envelope on stdout.
# Success when FINAL_OK=1, failure otherwise. Always returns 0.
# ---------------------------------------------------------------------------
emit_envelope() {
  local rc=$?
  set +e  # never recurse / re-trip inside the trap
  if [[ "${SUPPRESS_ENVELOPE:-0}" == "1" ]]; then
    return 0
  fi
  if [[ "${FINAL_OK:-0}" == "1" ]]; then
    local imgs_json="[]"
    if [[ "${#FINAL_IMAGES[@]}" -gt 0 ]]; then
      imgs_json=$(printf '%s\n' "${FINAL_IMAGES[@]}" | jq -R . 2>/dev/null | jq -s . 2>/dev/null || echo "[]")
    fi
    if [[ -n "${FINAL_COST:-}" ]]; then
      jq -nc --argjson images "$imgs_json" --arg cost "$FINAL_COST" \
        '{ok:true, data:{images:$images, cost:$cost}}' 2>/dev/null \
        || printf '{"ok":true,"data":{"images":[]}}'
    else
      jq -nc --argjson images "$imgs_json" '{ok:true, data:{images:$images}}' 2>/dev/null \
        || printf '{"ok":true,"data":{"images":[]}}'
    fi
  else
    # Prefer FINAL_EXIT_CODE (set by die); fall back to the real exit status
    # captured by the trap (covers raw set -e failures that bypassed die).
    local code="${FINAL_EXIT_CODE:-1}"
    if [[ "$code" == "0" && "$rc" != "0" ]]; then
      code="$rc"
    fi
    # Clamp to the documented 0-4 range; anything else becomes generic failure.
    case "$code" in
      0|1|2|3|4) ;;
      *) code=1 ;;
    esac
    [[ "$code" == "0" ]] && code=1   # 0 here means we failed without setting a code
    local msg="${FINAL_ERROR_MSG:-generation failed}"
    jq -nc --argjson code "$code" --arg msg "$msg" \
      '{ok:false, error:{code:$code, message:$msg}}' 2>/dev/null \
      || printf '{"ok":false,"error":{"code":1,"message":"generation failed"}}'
  fi
  return 0
}

# die <code> <message>: record failure state and exit (triggers emit_envelope).
die() {
  FINAL_EXIT_CODE="$1"
  FINAL_ERROR_MSG="$2"
  exit "$1"
}

trap emit_envelope EXIT

# ---------------------------------------------------------------------------
# validate_size: GPT-Image-2/2.5 hard constraints.
#   Rule 1: both dimensions must be multiples of 16
#   Rule 2: each side <=3840px
#   Rule 3: aspect ratio (long/short) <=3:1
#   Rule 4: total pixels within 655,360..8,294,400 (2.5 spec)
#   Rule 5: side >2048 -> stderr warning (non-blocking, experimental)
# Violations of rules 1-4 exit 2 (via die) with message.
# ---------------------------------------------------------------------------
validate_size() {
  local size="$1"
  if ! [[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    die 2 "--size must be WxH (e.g. 1024x1024), got '$size'"
  fi
  local w="${BASH_REMATCH[1]}"
  local h="${BASH_REMATCH[2]}"

  # Rule 1: multiples of 16
  if (( w % 16 != 0 || h % 16 != 0 )); then
    die 2 "size dimensions must be multiples of 16 (gpt-image spec), got ${w}x${h}"
  fi

  # Rule 2: each side <=3840
  if (( w > 3840 || h > 3840 )); then
    die 2 "size side must be <=3840px, got ${w}x${h}"
  fi

  # Rule 3: aspect ratio <=3:1
  local long short
  if (( w >= h )); then long=$w; short=$h; else long=$h; short=$w; fi
  if (( short == 0 )); then
    die 2 "zero dimension in size ${w}x${h}"
  fi
  if (( long > short * 3 )); then
    local ratio
    ratio=$(awk -v l="$long" -v s="$short" 'BEGIN{printf "%.2f", l/s}')
    die 2 "aspect ratio must be <=3:1, got ${w}x${h} (ratio ${ratio}:1)"
  fi

  # Rule 4: total pixels (2.5 spec: 655,360..8,294,400)
  local pixels=$(( w * h ))
  if (( pixels < 655360 || pixels > 8294400 )); then
    die 2 "total pixels must be within 655,360..8,294,400, got ${w}x${h} (${pixels})"
  fi

  # Rule 5: >2048 experimental warning (non-blocking)
  if (( w > 2048 || h > 2048 )); then
    log_event "size_warning" "size ${w}x${h} exceeds 2048 on one side; experimental, results may be unstable"
  fi
}

# Peek size from JSON prompt's `size` field (string "WxH" form only).
# Used when --size is not provided but JSON prompt carries a size.
peek_size_from_prompt() {
  local raw=""
  if [[ -n "${PROMPT_FILE:-}" && -f "$PROMPT_FILE" ]]; then
    raw="$(cat "$PROMPT_FILE")"
  elif [[ -n "${PROMPT:-}" ]]; then
    raw="$PROMPT"
  fi
  [[ -z "$raw" ]] && return 0
  if echo "$raw" | jq -e 'type == "object" and (.size | type == "string")' >/dev/null 2>&1; then
    echo "$raw" | jq -r '.size'
  fi
}

# ---------------------------------------------------------------------------
# assemble_5slot: flatten a JSON prompt template or plain
# text into 5 layered slots before sending to codex / HTTP service.
#   [Scene]            scene_type / composition / view / camera
#   [Subject]          subject / product
#   [Important details] materials / features / selling_points / colors
#   [Use case]         platform / region / purpose
#   [Constraints]      hard constraints (defaults injected if absent)
# JSON input  -> fields parsed per slot, unknown fields tolerated.
# Plain text  -> passed through verbatim + default Constraints appended.
# Always appends [Output] size hint when SIZE is resolved.
# ---------------------------------------------------------------------------
assemble_5slot() {
  local raw="$1"

  if echo "$raw" | jq -e 'type == "object"' >/dev/null 2>&1; then
    local scene subject details usecase constraints

    scene=$(echo "$raw" | jq -r '
      [ (.scene // .scene_type // .composition // .view // empty),
        (.camera // .angle // empty) ]
      | map(select(. != null and . != ""))
      | join(" / ")
    ' 2>/dev/null || echo "")
    subject=$(echo "$raw" | jq -r '
      [ (.subject // .product // .product_description // empty) ]
      | map(select(. != null and . != ""))
      | join(" / ")
    ' 2>/dev/null || echo "")
    details=$(echo "$raw" | jq -r '
      [ (.details // .important_details // empty),
        (.materials // empty),
        (.features // .selling_points // empty),
        (.colors // .palette // empty) ]
      | map(select(. != null and . != ""))
      | join(" / ")
    ' 2>/dev/null || echo "")
    usecase=$(echo "$raw" | jq -r '
      [ (.use_case // .usecase // empty),
        (.platform // empty),
        (.region // empty),
        (.purpose // empty) ]
      | map(select(. != null and . != ""))
      | join(" / ")
    ' 2>/dev/null || echo "")
    constraints=$(echo "$raw" | jq -r '
      [ (.constraints // .platform_constraints // .hard_constraints // empty) ]
      | map(select(. != null and . != ""))
      | join(" / ")
    ' 2>/dev/null || echo "")

    # Force-inject default Constraints if caller provided none.
    if [[ -z "$constraints" ]]; then
      constraints="$DEFAULT_CONSTRAINTS"
    fi

    local out=""
    [[ -n "$scene" ]]     && out+=$'[Scene] '"$scene"$'\n'
    [[ -n "$subject" ]]   && out+=$'[Subject] '"$subject"$'\n'
    [[ -n "$details" ]]   && out+=$'[Important details] '"$details"$'\n'
    [[ -n "$usecase" ]]   && out+=$'[Use case] '"$usecase"$'\n'
    out+=$'[Constraints] '"$constraints"
    [[ -n "$SIZE" ]]      && out+=$'\n'"[Output] target size ${SIZE}px"
    echo "$out"
  else
    # Plain text: pass through verbatim + append default Constraints.
    local out="$raw"
    out+=$'\n\n[Constraints] '"$DEFAULT_CONSTRAINTS"
    [[ -n "$SIZE" ]] && out+=$'\n'"[Output] target size ${SIZE}px"
    echo "$out"
  fi
}

# ---------------------------------------------------------------------------
# get_prompt_text: read raw prompt from
# --prompt-file or --prompt, validate presence, run through assemble_5slot,
# and store the result in the global ASSEMBLED_PROMPT. Uses a global instead
# of stdout so that die() runs in the main shell (not a command-substitution
# subshell) and FINAL_EXIT_CODE is set correctly.
# ---------------------------------------------------------------------------
get_prompt_text() {
  local raw
  if [[ -n "${PROMPT_FILE:-}" ]]; then
    if [[ ! -f "$PROMPT_FILE" ]]; then
      die 2 "prompt file not found: $PROMPT_FILE"
    fi
    raw="$(cat "$PROMPT_FILE")"
  elif [[ -n "${PROMPT:-}" ]]; then
    raw="$PROMPT"
  else
    die 2 "--prompt or --prompt-file required"
  fi
  ASSEMBLED_PROMPT="$(assemble_5slot "$raw")"
}

# ---------------------------------------------------------------------------
# input_fidelity refusal handling (cli channel).
#   is_input_fidelity_rejection <text> -> 0 if text mentions input_fidelity
#     in a way that looks like a model/provider rejection.
#   strip_input_fidelity <text> -> text with input_fidelity references removed.
# ---------------------------------------------------------------------------
is_input_fidelity_rejection() {
  local text="$1"
  [[ -z "$text" ]] && return 1
  # Match input_fidelity / input-fidelity / inputFidelity (case-insensitive),
  # appearing alongside refusal-ish words.
  if echo "$text" | grep -iE 'input[_-]?fidelity' >/dev/null 2>&1; then
    # Narrow: only treat as param-rejection when a refusal/error signal is near.
    if echo "$text" | grep -iE '(unsupported|unknown|unrecognized|invalid|not supported|error|refus|fail|cannot|could not)' >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

strip_input_fidelity() {
  local text="$1"
  echo "$text" \
    | sed -E 's/[Ii]nput[_-]?[Ff]idelity[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_]+[,;.]?[[:space:]]*//g' \
    | sed -E 's/[Ii]nput[_-]?[Ff]idelity[,;.]?[[:space:]]*//g' \
    | sed -E 's/[[:space:]]{2,}/ /g' \
    | sed -E 's/[[:space:]]+$//'
}

# ---------------------------------------------------------------------------
# spill_base64_to_file <b64> <ext>: decode base64 to a temp file and echo its
# file:// URL. Used when an inline b64_json is too large for the envelope.
# ---------------------------------------------------------------------------
spill_base64_to_file() {
  local b64="$1"
  local ext="${2:-png}"
  case "$ext" in
    png|jpg|jpeg|webp) ;;
    *) ext="png" ;;
  esac
  local tmp
  tmp=$(mktemp -t imagegen.XXXXXX 2>/dev/null || return 1) || return 1
  rm -f "$tmp"  # mktemp made an empty file; re-add the chosen extension
  tmp="${tmp}.${ext}"
  if ! printf '%s' "$b64" | base64 -d > "$tmp" 2>/dev/null; then
    # BSD base64 uses -D; retry for older macOS.
    if ! printf '%s' "$b64" | base64 -D > "$tmp" 2>/dev/null; then
      rm -f "$tmp"
      return 1
    fi
  fi
  echo "file://${tmp}"
}

# ---------------------------------------------------------------------------
# classify_failure_text: map a failure text to an exit
# code. Defaults to 1 (API refusal).
# ---------------------------------------------------------------------------
classify_failure_text() {
  local text="$1"
  if [[ "$text" =~ (rate.?limit|quota|429|too.?many.?requests) ]]; then
    echo 3
  elif [[ "$text" =~ (timeout|timed.?out|unreachable|connection|network) ]]; then
    echo 4
  else
    echo 1
  fi
}

# ===========================================================================
# CLI channel (DEPRECATED legacy — kept for backward compatibility)
# ===========================================================================

# cli_run_once <prompt-text>: invoke codex exec once, capturing combined
# stdout+stderr into CLI_LAST_OUT and exit code into CLI_LAST_RC. The captured
# text is also re-streamed to stderr as progress so humans can follow along.
cli_run_once() {
  local pt="$1"
  local wrapper
  if [[ ${#IMAGES[@]} -gt 0 ]]; then
    wrapper="Use imagegen to create an image with this request:
${pt}

Reference image(s) are attached. Use them as visual identity/style references.
Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
  else
    wrapper="Use imagegen to create an image with this request:
${pt}

Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
  fi

  local cmd=(codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never)
  local img
  for img in "${IMAGES[@]+"${IMAGES[@]}"}"; do
    cmd+=(--image "$img")
  done
  cmd+=(-)

  log_event "submit" "mode=cli"
  local out rc=0
  # Capture combined output; codex's own progress thus lands in $out, which we
  # re-emit to stderr below so stdout stays reserved for the final envelope.
  out=$(printf '%s' "$wrapper" | "${cmd[@]}" 2>&1) || rc=$?
  CLI_LAST_OUT="$out"
  CLI_LAST_RC="$rc"
  # Re-stream captured output to stderr as human-readable progress.
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out" >&2
  fi
}

# generate_via_cli: run codex exec, with input_fidelity-rejection retry.
# On success, best-effort extract image paths from codex output into
# FINAL_IMAGES and mark FINAL_OK=1.
generate_via_cli() {
  get_prompt_text
  local prompt_text="$ASSEMBLED_PROMPT"

  cli_run_once "$prompt_text"

  if (( CLI_LAST_RC != 0 )); then
    if is_input_fidelity_rejection "$CLI_LAST_OUT" && (( RETRY_DONE_INPUT_FIDELITY == 0 )); then
      RETRY_DONE_INPUT_FIDELITY=1
      log_event "input_fidelity_retry" "cli rejection mentioned input_fidelity; retrying without it"
      prompt_text=$(strip_input_fidelity "$prompt_text")
      cli_run_once "$prompt_text"
    fi
    if (( CLI_LAST_RC != 0 )); then
      die 1 "codex exec failed (exit $CLI_LAST_RC)"
    fi
  fi

  # Best-effort: harvest anything that looks like an image path/URL from the
  # codex output. codex typically prints something like "Image saved to /path.png".
  local paths
  paths=$(echo "$CLI_LAST_OUT" | grep -oE '(/[^[:space:]]+\.(png|jpg|jpeg|webp)|https?://[^[:space:]]+\.(png|jpg|jpeg|webp))' 2>/dev/null || true)
  if [[ -n "$paths" ]]; then
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && FINAL_IMAGES+=("$line")
    done <<< "$paths"
  fi

  FINAL_OK=1
  exit 0
}

# ===========================================================================
# API channel (any OpenAI-compatible endpoint)
#   POST {IMAGE_API_BASE}/v1/images/generations
#   Body: {model, prompt, size?, quality?, n:1, image_urls?: [...]}
#   Reference images ride in `image_urls` as data URLs (relay-common form).
#   Endpoints that reject `image_urls` with a 4xx are retried once against
#   the official /v1/images/edits multipart form — both dialects, one wrapper.
#   Response: {data:[{b64_json|url}]} (+ optional cost/usage surfaced in envelope).
# ===========================================================================

# Resolve credentials: IMAGE_API_* wins; legacy OPENAI_* respected.
api_base()  { echo "${IMAGE_API_BASE:-${OPENAI_BASE:-https://api.openai.com}}"; }
api_key()   { echo "${IMAGE_API_KEY:-${OPENAI_API_KEY:-}}"; }
api_model() { echo "${IMAGE_MODEL:-gpt-image-2.5-flare}"; }

# build_image_urls_json: turn local image files into data URLs, emit a JSON
# array. Dies (exit 2) on missing files. Body file avoids argv length limits.
build_image_urls_json() {
  local img b64 mime
  local first=1
  printf '['
  for img in "${IMAGES[@]+"${IMAGES[@]}"}"; do
    [[ -f "$img" ]] || die 2 "reference image not found: $img"
    case "${img##*.}" in
      jpg|jpeg) mime="image/jpeg" ;;
      webp)     mime="image/webp" ;;
      *)        mime="image/png" ;;
    esac
    b64=$(base64 -i "$img" 2>/dev/null) || b64=$(base64 "$img" 2>/dev/null)
    [[ -z "$b64" ]] && die 2 "failed to base64-encode reference image: $img"
    (( first )) || printf ','
    first=0
    printf '"data:%s;base64,%s"' "$mime" "$b64"
  done
  printf ']'
}

# collect_api_response <resp_body>: parse images (b64_json or url) into
# FINAL_IMAGES; surface relay-reported cost into FINAL_COST when present.
collect_api_response() {
  local resp_body="$1"
  local n i item b64 url
  n=$(echo "$resp_body" | jq -r '.data | length' 2>/dev/null || echo 0)
  [[ -z "$n" || "$n" == "null" ]] && n=0
  for (( i=0; i<n; i++ )); do
    b64=$(echo "$resp_body" | jq -r ".data[$i].b64_json // empty" 2>/dev/null || true)
    url=$(echo "$resp_body" | jq -r ".data[$i].url // empty" 2>/dev/null || true)
    if [[ -n "$b64" ]]; then
      # Spill anything beyond a safe envelope size: giant inline data URIs
      # break the envelope's jq pipeline (observed: 800k-char b64 rendered
      # as images:[] silently). 100k b64 chars (~75KB image) is the safe line.
      local b64_len=${#b64}
      if (( b64_len > 100000 )); then
        log_event "api_base64_spill" "image[$i] b64=${b64_len} chars; spilling to file"
        local spilled
        if spilled=$(spill_base64_to_file "$b64" "png"); then
          FINAL_IMAGES+=("$spilled")
        else
          FINAL_IMAGES+=("data:image/png;base64,${b64}")
        fi
      else
        FINAL_IMAGES+=("data:image/png;base64,${b64}")
      fi
    elif [[ -n "$url" ]]; then
      local tmp
      tmp=$(mktemp -t imagegen_api.XXXXXX 2>/dev/null) || die 4 "mktemp failed"
      rm -f "$tmp"; tmp="${tmp}.png"
      if ! curl -sS "$url" -o "$tmp" --max-time 120 2>/dev/null; then
        rm -f "$tmp"
        die 4 "output download failed (url=$url); note some relays expire URLs quickly"
      fi
      FINAL_IMAGES+=("$tmp")
    fi
  done
  (( ${#FINAL_IMAGES[@]} == 0 )) && \
    die 1 "endpoint returned no images: $(echo "$resp_body" | head -c 200)"
  # Surface relay-reported cost (relay cost/credits_cost fields, official usage).
  FINAL_COST=$(echo "$resp_body" | jq -r '
    (.cost // .credits_cost // .data[0].cost //
     (if .usage then ("input_tokens=" + (.usage.input_tokens|tostring) +
                      " output_tokens=" + (.usage.output_tokens|tostring)) else empty end)
    ) // empty' 2>/dev/null || true)
  [[ -n "$FINAL_COST" ]] && log_event "api_cost" "$FINAL_COST"
}

# api_post_generations <body-file>: POST the JSON body file; on success feed
# the response to collect_api_response. Returns non-zero (via die) on failure.
# Sets API_LAST_HTTP_CODE / API_LAST_BODY for the edits-fallback decision.
api_post_generations() {
  local body_file="$1"
  local base; base=$(api_base)
  local response http_code resp_body
  response=$(curl -sS -w '\n%{http_code}' -X POST "${base}/v1/images/generations" \
    -H "Authorization: Bearer $(api_key)" \
    -H "Content-Type: application/json" \
    --data-binary "@${body_file}" --max-time "$TIMEOUT" 2>/dev/null) || \
    die 4 "cannot reach endpoint ${base}"

  http_code=$(echo "$response" | tail -n1)
  resp_body=$(echo "$response" | sed '$d')
  API_LAST_HTTP_CODE="$http_code"
  API_LAST_BODY="$resp_body"

  case "$http_code" in
    2*) collect_api_response "$resp_body" ;;
    401|403) die 1 "auth failed (HTTP $http_code); check IMAGE_API_KEY" ;;
    429) die 3 "rate limited / quota exceeded (HTTP 429)" ;;
    4*|5*) die 1 "endpoint error (HTTP $http_code): $(echo "$resp_body" | head -c 200)" ;;
    *) die 4 "unexpected HTTP status $http_code" ;;
  esac
}

# api_post_edits <prompt> [model]: official multipart /v1/images/edits fallback
# for endpoints that reject `image_urls` on generations (e.g. official OpenAI).
api_post_edits() {
  local prompt_text="$1"
  local base; base=$(api_base)
  local model; model=$(api_model)
  local args=(
    -sS -w '\n%{http_code}' -X POST "${base}/v1/images/edits"
    -H "Authorization: Bearer $(api_key)"
    -F "model=${model}"
    -F "prompt=${prompt_text}"
  )
  [[ -n "$SIZE" ]] && args+=(-F "size=${SIZE}")
  [[ -n "$QUALITY" ]] && args+=(-F "quality=${QUALITY}")
  local img
  for img in "${IMAGES[@]+"${IMAGES[@]}"}"; do
    args+=(-F "image[]=@${img}")
  done
  args+=(--max-time "$TIMEOUT")

  local response http_code resp_body
  response=$(curl "${args[@]}" 2>/dev/null) || die 4 "edits request failed (transport)"
  http_code=$(echo "$response" | tail -n1)
  resp_body=$(echo "$response" | sed '$d')

  case "$http_code" in
    2*) collect_api_response "$resp_body" ;;
    401|403) die 1 "auth failed (HTTP $http_code); check IMAGE_API_KEY" ;;
    429) die 3 "rate limited / quota exceeded (HTTP 429)" ;;
    *) die 1 "edits fallback failed (HTTP $http_code): $(echo "$resp_body" | head -c 200)" ;;
  esac
}

generate_via_api() {
  local key; key=$(api_key)
  [[ -z "$key" ]] && \
    die 2 "IMAGE_API_KEY (or legacy OPENAI_API_KEY) not set; cannot use --mode api. Use --mode manual to export a prompt pack instead."

  get_prompt_text
  local prompt_text="$ASSEMBLED_PROMPT"
  local model; model=$(api_model)

  log_event "submit" "mode=api base=$(api_base) model=${model} quality=${QUALITY:-auto}"

  # Build JSON body in a temp file (data URLs for reference images can be MBs).
  local body_file
  body_file=$(mktemp -t imagegen_body.XXXXXX.json 2>/dev/null) || die 4 "mktemp failed"
  {
    printf '{"model":%s,"prompt":%s,"n":%s' \
      "$(printf '%s' "$model" | jq -Rs .)" "$(printf '%s' "$prompt_text" | jq -Rs .)" "$COUNT"
    [[ -n "$SIZE" ]] && printf ',"size":"%s"' "$SIZE"
    [[ -n "$QUALITY" ]] && printf ',"quality":"%s"' "$QUALITY"
    if [[ ${#IMAGES[@]} -gt 0 ]]; then
      printf ',"image_urls":'
      build_image_urls_json
    fi
    printf '}'
  } > "$body_file"

  API_LAST_HTTP_CODE=""
  if [[ ${#IMAGES[@]} -gt 0 ]]; then
    # Try relay-common form first; on a 4xx that mentions image_urls/unknown
    # field, fall back to the official edits multipart. Other hard failures
    # (auth/quota/5xx) die here — they must not be mistaken for success.
    api_post_generations_soft "$body_file" || true
    if [[ "$API_LAST_HTTP_CODE" =~ ^2 ]]; then
      :  # collected already
    elif [[ "$API_LAST_HTTP_CODE" =~ ^4 ]] && \
         echo "$API_LAST_BODY" | grep -qiE 'image_urls|unknown (field|parameter)|unrecognized|not supported'; then
      log_event "api_edits_fallback" "generations rejected image_urls (HTTP $API_LAST_HTTP_CODE); retrying via /v1/images/edits"
      rm -f "$body_file"
      api_post_edits "$prompt_text"
    else
      case "$API_LAST_HTTP_CODE" in
        401|403) die 1 "auth failed (HTTP $API_LAST_HTTP_CODE); check IMAGE_API_KEY" ;;
        429) die 3 "rate limited / quota exceeded (HTTP 429)" ;;
        *) die 1 "endpoint error (HTTP ${API_LAST_HTTP_CODE:-none}): $(echo "$API_LAST_BODY" | head -c 200)" ;;
      esac
    fi
  else
    api_post_generations "$body_file"
  fi
  rm -f "$body_file"

  FINAL_OK=1
  exit 0
}

# api_post_generations_soft: like api_post_generations but records 4xx into
# API_LAST_* instead of dying, so the caller can decide on the edits fallback.
api_post_generations_soft() {
  local body_file="$1"
  local base; base=$(api_base)
  local response http_code resp_body
  if ! response=$(curl -sS -w '\n%{http_code}' -X POST "${base}/v1/images/generations" \
      -H "Authorization: Bearer $(api_key)" \
      -H "Content-Type: application/json" \
      --data-binary "@${body_file}" --max-time "$TIMEOUT" 2>/dev/null); then
    die 4 "cannot reach endpoint ${base}"
  fi
  http_code=$(echo "$response" | tail -n1)
  resp_body=$(echo "$response" | sed '$d')
  API_LAST_HTTP_CODE="$http_code"
  API_LAST_BODY="$resp_body"
  if [[ "$http_code" =~ ^2 ]]; then
    collect_api_response "$resp_body"
    return 0
  fi
  return 1
}

# ===========================================================================
# Manual mode (zero-channel degradation path)
#   No API call. Exports a prompt pack for the user to run anywhere:
#   paste into ChatGPT, or curl any OpenAI-compatible endpoint themselves.
# ===========================================================================
generate_via_manual() {
  get_prompt_text
  local prompt_text="$ASSEMBLED_PROMPT"
  local model; model=$(api_model)

  local pack_dir
  if [[ -n "$OUTPUT" ]]; then
    pack_dir="$OUTPUT"
    mkdir -p "$pack_dir"
  else
    pack_dir="${OUTPUT_DIR}/prompt-pack-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$pack_dir"
  fi

  printf '%s\n' "$prompt_text" > "${pack_dir}/prompt.txt"

  {
    printf '{"model":%s,"prompt":%s,"n":%s' \
      "$(printf '%s' "$model" | jq -Rs .)" "$(printf '%s' "$prompt_text" | jq -Rs .)" "$COUNT"
    [[ -n "$SIZE" ]] && printf ',"size":"%s"' "$SIZE"
    [[ -n "$QUALITY" ]] && printf ',"quality":"%s"' "$QUALITY"
    printf '}\n'
  } > "${pack_dir}/request.json"

  cat > "${pack_dir}/HOW-TO-USE.txt" << 'NOTES'
This is an exported prompt pack — no API was called.

Three ways to use it:
1. Paste prompt.txt into ChatGPT (attach your reference images in the same
   message, in the same order the prompt references them).
2. curl any OpenAI-compatible endpoint with request.json:
     curl $IMAGE_API_BASE/v1/images/generations \
       -H "Authorization: Bearer $IMAGE_API_KEY" \
       -H "Content-Type: application/json" \
       --data-binary @request.json
   Works with the official OpenAI API and OpenAI-compatible relays/gateways
   alike — set IMAGE_API_BASE/IMAGE_API_KEY to whichever you use.
   For reference-image edits on the official API, use /v1/images/edits with
   multipart -F "image[]=@your-image.png" instead of image_urls.
3. Edit model/size/quality in request.json to match your endpoint's options
   (e.g. gpt-image-2.5-sunburst for precision edits that must preserve
   product labels/logos; gpt-image-2.5-flare for fast bulk generation).
NOTES

  log_event "manual_pack_exported" "dir=${pack_dir}"
  FINAL_IMAGES+=("${pack_dir}")
  FINAL_OK=1
  exit 0
}

# ===========================================================================
# Argument parsing
# ===========================================================================

PROMPT=""
PROMPT_FILE=""
IMAGES=()
MODE="auto"
OUTPUT=""
SIZE=""
QUALITY=""
COUNT=1
TIMEOUT=180

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--prompt)      PROMPT="$2"; shift 2 ;;
    -f|--prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    -i|--image)       IMAGES+=("$2"); shift 2 ;;
    -m|--mode)        MODE="$2"; shift 2 ;;
    -o|--output)      OUTPUT="$2"; shift 2 ;;
    -s|--size)        SIZE="$2"; shift 2 ;;
    -q|--quality)     QUALITY="$2"; shift 2 ;;
    -n|--count)       COUNT="$2"; shift 2 ;;
    -t|--timeout)     TIMEOUT="$2"; shift 2 ;;
    -h|--help)        SUPPRESS_ENVELOPE=1; usage; exit 0 ;;
    *)                die 2 "unknown option: $1" ;;
  esac
done

# Validate quality early (2.5 ladder; providers may ignore unknown levels).
if [[ -n "$QUALITY" ]] && ! [[ "$QUALITY" =~ ^(low|medium|high|xhigh|max|auto)$ ]]; then
  die 2 "--quality must be one of low|medium|high|xhigh|max|auto, got '$QUALITY'"
fi
if ! [[ "$COUNT" =~ ^[1-4]$ ]]; then
  die 2 "--count must be 1-4 (loop the call for larger sets), got '$COUNT'"
fi

# ---------------------------------------------------------------------------
# Resolve effective size: explicit --size wins, else peek from JSON prompt.
# ---------------------------------------------------------------------------
if [[ -z "$SIZE" ]]; then
  PEEKED_SIZE="$(peek_size_from_prompt || true)"
  if [[ -n "${PEEKED_SIZE:-}" ]]; then
    SIZE="$PEEKED_SIZE"
  fi
fi
if [[ -n "$SIZE" ]]; then
  validate_size "$SIZE"
fi

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
case "$MODE" in
  auto)
    if [[ -n "${IMAGE_API_KEY:-}" || -n "${OPENAI_API_KEY:-}" ]]; then
      log_event "mode_resolved" "auto -> api (IMAGE_API_KEY/OPENAI_API_KEY detected)"
      generate_via_api
    else
      log_event "mode_resolved" "auto -> manual (no API key; zero-channel path)"
      generate_via_manual
    fi
    ;;
  api)
    log_event "mode_resolved" "api"
    generate_via_api
    ;;
  manual)
    log_event "mode_resolved" "manual"
    generate_via_manual
    ;;
  cli)
    log_event "mode_resolved" "cli (DEPRECATED)"
    log_event "deprecation" "cli mode is deprecated legacy; set IMAGE_API_KEY or use --mode manual"
    generate_via_cli
    ;;
  *)
    die 2 "unknown mode '$MODE' (expected auto|api|manual|cli)"
    ;;
esac
