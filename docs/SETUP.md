# Manual setup and first GitHub release

## Current checkpoint

The project is prepared for initial publication to the private repository. Publication is authorized; deployment is not. No setup SQL or business SQL has been executed by the assistant. See the repository's Actions tab for publication checks and [RESULTS.md](RESULTS.md) for the dated pre-publication verification record.

The GitHub API rejected the production required-reviewer rule with HTTP 422: **"Failed to create the environment protection rule. Please ensure the billing plan supports the required reviewers protection rule."** Main-only branch policies were successfully configured on `dev`, `qa`, and `prod`, but PROD has no reviewer rule. Repository variables `DEPLOYMENTS_ENABLED=false` and `PROD_ENABLED=false` are set. Do not enable PROD until the actual reviewer rule is available and verified. Do not use manual dispatch as a substitute for approval.

The initial failed environment request created an unprotected `prod` environment. It now has a main-only branch rule, but remains unsuitable for production approval. Keep deployment switches disabled during publication; the missing approval rule must not be bypassed.

## 1. Run setup yourself in Snowsight

Select **SFSENORTHAMERICA-DSHEMSI_AWS1**, signed in as **DSHEMSI**. Do not use Snowhouse. Open `setup.sql` as a worksheet and run each labeled section in order. Run every `EXECUTE IMMEDIATE` block as a whole; stop on any error.

- Inspect the exact database/warehouse/role names before creating anything. Existing objects must belong exclusively to this demo. The account guard is not a name-collision or ownership audit.
- Section 1 uses SECURITYADMIN for four isolated deployment roles and grants them to DSHEMSI and SYSADMIN. Those administrative roles must already be available to the presenter.
- Section 2 uses SYSADMIN for infrastructure and schema creation privileges. No deployment role receives database/schema ownership, account administration, user management, or grant management.
- Section 3 switches to RETAIL_DEV_DEPLOY before creating input tables so later Actions runs use the same owner role.
- Section 4 displays **4 customers and 11 orders** on a fresh setup. Re-run the setup and compare the actual raw rows. Seeds add only missing keys; existing values are not repaired automatically.
- QA and PROD contain empty BRONZE/SILVER/GOLD schemas. They do not receive business objects from manual setup.

`setup.sql` is generated from `scripts/build_setup.py`, `sql/10_raw_tables.sql`, and `sql/20_seed.sql`. Regenerate after changing those inputs:

```bash
python3 scripts/build_setup.py
python3 scripts/build_setup.py --check
```

This generation is local file processing, not deployment.

## 2. Configure Actions authentication

Run `oidc_setup.sql` in the same Snowsight account as ACCOUNTADMIN. It creates four service users with no password or private key. Inspect DESC USER and SHOW GRANTS output afterward; existing users are not reconfigured by `IF NOT EXISTS`.

Exact repository prefix obtained from GitHub:

```text
repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222
```

| Identity | Subject suffix | Role and write scope |
|---|---|---|
| RETAIL_PR_SVC | `:pull_request` | RETAIL_PR_DEPLOY; DEV_DB.CI_BRONZE/CI_SILVER/CI_GOLD |
| RETAIL_DEV_SVC | `:environment:dev` | RETAIL_DEV_DEPLOY; DEV_DB.BRONZE/SILVER/GOLD |
| RETAIL_QA_SVC | `:environment:qa` | RETAIL_QA_DEPLOY; QA_DB.BRONZE/SILVER/GOLD |
| RETAIL_PROD_SVC | `:environment:prod` | RETAIL_PROD_DEPLOY; PROD_DB.BRONZE/SILVER/GOLD; initially disabled |

Issuer: `https://token.actions.githubusercontent.com`. Audience: `snowflakecomputing.com`. Repository recreation changes the numeric ID: verify the subject again instead of copying it to another repository.

Review existing PUBLIC grants and any grants on reused roles/users. These scripts do not remove preexisting access. Logical isolation requires that the service identities have no additional privileges exposing the other environments. The deployment role owns its business objects and can therefore damage its own environment if malicious code is merged; this is not a sandbox for untrusted contributors.

