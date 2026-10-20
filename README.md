# Snowflake SQL CI/CD Demo

Retail SQL deployment using **GitHub Actions, Snowflake CLI, and OIDC**. No migration framework.

[Setup](#1-run-setup) · [Connect Git](#2-connect-git) · [Configure Actions](#3-configure-github-actions) · [Deploy](#4-deploy-and-verify) · [Make a change](#5-make-a-change)

## How CI/CD works in this demo

```mermaid
flowchart LR
    PR["Feature PR"] --> CI["CI checks<br/>Code + SQL tests"]
    CI -->|Pass + review| MAIN["Merge to main"]
    MAIN --> DEV["DEV<br/>Deploy + test"]
    DEV -->|Pass| QA["QA<br/>Deploy + test"]
    QA -->|Pass| APPROVAL["Manual<br/>approval"]
    APPROVAL --> PROD["PROD<br/>Deploy + test"]
```

- **CI:** Test PR changes in isolated CI schemas; fix failures and push again.
- **CD:** Promote the same `main` commit through DEV, QA, and approved PROD. Failed stages stop promotion.
- Environments are not branches. Promotion moves code, not data.

<details>
<summary><strong>Demo architecture</strong></summary>

```mermaid
flowchart TB
    AUTHOR["Developer<br/>Snowsight Git workspace or local editor"] -->|Commit and push| REPO["GitHub repository<br/>SQL files, assertions, workflows"]
    ADMIN["Administrator<br/>Run setup.sql manually in Snowsight"]

    subgraph GH["GitHub Actions"]
        CONFIG["Repository configuration<br/>Secret: SNOWFLAKE_ACCOUNT<br/>Variables: deployment switches"]
        RUNNER["Hosted runner<br/>Snowflake CLI + deploy.sh"]
        TOKEN["GitHub OIDC<br/>Short-lived identity token"]
        CONFIG -.-> RUNNER
        TOKEN --> RUNNER
    end
    REPO -->|PR validation or main promotion| RUNNER

    subgraph SF["One Snowflake demo account"]
        ACCESS["Connection controls<br/>RETAIL_GITHUB_RUNNERS network policy<br/>OIDC service users and deployment roles"]
        WH["Shared compute<br/>RETAIL_CICD_WH"]
        subgraph DEVDB["DEV_DB"]
            PRLAYERS["CI_BRONZE / CI_SILVER / CI_GOLD<br/>RETAIL_PR_SVC / RETAIL_PR_DEPLOY"]
            DEVLAYERS["BRONZE / SILVER / GOLD<br/>RETAIL_DEV_SVC / RETAIL_DEV_DEPLOY"]
        end
        QALAYERS["QA_DB<br/>BRONZE / SILVER / GOLD<br/>RETAIL_QA_SVC / RETAIL_QA_DEPLOY"]
        PRODLAYERS["PROD_DB<br/>BRONZE / SILVER / GOLD<br/>RETAIL_PROD_SVC / RETAIL_PROD_DEPLOY"]
        ACCESS -->|PR| PRLAYERS
        ACCESS -->|DEV| DEVLAYERS
        ACCESS -->|QA| QALAYERS
        ACCESS -->|PROD - after approval| PRODLAYERS
        WH -.-> PRLAYERS
        WH -.-> DEVLAYERS
        WH -.-> QALAYERS
        WH -.-> PRODLAYERS
    end
    RUNNER -->|OIDC-authenticated SQL and assertions| ACCESS
    ADMIN -.->|Infrastructure, identities, policy, Git integration and DEV seed rows| SF
```

</details>

## 1. Run setup

- Use a dedicated demo account, administrator access, and a private GitHub repository.
- Before publishing workflows, set repository variables `DEPLOYMENTS_ENABLED=false` and `PROD_ENABLED=false` (step 3).
- Run **[setup.sql](setup.sql)** in Snowsight. No Python setup or separate setup scripts needed.
- **Pause for manual checks:** Section 1 confirms the account; section 6 reviews network policies before attachment. Stop on errors; reused settings are not reconciled.
- Verify all statements succeeded and fresh setup shows **4 customers / 11 orders**. Full deployment happens through Actions.

**Using another account/repo?** Update account guards, repository IDs, OIDC subjects, Git URL, and reviewer ID in SQL, scripts, and tests. Changing the GitHub secret alone is not enough.

## 2. Connect Git

- Publish `main` with deployments disabled.
- In Snowsight's user menu, select `RETAIL_DEV_DEPLOY`.
- Open **Projects > Workspaces > From Git repository**.
- Enter the repository URL, select `RETAIL_GITHUB_APP`, and complete **OAuth2** sign-in.

## 3. Configure GitHub Actions

### Account secret and deployment variables

Open **Settings > Secrets and variables > Actions**:

- **Secrets > New repository secret:** Add `SNOWFLAKE_ACCOUNT` = your demo `ORGANIZATION-ACCOUNT` identifier, not a URL. Do not add same-name environment secrets.
- **Variables > New repository variable:** Add both switches below, initially `false`.
- **`DEPLOYMENTS_ENABLED`:** Set to `true` after setup, grants, and network checks. Enables live PR tests and DEV/QA.
- **`PROD_ENABLED`:** Set to `true` only after configuring approval below and explicitly enabling `RETAIL_PROD_SVC` in Snowsight. Setup creates this user disabled; reruns preserve its existing state.

### Environments and approval

- **Settings > Environments:** Create `dev`, `qa`, and `prod`.
- For each, select **Deployment branches and tags > Selected branches and tags**; add only **Branch: `main`**.
- For **prod**, enable **Required reviewers**, select the approver, disable administrator bypass, and save. Leave DEV/QA reviewers off.
- Match the approver's numeric ID in both checks in [`check_environment.py`](scripts/check_environment.py) and its offline test.
- Teams: enable **Prevent self-review**. Solo demo: allow self-review.
- **Reviewer gate unavailable?** Keep PROD disabled; check [GitHub requirements](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

### Protect main

- **Settings > Branches:** Require PRs and **`validation-result`**; block force pushes and deletion.
- Check not listed? Run a test PR first. Failed/skipped live SQL cannot pass; fork and Dependabot PRs are offline-only.

## 4. Deploy and verify

- Open **Actions > Retail SQL promotion > Run workflow > main**. Variable changes alone do not start a run.
- Review DEV/QA results, then approve PROD through **Review deployments**.
- Run **[verify.sql](verify.sql)**: after deploying this 15% change, order 101 should show **$200 gross / $30 discount / $170 net** (10% baseline: $20 discount / $180 net); confirm matching release commits and a suspended task.
- With PROD disabled, DEV/QA can run, but the workflow reports **`PROD BLOCKED`** rather than full-release success.

## 5. Make a change

- Create a feature branch; edit [`sql/`](sql/) and [`tests/assertions.sql`](tests/assertions.sql).
- Push, open a PR to `main`, review passing checks, and merge. Follow promotion and approve PROD.
- **Example: 10% -> 15% discount.** Expected discounts: `20 -> 30`, `10 -> 15`; net amounts: `180 -> 170`, `90 -> 85`; total: `519.99 -> 504.99`.

## Documentation

- [Snowflake CLI and OIDC](https://docs.snowflake.com/en/developer-guide/snowflake-cli/cicd/github-action)
- [Snowsight Git setup](https://docs.snowflake.com/en/user-guide/ui-snowsight/workspaces-git)
- [GitHub environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

> Diagrams and sample results describe the intended flow. Offline checks do not prove live deployment success.
