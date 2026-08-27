#!/usr/bin/env bash
# imagegen.sh - Codex CLI image generation wrapper (hybrid mode)
# Supports: direct CLI mode, HTTP service mode, optional Atlas Cloud mode,
# reference images

set -euo pipefail

CODEX_SERVICE_PORT="${CODEX_IMAGEGEN_PORT:-4312}"
CODEX_SERVICE_URL="http://127.0.0.1:${CODEX_SERVICE_PORT}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.codex/generated_images}"
ATLAS_BASE_URL="${ATLASCLOUD_API_BASE_URL:-https://api.atlascloud.ai/api/v1}"
ATLAS_TEXT_MODEL="${ATLASCLOUD_TEXT_MODEL:-openai/gpt-image-2/text-to-image}"
ATLAS_EDIT_MODEL="${ATLASCLOUD_EDIT_MODEL:-openai/gpt-image-2/edit}"
ATLAS_IMAGE_SIZE="${ATLASCLOUD_IMAGE_SIZE:-1024x1024}"
ATLAS_IMAGE_QUALITY="${ATLASCLOUD_IMAGE_QUALITY:-medium}"
ATLAS_OUTPUT_FORMAT="${ATLASCLOUD_OUTPUT_FORMAT:-jpeg}"

usage() {
  cat << 'USAGE'
Usage: imagegen.sh [options]

Options:
  -p, --prompt <text>       Prompt text (required for CLI mode)
  -f, --prompt-file <path>  Read prompt from file
  -i, --image <path>        Reference image path (can be repeated)
  -m, --mode <auto|cli|http|atlas>  Generation mode (default: auto)
  -o, --output <path>       Output file path
  -t, --timeout <seconds>   Timeout in seconds (default: 180)
  -h, --help                Show this help

Modes:
  auto  - Detect HTTP service, fallback to CLI
  cli   - Always use codex exec directly
  http  - Always use HTTP service
  atlas - Use Atlas Cloud (requires ATLASCLOUD_API_KEY)
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

require_atlas_dependency() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: Atlas mode requires '$command_name'" >&2
    exit 1
  fi
}

atlas_curl() {
  # Pass the token over stdin so it is not exposed in the curl process argv.
  printf 'header = "Authorization: Bearer %s"\n' "$ATLASCLOUD_API_KEY" |
    curl --config - "$@"
}

upload_atlas_image() {
  local image_path="$1"

  if [[ ! -f "$image_path" ]]; then
    echo "Error: Reference image not found: $image_path" >&2
    exit 1
  fi

  local response
  response=$(atlas_curl --silent --show-error --fail-with-body \
    -X POST "${ATLAS_BASE_URL}/model/uploadMedia" \
    -F "file=@${image_path}")

  local image_url
  image_url=$(echo "$response" | jq -r '.data.download_url // empty')
  if [[ -z "$image_url" ]]; then
    echo "Error: Atlas Cloud upload did not return a download URL" >&2
    echo "$response" | jq . >&2
    exit 1
  fi

  printf '%s\n' "$image_url"
}

