#!/usr/bin/env bash
set -euo pipefail
# Intentionally runnable only on Actions; never deploy from the presenter's laptop.
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-}"
case "$target" in
  pr) database=DEV_DB; bronze=CI_BRONZE; silver=CI_SILVER; gold=CI_GOLD; role=RETAIL_PR_DEPLOY; user=RETAIL_PR_SVC ;;
  dev) database=DEV_DB; bronze=BRONZE; silver=SILVER; gold=GOLD; role=RETAIL_DEV_DEPLOY; user=RETAIL_DEV_SVC ;;
  qa) database=QA_DB; bronze=BRONZE; silver=SILVER; gold=GOLD; role=RETAIL_QA_DEPLOY; user=RETAIL_QA_SVC ;;
  prod) database=PROD_DB; bronze=BRONZE; silver=SILVER; gold=GOLD; role=RETAIL_PROD_DEPLOY; user=RETAIL_PROD_SVC ;;
  *) printf 'Invalid target: use pr, dev, qa or prod\n' >&2; exit 2 ;;
esac
[[ "${GITHUB_ACTIONS:-}" == true ]] || { printf 'Deployment is GitHub Actions only\n' >&2; exit 2; }
[[ "${GITHUB_REPOSITORY:-}" == sfc-gh-dshemsi/snowflake-sql-cicd-demo ]] || exit 2
[[ "${SNOWFLAKE_ACCOUNT:-}" == SFSENORTHAMERICA-DSHEMSI_AWS1 ]] || exit 2
[[ "${SNOWFLAKE_AUTHENTICATOR:-}" == WORKLOAD_IDENTITY ]] || exit 2
[[ "${SNOWFLAKE_WORKLOAD_IDENTITY_PROVIDER:-}" == OIDC ]] || exit 2
[[ "${DEPLOY_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || exit 2
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]] || exit 2
[[ "$(git -C "$root" rev-parse HEAD)" == "$DEPLOY_SHA" ]] || exit 2
if [[ "$target" == pr ]]; then
  [[ "${GITHUB_EVENT_NAME:-}" == pull_request ]] || exit 2
else
  [[ "${GITHUB_REF:-}" == refs/heads/main ]] || exit 2
  bash "$root/scripts/check_current_release.sh"
fi
if [[ "$target" == prod ]]; then
  [[ "${PROD_ENABLED:-}" == true ]] || { printf 'PROD disabled: reviewer gate not verified\n' >&2; exit 2; }
fi
# Explicit dependency order; the second pass verifies rerunnable definitions and seeds.
files=(sql/00_guard.sql tests/isolation.sql sql/10_raw_tables.sql sql/20_seed.sql sql/30_storage.sql
       tests/snapshot_raw.sql
       sql/40_clean_views.sql sql/50_discount.sql sql/60_process_orders.sql
       sql/70_sales.sql sql/80_task.sql
       sql/10_raw_tables.sql sql/20_seed.sql sql/30_storage.sql
       sql/40_clean_views.sql sql/50_discount.sql sql/60_process_orders.sql
       sql/70_sales.sql sql/80_task.sql
       tests/assert_raw_preserved.sql tests/assertions.sql sql/90_record_release.sql)
arguments=()
for file in "${files[@]}"; do
  arguments+=(-f "$root/$file")
done
printf 'Deploy/test target=%s commit=%s run=%s attempt=%s\n' "$target" "$DEPLOY_SHA" "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT"
snow sql -x --account "$SNOWFLAKE_ACCOUNT" --role "$role" \
  --warehouse RETAIL_CICD_WH --database "$database" --schema "$bronze" \
  --enable-templating STANDARD --enhanced-exit-codes \
  -D "database=$database" -D "bronze=$bronze" -D "silver=$silver" -D "gold=$gold" \
  -D "role=$role" -D "user=$user" -D "commit_sha=$DEPLOY_SHA" \
  -D "run_id=$GITHUB_RUN_ID" -D "run_attempt=$GITHUB_RUN_ATTEMPT" "${arguments[@]}"
