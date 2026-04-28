#!/bin/bash
# Wrapper for scheduled copilot jobs. Usage: run-job.sh <role> <skill> <job-id>
ROLE="$1"
SKILL="$2"
JOB_ID="$3"

LOG_DIR="/tmp/scheduling-assistant"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/${JOB_ID}.log"

export PATH="$HOME/.nvm/versions/node/v24.12.0/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export GH_TOKEN="$(cat "$HOME/.config/scheduling-assistant/token" 2>/dev/null)"

"$HOME/.nvm/versions/node/v24.12.0/bin/copilot" \
  -p "Assume role ${ROLE} and immediately invoke the ${SKILL} skill" \
  --yolo >> "${LOG}" 2>&1
