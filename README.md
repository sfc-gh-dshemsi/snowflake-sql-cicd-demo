# Snowflake SQL CI/CD Demo

Deploy a retail SQL example with **GitHub Actions, Snowflake CLI, and OIDC**. The same code revision moves through **DEV -> QA -> manual approval -> PROD**. No migration framework is used.

The demo defines `DEV_DB`, `QA_DB`, and `PROD_DB` in one account, each with `BRONZE`, `SILVER`, and `GOLD` schemas.

**Follow these steps in order:**
[1. Prepare](#1-prepare) | [2. Run setup](#2-run-setup-in-snowsight) | [3. Connect Git](#3-connect-snowsight-to-github) | [4. Configure Actions](#4-configure-github-actions) | [5. Deploy](#5-deploy-and-verify) | [6. Make a change](#6-make-a-change)

## 1. Prepare

- Use a dedicated demo account and a private GitHub repository with Actions enabled.
- Arrange administrator access for setup and a reviewer for production approval.
- Before publishing workflows, create repository variables `DEPLOYMENTS_ENABLED=false` and `PROD_ENABLED=false` under **Settings > Secrets and variables > Actions > Variables**.
- If using a different account or repository, update the account/user guards, repository identifiers, OIDC subjects, Git URL, and reviewer ID in the supplied SQL, scripts, workflows, and tests. These values are not automatically configured by this README. Regenerate `setup.sql` with `python3 scripts/build_setup.py` after updating its source.

## 2. Run setup in Snowsight

Open each file as a SQL worksheet and run it manually in this order. Follow the role switches in each file, run complete blocks, and stop on errors. Review existing objects before reusing their names.

1. **[setup.sql](setup.sql)** — Prepare roles, warehouse, databases, and schemas; insert sample customers and orders in DEV.
2. **[oidc_setup.sql](oidc_setup.sql)** — Configure the service identities used by GitHub Actions. Leave the PROD identity disabled until approval is configured.
3. **[network_policy_setup.sql](network_policy_setup.sql)** — Inspect existing policies, review the runner policy, then explicitly run the commented attachment block. Apply it only to the automation users, not your own login or the account.
4. **[git_setup.sql](git_setup.sql)** — Configure the integration used to connect Snowsight to GitHub.

**Check:** A fresh setup should display **4 customers and 11 orders**. Full business deployment happens through Actions, not from your laptop.

## 3. Connect Snowsight to GitHub

Publish the project to your repository's `main` branch with deployments still disabled. Then, in Snowsight:

1. Select `RETAIL_DEV_DEPLOY` in the user-menu role selector.
2. Open **Projects > Workspaces > From Git repository**.
3. Enter your repository URL and select `RETAIL_GITHUB_APP`.
4. Choose **OAuth2**, complete GitHub sign-in, and create the workspace.

This Git connection is separate from the OIDC authentication used by Actions. See the [workspace setup documentation](https://docs.snowflake.com/en/user-guide/ui-snowsight/workspaces-git).

## 4. Configure GitHub Actions

1. Under **Settings > Environments**, create `dev`, `qa`, and `prod`. Restrict each to the `main` branch.
2. For `prod`, configure a required reviewer and disable administrator bypass. Match the reviewer ID in `scripts/check_environment.py`. Use a separate reviewer for team deployments.
3. Protect `main` with required pull requests and the `validation-result` check; confirm the check name from a PR run. This check intentionally fails when live SQL validation is skipped.
4. After verifying manual setup, grants, and network configuration, set `DEPLOYMENTS_ENABLED=true`.
5. Only after verifying the native PROD approval gate, enable `RETAIL_PROD_SVC` in Snowsight and set `PROD_ENABLED=true`.

**Do not enable PROD if required-reviewer protection is unavailable.** A manual workflow start does not replace production approval.

## 5. Deploy and verify

1. In GitHub, open **Actions > Retail SQL promotion > Run workflow** and select `main`.
2. Inspect the DEV deployment and tests, followed by QA.
3. Have the designated reviewer approve PROD through **Review deployments**.
4. Run **[verify.sql](verify.sql)** in Snowsight using the matching environment role/database.

**Expected result:** Order 101 has **$200 gross, $20 discount, and $180 net**. Confirm the same release commit across DEV, QA, and PROD. The task should remain suspended.

## 6. Make a change

1. Create a feature branch and update the business SQL in [`sql/`](sql/).
2. Update the matching assertions in [`tests/assertions.sql`](tests/assertions.sql).
3. Push the branch and open a pull request to `main`.
4. Review the changes and passing checks, then merge.
5. Follow the automatic DEV -> QA promotion, approve PROD, and verify the new results.

**Example:** Change the GOLD discount from 10% to 15%. Update expected discounts **20 -> 30** and **10 -> 15**, net amounts **180 -> 170** and **90 -> 85**, and total net sales **519.99 -> 504.99**. Order 101 should then have **$170 net**.

## Documentation

- [Snowflake CLI GitHub Action and OIDC](https://docs.snowflake.com/en/developer-guide/snowflake-cli/cicd/github-action)
- [Connect Snowsight Workspaces to Git](https://docs.snowflake.com/en/user-guide/ui-snowsight/workspaces-git)
- [GitHub deployment environments and approval rules](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

Sample results above are expectations. Passing offline checks does not verify live SQL execution; complete the deployment steps before presenting the demo as tested end to end.
