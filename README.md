# Snowflake SQL CI/CD Demo

A retail example using **GitHub Actions, Snowflake CLI, and OpenID Connect (OIDC)** to promote one code revision through DEV, QA, and manually approved PROD. Business logic is plain SQL; no DCM Projects, schemachange, dbt, or migration framework is used.

```text
Feature branch -> Pull request checks -> Merge to main
                                       -> DEV -> QA -> PROD approval -> PROD
```

The project targets one demo account, `SFSENORTHAMERICA-DSHEMSI_AWS1`, with `DEV_DB`, `QA_DB`, and `PROD_DB`. Each has BRONZE, SILVER, and GOLD layers. PR validation targets separate `DEV_DB.CI_*` schemas.

> **Current status:** Offline checks pass; live SQL deployment is not yet verified. Both deployment switches are disabled. GitHub rejected the required-reviewer rule for this private repository; keep PROD disabled until that gate is configured and verified.

## 1. Prepare the account in Snowsight

Sign in to the demo account as `DSHEMSI`. Follow [the setup guide](docs/SETUP.md) and run these worksheets manually, in order. Review each section and stop on errors.

1. **[setup.sql](setup.sql)** — Prepare roles, warehouse, databases, and schemas; seed and display four customers and eleven orders in DEV.
2. **[oidc_setup.sql](oidc_setup.sql)** — Configure the four Actions service identities. The PROD identity is initially disabled.
3. **[network_policy_setup.sql](network_policy_setup.sql)** — Inspect existing policies, then review the runner policy before explicitly applying the commented attachment section.
4. **[git_setup.sql](git_setup.sql)** — Configure the separate Snowsight Git integration and complete interactive GitHub authorization as described in the guide.

These files are specific to this account and repository. Review identifiers before adapting the demo elsewhere. Do not run administrative setup through Actions or deploy business SQL from your laptop.

## 2. Configure and run GitHub Actions

1. Keep repository variables `DEPLOYMENTS_ENABLED=false` and `PROD_ENABLED=false` during initial publication; only offline checks should run.
2. Confirm manual setup and review the `dev`, `qa`, and `prod` environments, each restricted to `main`. Configure main branch protection and required PR checks using [SETUP.md](docs/SETUP.md#5-publication-and-release-checklist).
3. After setup verification, set `DEPLOYMENTS_ENABLED=true` for DEV/QA. Keep PROD disabled until its native required-reviewer gate is verified, then explicitly enable its service identity and set `PROD_ENABLED=true`.
4. In **Actions > Retail SQL promotion > Run workflow**, select `main`. Inspect DEV and QA results, then approve PROD manually when prompted.

DEV/QA success alone is not a complete release. For the solo demo, the intended reviewer is `sfc-gh-dshemsi`; customer deployments should use a separate reviewer and prevent self-approval.

## 3. Demonstrate a change

Follow the [20-minute runbook](docs/DEMO.md): change the GOLD discount from 10% to 15%, observe an intentional failing PR assertion, update the expected results, then merge and promote. Use [verify.sql](verify.sql) to inspect results after deployment.

The SQL includes customer/order tables, cleaned views, a discount UDF, an order-processing procedure, a sales summary, and a task deliberately left suspended. Tests cover accepted/rejected orders, repeat processing, raw-data preservation, and task state. [RESULTS.md](docs/RESULTS.md) distinguishes observed checks from unrun live tests.

## Repository layout

- `sql/` — Shared business definitions, fixtures, and deployment history.
- `tests/` — SQL assertions and offline contract tests.
- `scripts/` — Setup generation, deployment order, and release safeguards.
- `.github/workflows/` — PR validation and sequential environment promotion.
- `docs/` — Detailed setup, demo runbook, and verification record.

## Run offline checks

From the repository root:

```bash
python3 -m pip install -r requirements-dev.txt
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

These checks do not connect to Snowflake or establish that SQL compiles. Keep credentials and customer data out of source control and workflow logs.

Reference: [Snowflake CLI GitHub Action and OIDC authentication](https://docs.snowflake.com/en/developer-guide/snowflake-cli/cicd/github-action).
