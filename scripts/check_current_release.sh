#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_REPOSITORY:-}" == sfc-gh-dshemsi/snowflake-sql-cicd-demo ]] || exit 2
[[ "${DEPLOY_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || exit 2
current_sha="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/main" --jq '.object.sha')"
[[ "$DEPLOY_SHA" == "$current_sha" ]] || {
  printf 'Stale release refused: main moved; start a release for current main\n' >&2
  exit 3
}
