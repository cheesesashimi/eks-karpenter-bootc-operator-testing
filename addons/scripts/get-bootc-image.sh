#!/usr/bin/env bash
set -xeuo pipefail

input=$(jq -e 'select(.instance_id != null and .instance_id != "")')
instance_id=$(jq -r '.instance_id' <<<"$input")

command_id=""
for _ in {1..60}; do
  if command_id=$(aws ssm send-command \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["sudo bootc status --json"]}' \
    --query "Command.CommandId" \
    --output text 2>/dev/null); then
    break
  fi
  sleep 5
done

if [[ -z "$command_id" ]]; then
  printf 'Timed out waiting for instance %s to become available in SSM\n' "$instance_id" >&2
  exit 1
fi

status=""
for _ in {1..60}; do
  status=$(aws ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$instance_id" \
    --query "Status" \
    --output text 2>/dev/null || true)

  case "$status" in
  Success | Failed | Cancelled | TimedOut | Undeliverable | Terminated)
    break
    ;;
  esac
  sleep 5
done

result=$(aws ssm get-command-invocation \
  --command-id "$command_id" \
  --instance-id "$instance_id" \
  --output json)

if [[ "$(jq -r '.Status' <<<"$result")" != "Success" ]]; then
  printf 'bootc status failed on instance %s: %s\n' "$instance_id" \
    "$(jq -r '.StandardErrorContent' <<<"$result")" >&2
  exit 1
fi

stdout=$(jq -r '.StandardOutputContent' <<<"$result")
status_json=$(jq -e '.' <<<"$stdout")
image=$(jq -er '.status.booted.image.image.image' <<<"$status_json")
digest=$(jq -er '.status.booted.image.imageDigest' <<<"$status_json")
repository="${image%:*}"

jq -n \
  --arg image_ref "${repository}@${digest}" \
  '{image_ref: $image_ref}'
