#!/bin/bash
# PostToolUse hook.
# If a pending review flag exists (set by pre-push hook when user chose [r]),
# tells Claude to run /review before continuing.

if [ -f ".claude/.pending-review" ]; then
  echo "NOTICE: A code review was requested by the pre-push hook."
  echo "Run /review to complete the review before pushing."
  exit 2
fi

exit 0