atlas_output_url() {
  jq -r '
    first(
      (.data.outputs // .outputs // [])[]? |
      if type == "string" then .
      else (.url // .download_url // .output // empty)
      end
    ) // empty
  '
}

generate_via_atlas() {
  require_atlas_dependency curl
  require_atlas_dependency jq

  if [[ -z "${ATLASCLOUD_API_KEY:-}" ]]; then
    echo "Error: ATLASCLOUD_API_KEY is required for Atlas mode" >&2
    exit 1
  fi

  local prompt_text
  prompt_text="$(get_prompt_text)"

  local model="$ATLAS_TEXT_MODEL"
  local payload
  if [[ ${#IMAGES[@]} -gt 0 ]]; then
    model="$ATLAS_EDIT_MODEL"
    local uploaded_urls=()
    local image_path
    for image_path in "${IMAGES[@]}"; do
      uploaded_urls+=("$(upload_atlas_image "$image_path")")
    done

    local images_json
    images_json=$(printf '%s\n' "${uploaded_urls[@]}" | jq -R . | jq -s .)
    payload=$(jq -n \
      --arg model "$model" \
      --arg prompt "$prompt_text" \
      --arg size "$ATLAS_IMAGE_SIZE" \
      --arg quality "$ATLAS_IMAGE_QUALITY" \
      --arg output_format "$ATLAS_OUTPUT_FORMAT" \
      --argjson images "$images_json" \
      '{model: $model, prompt: $prompt, images: $images, size: $size, quality: $quality, output_format: $output_format}')
  else
    payload=$(jq -n \
      --arg model "$model" \
      --arg prompt "$prompt_text" \
      --arg size "$ATLAS_IMAGE_SIZE" \
      --arg quality "$ATLAS_IMAGE_QUALITY" \
      --arg output_format "$ATLAS_OUTPUT_FORMAT" \
      '{model: $model, prompt: $prompt, size: $size, quality: $quality, output_format: $output_format}')
  fi

  echo "Submitting one generation request to Atlas Cloud using ${model}..." >&2
  local response
  # Generation POSTs are intentionally never retried because they may be billable.
  response=$(atlas_curl --silent --show-error --fail-with-body \
    -X POST "${ATLAS_BASE_URL}/model/generateImage" \
    -H 'content-type: application/json' \
    -d "$payload")

  local prediction_id
  prediction_id=$(echo "$response" | jq -r '.data.id // .id // empty')
  if [[ -z "$prediction_id" ]]; then
    echo "Error: Atlas Cloud did not return a prediction ID" >&2
    echo "$response" | jq . >&2
    exit 1
  fi

  echo "Prediction submitted: $prediction_id" >&2
  local elapsed=0
  local poll_delay=2
  while [[ $elapsed -lt $TIMEOUT ]]; do
    sleep "$poll_delay"
    elapsed=$((elapsed + poll_delay))

    local prediction
    prediction=$(atlas_curl --silent --show-error --fail-with-body \
      --retry 2 --retry-delay 1 --retry-all-errors \
      "${ATLAS_BASE_URL}/model/prediction/${prediction_id}")

    local status
    status=$(echo "$prediction" | jq -r '.data.status // .status // empty')
    if [[ "$status" == "completed" || "$status" == "succeeded" ]]; then
      local output_url
      output_url=$(echo "$prediction" | atlas_output_url)
      if [[ -z "$output_url" ]]; then
        echo "Error: Atlas Cloud completed without an output URL" >&2
        echo "$prediction" | jq . >&2
        exit 1
      fi

      local output_path="$OUTPUT"
      if [[ -z "$output_path" ]]; then
        mkdir -p "$OUTPUT_DIR"
        output_path="${OUTPUT_DIR}/atlas-${prediction_id}.${ATLAS_OUTPUT_FORMAT}"
      else
        mkdir -p "$(dirname "$output_path")"
      fi

      curl --silent --show-error --fail-with-body \
        --retry 2 --retry-delay 1 --retry-all-errors \
        -o "$output_path" "$output_url"
      printf '%s\n' "$output_path"
      return 0
    fi

    if [[ "$status" == "failed" || "$status" == "canceled" || "$status" == "cancelled" ]]; then
      echo "Error: Atlas Cloud generation ended with status '$status'" >&2
      echo "$prediction" | jq . >&2
      exit 1
    fi

    echo "Status: ${status:-unknown} (${elapsed}s/${TIMEOUT}s)" >&2
    if [[ $poll_delay -lt 8 ]]; then
      poll_delay=$((poll_delay * 2))
    fi
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
  atlas)
    generate_via_atlas
    ;;
  *)
    echo "Error: Unknown mode '$MODE'" >&2
    usage
    exit 1
    ;;
esac