Official documentation: **"With OIDC, GitHub issues a short-lived OpenID Connect token that Snowflake validates directly. No private key or password is stored in GitHub."** [Snowflake CLI GitHub Action](https://docs.snowflake.com/en/developer-guide/snowflake-cli/cicd/github-action).

## 3. Review and attach the runner network policy

Run the inspection section of `network_policy_setup.sql` first. Review account and all four user policies. The creation block stops if it finds a different effective policy; resolve that with the account administrator, not by broadening the allowlist automatically.

Then inspect `DESC NETWORK POLICY RETAIL_GITHUB_RUNNERS`. Only after review, uncomment/select the final guarded attachment block. It attaches exclusively to the four service users, never DSHEMSI or the account. On reruns verify the existing policy contents; `IF NOT EXISTS` does not refresh them.

The allowlist uses `SNOWFLAKE.NETWORK_SECURITY.GITHUBACTIONS_GLOBAL`. This identifies the runner network, not this particular repository. OIDC subject matching supplies the separate identity check. A user-level policy is not an additive exception to all existing account restrictions; review the effective policy before attachment.

The official CI/CD tutorial says **"A Snowflake user can have only one network policy at a time"** and provides the managed GitHub rule and user attachment pattern. Only its authentication/network sections are reused; this project does not use dbt. [Source](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-advanced-ci-cd-tutorial).

## 4. Configure separate Snowsight Git authorization

Run `git_setup.sql` as ACCOUNTADMIN and inspect the integration. After the repository has code on main, use **Projects > Workspaces > From Git repository**, the `.git` URL in that file, and RETAIL_GITHUB_APP. Complete GitHub authorization interactively. Select only this repository when authorizing the GitHub App.

SQL configures the integration; it does not sign you in. No personal access token belongs in chat, SQL source, or the repository.

The documented configuration is `API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)`. The reference states **"No other values are required for API_USER_AUTHENTICATION in this case."** [CREATE API INTEGRATION](https://docs.snowflake.com/en/sql-reference/sql/create-api-integration).

## 5. Publication and release checklist

Initial publication is authorized with both deployment switches disabled. Keep repository visibility private. Publication does not authorize running setup, enabling deployments, or approving PROD. Before enabling deployments:

1. Confirm manual setup, service identities, ownership, PUBLIC grants, network attachments, and the expected account.
2. Obtain a GitHub capability/hosting decision that preserves a real required-reviewer gate. No upgrade or visibility change has been performed.
3. Configure PROD required reviewer `sfc-gh-dshemsi` (ID 216220113), no administrator bypass, main branch only. For this solo demo, self-review is allowed. For a real customer use another reviewer and prevent self-review.
4. Inspect all environment policies using the GitHub API. The runtime check must be able to read environments and run approval history using the Actions token. If an API read fails, deployment fails closed; validate this during the first run.
5. Publish the reviewed files with `DEPLOYMENTS_ENABLED=false` so only offline checks run. Initial publication is authorized; later pushes require their own authorization.
6. Once main exists and static checks pass, protect main: require PRs, disallow force pushes/deletion, and require the `validation-result` check before merging. Verify the actual check name from a PR run. Bootstrap publication precedes branch protection because the repository starts empty.
7. Set `DEPLOYMENTS_ENABLED=true` only after manual setup and publication approval. DEV/QA can run while PROD remains blocked, but that is a partial demonstration, not a completed release.
8. Only after the native production gate is verified, explicitly enable RETAIL_PROD_SVC in Snowsight and set `PROD_ENABLED=true`. The enabling SQL is deliberately not included in routine deployment.
9. Dispatch the baseline promotion on main. Every deployment checks out the same `${{ github.sha }}`. Approve PROD yourself in GitHub; the assistant must not approve it.

The workflow checks protections before requesting the Snowflake OIDC token, and checks for a real approval on the current run before PROD deployment. These checks complement, not replace, GitHub environment enforcement.

## What the workflows execute

`promote.yml`: static checks -> DEV -> QA -> PROD approval -> PROD. A shared concurrency group prevents overlapping release runs; active releases are not automatically canceled. Each environment refuses a revision that is no longer current main. GitHub concurrency is not a FIFO release queue: superseded pending runs may not execute. The stale check is a point-in-time check; a newer merge can arrive during a SQL step, but cannot start an overlapping release through this workflow.

`pr.yml`: all PRs get credential-free checks. Same-repository, non-Dependabot PRs additionally use only the PR identity and shared CI schemas. Those SQL jobs serialize. Fork PRs do not receive live SQL credentials and cannot pass the merge-ready result until a maintainer reviews and moves the change into a trusted branch. No pull_request_target workflow exists.

`deploy.sh`: guard -> tables -> insert-only fixtures -> storage -> raw snapshot -> views -> discount function -> procedure -> sales -> suspended task -> repeat definitions -> raw preservation check -> business and procedure-rerun tests -> successful deployment record.

Official CLI docs state **"When you specify multiple files, all files are executed sequentially on a single connection."** This preserves the temporary comparison tables across the files. [snow sql](https://docs.snowflake.com/en/developer-guide/snowflake-cli/command-reference/sql-commands/sql).

## Troubleshooting and reruns

- OIDC mismatch: compare the exact prefix, environment suffix, issuer and audience. PR job deliberately has no environment. Never print the token.
- Network denied: review the effective user policy and runner rule; never attach the automation policy to your human login.
- Owner/permission failure: confirm setup used RETAIL_DEV_DEPLOY for raw tables. Inspect grants; do not automatically transfer unrelated ownership.
- Test failure: inspect order-level assertions and fixture drift. The demonstration expects only the documented fixtures; added valid orders change total assertions. Seeds deliberately do not overwrite manual changes.
- Partial release: stop promotion. Inspect the failed SQL/query ID and last successful history row. Fix through a PR, then redeploy current main. A history row means tests passed, not that all previous failed attempts left no changes.
- Revert: use a reviewed Git revert PR for code plus tests. Deploy the new revert commit through the same pipeline. Do not dispatch an old SHA; stale checks intentionally refuse it.
- Table evolution: add reviewed, explicit ALTER statements and matching tests. CREATE TABLE IF NOT EXISTS is not schema reconciliation.
- The processor handles inserts/updates and retains rejected rows; it does not remove processed rows when a raw order is physically deleted. Raw delete/CDC handling is outside this demo.
- Task remains suspended, with no EXECUTE TASK grant. Tests call PROCESS_ORDERS directly. Official docs say **"Newly created or cloned tasks are created suspended."** [CREATE TASK](https://docs.snowflake.com/en/sql-reference/sql/create-task).
- No multi-file rollback promise: official procedure docs say **"Stored procedures are not atomic"**. Review failures and forward-fix or revert code rather than claiming DDL rollback. [CREATE PROCEDURE](https://docs.snowflake.com/en/sql-reference/sql/create-procedure).

## Offline verification

```bash
python3 -m pip install -r requirements-dev.txt
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

These tests check generation drift, shell syntax, workflow YAML/contracts, action pins, target rejection, data-preserving statement patterns, and protection checks. They are not Snowflake SQL compilation or live permission tests. The installed local CLI is 3.17.1; the workflow pins that version and snowflake-actions v3.0.0 by verified commit SHA.
