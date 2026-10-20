# Verification record

Pre-publication checkpoint: October 20, 2026. **Local implementation complete; end-to-end demonstration incomplete.**

Initial publication has since been authorized with deployments disabled. The observations below describe the pre-publication checkpoint, not the current branch or run count. Consult [GitHub Actions](https://github.com/sfc-gh-dshemsi/snowflake-sql-cicd-demo/actions) for subsequent publication-check results; those are not live SQL deployment evidence.

## Observed results

- `python3 -m unittest discover -s tests -p 'test_*.py' -v`: **13 tests passed**.
- `actionlint` v1.7.7: all three workflow files passed (exit 0). ShellCheck and Pyflakes integration were disabled; bash syntax and Python tests were checked separately.
- Generated `setup.sql` matched its canonical source definitions.
- Mock CLI tests verified argument/file order, PR schema mapping, success exit 0 and query-failure exit 5 propagation. These were mocked, not live Snowflake execution.
- Local deployment invocation rejected before contacting Snowflake.
- GitHub API verified main-only branch policies for DEV and QA through `scripts/check_environment.py`, using the local gh identity. Actions-token access to these API endpoints is not yet tested.
- Remote private repository created: https://github.com/sfc-gh-dshemsi/snowflake-sql-cicd-demo
- Repository ID: 1426468222. Owner ID: 216220113. Immutable OIDC prefix verified directly through the repository API.
- DEV, QA and PROD environments exist with a custom branch policy allowing only main.
- `DEPLOYMENTS_ENABLED=false` and `PROD_ENABLED=false` were configured.
- Required-reviewer configuration failed: HTTP 422, "Failed to create the environment protection rule. Please ensure the billing plan supports the required reviewers protection rule."
- PROD does NOT have a reviewer gate. The failed request initially created an empty environment; it was subsequently restricted to main. This does not resolve the approval requirement.
- GitHub workflow run count: **0** at this checkpoint.
- No local Git repository initialization, commits, feature branches, pushes, or PRs performed. Remote contains no published code.

## Review corrections made locally

- Moved procedure COPY GRANTS before RETURNS to match the canonical SQL syntax.
- Captured the task SHOW query ID inside the assertion block instead of relying on ambiguous LAST_QUERY_ID positioning.
- Added conservative cross-environment visibility assertions before deployment writes.
- Rechecked existing effective user policies in the commented network attachment block; it refuses a conflicting effective policy before attaching anything.
- Added mocked deployment tests and an independent workflow validator rather than representing YAML parsing as sufficient validation.

## Explicitly unrun

- Manual setup.sql in Snowsight and its rerun.
- Service-user creation, OIDC authentication and effective role isolation in Snowflake.
- Network policy creation/attachments and runner connectivity.
- Git integration creation and interactive sign-in.
- Snowflake compilation or execution of any project SQL.
- Live SQL assertions, preserved raw rows, procedure reruns, and task state verification.
- Actions-token access to environment/approval API endpoints.
- Main branch protection with required PR status checks (no main branch exists yet).
- Real failing/passing feature PR, merge, DEV/QA deployment, production review and PROD deployment.

No specialized `sql-verify` agent is available in this session. Static checks are not a substitute for live SQL compilation. The connected SQL tool points at Snowhouse, and the approved plan prohibits laptop deployment; neither boundary was bypassed.

## Resume sequence

1. Presenter runs the manual scripts in the demo account, stopping on errors and retaining actual results.
2. Resolve private-repository required-reviewer capability; keep PROD disabled until verified.
3. Initial publication is now authorized with deployments disabled. Later pushes and deployment enablement remain separate approval boundaries.
4. Publish with deployments disabled, inspect static run, configure main protection, and enable only approved environments.
5. Run baseline and the 20-minute feature sequence in DEMO.md. Append actual run/PR URLs and observed results here.

There are no baseline or feature run URLs to report yet. Designed dollar values in the demo guide are expectations, not observations.
