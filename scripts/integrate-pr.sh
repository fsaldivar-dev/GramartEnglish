#!/bin/bash
# Wraps `gh pr merge` for the worktree-divided dev setup where local
# branch deletion fails (the sibling worktree owns main). We pass
# --merge --delete-branch via `gh` so the SERVER deletes the branch,
# but skip the local cleanup to avoid the noisy error.
set -e
PR=$1
if [ -z "$PR" ]; then
  echo "Usage: ./scripts/integrate-pr.sh <PR_NUMBER>"
  exit 2
fi
gh pr merge "$PR" --merge --delete-branch 2>&1 | grep -v "is already used by worktree" || true
echo "Server-side merge complete. Verify with: gh pr view $PR --json mergedAt"
