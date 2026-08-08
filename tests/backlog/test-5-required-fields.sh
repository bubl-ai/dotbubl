#!/usr/bin/env bash
# Verifies: the skill asks for missing required fields (priority,
# description, acceptance criteria) instead of writing an incomplete item.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

claude_backlog -p "Log a backlog todo. Title: Improve error messages. Type: enhancement."

find backlog -maxdepth 1 -name '*.md' 2>/dev/null | grep -q . \
  && fail "a file was written despite missing priority/description/acceptance criteria"
echo "PASS"
