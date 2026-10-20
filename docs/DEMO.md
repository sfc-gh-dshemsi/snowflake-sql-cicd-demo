# 20-minute retail CI/CD demonstration

This is a runbook, not a claim that the steps have run. Complete manual setup and one successful baseline GitHub release before presenting. The current private-repository production approval blocker must be resolved first. Keep the installation afterward; no cleanup/drop step is included.

## 0-3 minutes: orient the customer

Show README and the three database/schema groups in Snowsight. Explain CI (continuous integration: validate a proposed change) and CD (continuous delivery: promote validated code). Distinguish the two connections:

```text
GitHub Actions -- OIDC service identity --> Snowflake
Snowsight      -- interactive Git sign-in --> GitHub
```

Open the five manual files. Show that administrative identity/network/Git setup is absent from the routine deployment file list. Do not display tokens or debug-level authentication logs.

## 3-6 minutes: follow the retail rows

Use verify.sql with DEV role/database. Trace customer 1 and order 101 from raw rows to clean views, processed orders and customer sales. Open the discount function and procedure. Show rejected orders and their reasons, plus Drew's zero-sales row. Show the task's actual suspended state.

Expected baseline fixture results, not yet live observations:

| Customer | Accepted orders | Gross | Discount | Net |
|---|---:|---:|---:|---:|
| Alice Morgan | 2 | 299.99 | 20.00 | 279.99 |
| Ben Carter | 1 | 150.00 | 0.00 | 150.00 |
| Cara Reed | 1 | 100.00 | 10.00 | 90.00 |
| Drew Stone | 0 | 0.00 | 0.00 | 0.00 |

Total net: 519.99. Accepted: 4; rejected: 7. Source rows: 4 customers / 11 orders.

## 6-11 minutes: branch and prove a failing test

Create a feature branch named `feature/gold-discount-15` in the Git-connected Snowsight workspace (or locally after explicit branch/commit/push authorization).

Change only `sql/50_discount.sql`: `ORDER_AMOUNT * 0.10` -> `ORDER_AMOUNT * 0.15`.

Commit/push that branch and open a PR to main. Inspect the real `Retail PR validation` run. Offline checks should pass; live SQL should fail because the expected discount still says 20.00. Show the actual assertion error and query ID. Do not merge the broken change. This deliberately fails only in CI schemas, not in the promoted databases.

Update the independent expectations in `tests/assertions.sql`:

- Discount for 200 GOLD: 20.00 -> 30.00.
- Discount for 100 GOLD: 10.00 -> 15.00.
- Order 101 net: 180.00 -> 170.00.
- Order 104 net: 90.00 -> 85.00.
- Total net: 519.99 -> 504.99.

Do not change the below-threshold or standard-tier assertions. Commit/push the fix after authorization. Inspect the real successful SQL and merge-ready check, including raw preservation and procedure rerun assertions. The tests independently encode the agreed business rule rather than calling the UDF to generate their expected values.

## 11-17 minutes: promote one revision

Merge the PR after review. In `Retail SQL promotion`, show the same commit SHA in DEV and QA. While PROD awaits native required-reviewer approval, query order 101 separately in DEV, QA and PROD:

- DEV: 170.00, new SHA.
- QA: 170.00, same new SHA.
- PROD: 180.00, previous baseline SHA.

Dureti approves PROD herself using GitHub's Review deployments. The assistant does not approve. Then inspect the PROD job, actual order result and deployment history. The commit SHA must match DEV/QA.

If main changes while awaiting approval, the stale-release check refuses that old revision. Start a release for current main; do not disable the check for the presentation. If approval support is still blocked, stop at the blocker and call the demonstration partial.

## 17-20 minutes: reruns and recovery

Show SQL step output for preservation assertions: definitions and seeds run twice, temporary snapshots compare every raw value and multiplicity, and the processor runs twice. Show the source rows remain unchanged.

Discuss a reviewed revert PR for code and assertions. A revert is a new commit promoted through the same path, not a rollback of every DDL/DML statement in a failed release. Table changes need explicitly reviewed ALTER statements; no destructive example is included.

For real customers: separate approver, prevent self-review, enforce branch protection and code-owner review for workflows/SQL, validate grants inherited through PUBLIC, and choose a runner-network policy approved by their security team. The demo's known fixture totals are intentionally not generic production data-quality tests.

## Evidence to record after the real runs

Record in RESULTS.md: baseline SHA/run URL; intentional failing PR/run/query ID; fixed PR run; merge SHA; DEV and QA success; PROD waiting evidence and old result; approval actor/time; PROD success and new result; raw row counts before/after; task state. Never invent IDs, URLs, or screenshots.

Useful read-only commands after runs exist:

```bash
gh run list --repo sfc-gh-dshemsi/snowflake-sql-cicd-demo
gh run view RUN_ID --repo sfc-gh-dshemsi/snowflake-sql-cicd-demo --log-failed
gh pr checks PR_NUMBER --repo sfc-gh-dshemsi/snowflake-sql-cicd-demo
```

The 20 minutes assumes a prepared baseline and normal runner availability. Setup, billing changes and GitHub queue time are outside the presentation window.
