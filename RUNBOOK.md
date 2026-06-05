# Runbook

## Worktree-quirk PR merge

`gh pr merge --delete-branch` prints a non-fatal error when the sibling
worktree owns `main` (server-side merge + remote delete still succeed).
Use `./scripts/integrate-pr.sh <PR>` to suppress the noise. Dev-only.
