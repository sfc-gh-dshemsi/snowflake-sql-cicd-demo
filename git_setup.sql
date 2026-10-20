-- MANUAL SNOWSIGHT ONLY. This is NOT GitHub Actions OIDC.
-- Direction: your interactive Snowsight session -> private GitHub repository.
-- No personal access token in this file. SQL creates configuration; UI sign-in follows.
USE ROLE ACCOUNTADMIN;
EXECUTE IMMEDIATE $$
DECLARE
    wrong_target EXCEPTION (-20001, 'STOP: expected demo account / DSHEMSI');
BEGIN
    IF (CURRENT_ORGANIZATION_NAME() <> 'SFSENORTHAMERICA'
        OR CURRENT_ACCOUNT_NAME() <> 'DSHEMSI_AWS1'
        OR CURRENT_USER() <> 'DSHEMSI') THEN
        RAISE wrong_target;
    END IF;
    CREATE API INTEGRATION IF NOT EXISTS RETAIL_GITHUB_APP
      API_PROVIDER = git_https_api
      API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-dshemsi/snowflake-sql-cicd-demo.git')
      API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
      ENABLED = TRUE
      COMMENT = 'Interactive retail demo Git authorization; unrelated to deployment OIDC';
    GRANT USAGE ON INTEGRATION RETAIL_GITHUB_APP TO ROLE RETAIL_DEV_DEPLOY;
END;
$$;
DESC API INTEGRATION RETAIL_GITHUB_APP;
SHOW GRANTS ON INTEGRATION RETAIL_GITHUB_APP;

-- AFTER files have been published with your separate approval:
-- 1. Snowsight > Projects > Workspaces > From Git repository.
-- 2. URL: https://github.com/sfc-gh-dshemsi/snowflake-sql-cicd-demo.git
-- 3. Choose RETAIL_GITHUB_APP and complete the interactive GitHub sign-in/authorization.
-- 4. Authorize only this repository when selecting repositories for the GitHub App.
-- 5. Open main, create a feature branch, edit SQL and corresponding tests, commit and push.
-- 6. Open the pull request in GitHub. Do NOT edit DEV/QA/PROD SQL directly for promotion.
-- SQL alone does not complete OAuth. An empty repository has no main branch to import.
-- Actions checks out a commit SHA and runs SQL files directly; no Snowflake Git FETCH.
