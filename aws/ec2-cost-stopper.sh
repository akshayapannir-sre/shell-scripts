#!/bin/bash
# ec2-cost-stopper.sh
# Auto-stop non-production EC2 instances during off-hours
# Saves cloud costs by stopping dev/staging instances at night
#
# Usage: ./ec2-cost-stopper.sh [stop|start|status]
# Cron (stop at 8PM IST): 0 14 * * 1-5 /scripts/ec2-cost-stopper.sh stop
# Cron (start at 9AM IST): 30 3 * * 1-5 /scripts/ec2-cost-stopper.sh start

set -euo pipefail

# ── Config ────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-ap-south-1}"
ENV_TAGS=("dev" "staging" "test")        # environments to manage
EXCLUDE_TAG="always-on"                  # instances with this tag are skipped
SNS_TOPIC="${SNS_TOPIC:-}"               # optional SNS ARN for alerts
LOG_FILE="/var/log/ec2-cost-stopper.log"
# ──────────────────────────────────────────────────────────

ACTION="${1:-status}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
  echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

get_instances() {
  local env_tag="$1"
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      "Name=tag:Environment,Values=${env_tag}" \
      "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].[InstanceId, State.Name, Tags[?Key==`Name`].Value|[0]]' \
    --output text
}

stop_instances() {
  local instance_ids=("$@")
  if [ ${#instance_ids[@]} -eq 0 ]; then
    log "No instances to stop."
    return
  fi
  log "Stopping instances: ${instance_ids[*]}"
  aws ec2 stop-instances \
    --region "$AWS_REGION" \
    --instance-ids "${instance_ids[@]}" \
    --output text >> "$LOG_FILE"
}

start_instances() {
  local instance_ids=("$@")
  if [ ${#instance_ids[@]} -eq 0 ]; then
    log "No instances to start."
    return
  fi
  log "Starting instances: ${instance_ids[*]}"
  aws ec2 start-instances \
    --region "$AWS_REGION" \
    --instance-ids "${instance_ids[@]}" \
    --output text >> "$LOG_FILE"
}

notify() {
  local message="$1"
  if [ -n "$SNS_TOPIC" ]; then
    aws sns publish \
      --region "$AWS_REGION" \
      --topic-arn "$SNS_TOPIC" \
      --message "$message" \
      --subject "EC2 Cost Stopper — $(hostname)" \
      > /dev/null
  fi
}

main() {
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "Action: $ACTION | Region: $AWS_REGION"

  declare -a target_ids=()

  for env in "${ENV_TAGS[@]}"; do
    log "Scanning environment: $env"
    while IFS=$'\t' read -r instance_id state name; do
      [ -z "$instance_id" ] && continue

      # Skip always-on instances
      always_on=$(aws ec2 describe-tags \
        --region "$AWS_REGION" \
        --filters \
          "Name=resource-id,Values=${instance_id}" \
          "Name=key,Values=${EXCLUDE_TAG}" \
        --query 'Tags[0].Value' \
        --output text 2>/dev/null || echo "None")

      if [ "$always_on" != "None" ] && [ -n "$always_on" ]; then
        log "  Skipping $instance_id ($name) — tagged always-on"
        continue
      fi

      log "  Found: $instance_id | $name | $state"
      target_ids+=("$instance_id")
    done < <(get_instances "$env")
  done

  case "$ACTION" in
    stop)
      running_ids=()
      for id in "${target_ids[@]}"; do
        state=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --instance-ids "$id" \
          --query 'Reservations[0].Instances[0].State.Name' \
          --output text)
        [ "$state" = "running" ] && running_ids+=("$id")
      done
      stop_instances "${running_ids[@]}"
      notify "Stopped ${#running_ids[@]} non-prod EC2 instances in $AWS_REGION"
      log "Done. Stopped ${#running_ids[@]} instances."
      ;;
    start)
      stopped_ids=()
      for id in "${target_ids[@]}"; do
        state=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --instance-ids "$id" \
          --query 'Reservations[0].Instances[0].State.Name' \
          --output text)
        [ "$state" = "stopped" ] && stopped_ids+=("$id")
      done
      start_instances "${stopped_ids[@]}"
      notify "Started ${#stopped_ids[@]} non-prod EC2 instances in $AWS_REGION"
      log "Done. Started ${#stopped_ids[@]} instances."
      ;;
    status)
      log "Status of non-prod instances:"
      for id in "${target_ids[@]}"; do
        state=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --instance-ids "$id" \
          --query 'Reservations[0].Instances[0].State.Name' \
          --output text)
        name=$(aws ec2 describe-instances \
          --region "$AWS_REGION" \
          --instance-ids "$id" \
          --query 'Reservations[0].Instances[0].Tags[?Key==`Name`].Value|[0]' \
          --output text)
        log "  $id | $name | $state"
      done
      ;;
    *)
      echo "Usage: $0 [stop|start|status]"
      exit 1
      ;;
  esac
}

main
