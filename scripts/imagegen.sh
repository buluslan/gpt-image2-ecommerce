#!/usr/bin/env bash
# imagegen.sh - Codex CLI image generation wrapper (hybrid mode)
# Supports: direct CLI mode, HTTP service mode, reference images

set -euo pipefail

CODEX_SERVICE_PORT="${CODEX_IMAGEGEN_PORT:-4312}"
CODEX_SERVICE_URL="http://127.0.0.1:${CODEX_SERVICE_PORT}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.codex/generated_images}"

usage() {
  cat << 'USAGE'
Usage: imagegen.sh [options]

Options:
  -p, --prompt <text>       Prompt text (required for CLI mode)
  -f, --prompt-file <path>  Read prompt from file
  -i, --image <path>        Reference image path (can be repeated)
  -m, --mode <auto|cli|http>  Generation mode (default: auto)
  -o, --output <path>       Output file path
  -t, --timeout <seconds>   Timeout in seconds (default: 180)
  -h, --help                Show this help

Modes:
  auto  - Detect HTTP service, fallback to CLI
  cli   - Always use codex exec directly
  http  - Always use HTTP service
USAGE
}

PROMPT=""
PROMPT_FILE=""
IMAGES=()
MODE="auto"
OUTPUT=""
TIMEOUT=180

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--prompt)      PROMPT="$2"; shift 2 ;;
    -f|--prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    -i|--image)       IMAGES+=("$2"); shift 2 ;;
    -m|--mode)        MODE="$2"; shift 2 ;;
    -o|--output)      OUTPUT="$2"; shift 2 ;;
    -t|--timeout)     TIMEOUT="$2"; shift 2 ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

get_prompt_text() {
  if [[ -n "$PROMPT_FILE" ]]; then
    cat "$PROMPT_FILE"
  elif [[ -n "$PROMPT" ]]; then
    echo "$PROMPT"
  else
    echo "Error: --prompt or --prompt-file required" >&2
    exit 1
  fi
}

check_http_service() {
  curl -sf --max-time 3 "${CODEX_SERVICE_URL}/health" >/dev/null 2>&1
}

generate_via_cli() {
  local prompt_text
  prompt_text="$(get_prompt_text)"

  local wrapper
  if [[ ${#IMAGES[@]} -gt 0 ]]; then
    wrapper="Use imagegen to create an image with this request:
${prompt_text}

Reference image(s) are attached. Use them as visual identity/style references.
Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
  else
    wrapper="Use imagegen to create an image with this request:
${prompt_text}

Requirements:
- Generate the image directly
- Do not provide explanation
- Return only the image result"
  fi

  local cmd=(codex exec --ephemeral --skip-git-repo-check --sandbox read-only --color never)
  for img in "${IMAGES[@]+"${IMAGES[@]}"}"; do
    cmd+=(--image "$img")
  done
  cmd+=(-)

  echo "Running: codex exec (CLI mode)..." >&2
  echo "$wrapper" | "${cmd[@]}"
}

generate_via_http() {
  local prompt_text
  prompt_text="$(get_prompt_text)"

  local json_payload
  json_payload=$(printf '{"prompt":%s' "$(printf '%s' "$prompt_text" | jq -Rs .)")

  if [[ ${#IMAGES[@]} -gt 0 ]]; then
    local images_json
    images_json=$(printf '%s\n' "${IMAGES[@]}" | jq -R . | jq -s .)
    json_payload="${json_payload%,},\"images\":${images_json}}"
  else
    json_payload="${json_payload}}"
  fi

  json_payload="${json_payload%,},\"timeout_sec\":${TIMEOUT}}"

  echo "Submitting to HTTP service at ${CODEX_SERVICE_URL}..." >&2
  local response
  response=$(curl -sf -X POST "${CODEX_SERVICE_URL}/v1/images/generations" \
    -H 'content-type: application/json' \
    -d "$json_payload")

  local job_id
  job_id=$(echo "$response" | jq -r '.job.id // empty')
  if [[ -z "$job_id" ]]; then
    echo "Error: Failed to submit job" >&2
    echo "$response" | jq . >&2
    exit 1
  fi

  echo "Job submitted: $job_id" >&2

  local elapsed=0
  local status=""
  while [[ $elapsed -lt $TIMEOUT ]]; do
    sleep 3
    elapsed=$((elapsed + 3))
    local job_response
    job_response=$(curl -sf "${CODEX_SERVICE_URL}/v1/jobs/${job_id}")
    status=$(echo "$job_response" | jq -r '.job.status')

    if [[ "$status" == "completed" ]]; then
      echo "Generation completed!" >&2
      echo "$job_response" | jq -r '.job.images[]?.path // empty'
      return 0
    elif [[ "$status" == "failed" ]]; then
      echo "Error: Generation failed" >&2
      echo "$job_response" | jq . >&2
      exit 1
    elif [[ "$status" == "promoted" ]]; then
      local new_id
      new_id=$(echo "$job_response" | jq -r '.job.replacementJobId // empty')
      if [[ -n "$new_id" ]]; then
        job_id="$new_id"
        echo "Job promoted to long mode: $job_id" >&2
      fi
    fi

    echo "Status: $status (${elapsed}s/${TIMEOUT}s)" >&2
  done

  echo "Error: Timeout after ${TIMEOUT}s" >&2
  exit 1
}

case "$MODE" in
  auto)
    if check_http_service; then
      echo "HTTP service detected at ${CODEX_SERVICE_URL}" >&2
      generate_via_http
    else
      generate_via_cli
    fi
    ;;
  cli)
    generate_via_cli
    ;;
  http)
    if ! check_http_service; then
      echo "Error: HTTP service not available at ${CODEX_SERVICE_URL}" >&2
      exit 1
    fi
    generate_via_http
    ;;
  *)
    echo "Error: Unknown mode '$MODE'" >&2
    usage
    exit 1
    ;;
esac
