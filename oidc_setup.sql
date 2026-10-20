-- MANUAL SNOWSIGHT ONLY. Run after setup.sql; no password, key or token to paste.
-- Authentication direction: GitHub Actions -> Snowflake.
-- Exact subject prefix verified using the repository OIDC customization API.
-- Existing users are NOT replaced or reconfigured: inspect DESC/SHOW GRANTS on rerun.
-- Keep PROD disabled until GitHub required reviewers and main-only branches are enforced.
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES NONE;
EXECUTE IMMEDIATE $$
DECLARE
    wrong_target EXCEPTION (-20001, 'STOP: expected demo account / DSHEMSI');
BEGIN
    IF (CURRENT_ORGANIZATION_NAME() <> 'SFSENORTHAMERICA'
        OR CURRENT_ACCOUNT_NAME() <> 'DSHEMSI_AWS1'
        OR CURRENT_USER() <> 'DSHEMSI') THEN
        RAISE wrong_target;
    END IF;
    CREATE USER IF NOT EXISTS RETAIL_PR_SVC
      TYPE = SERVICE
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222:pull_request'
        OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
      )
      DEFAULT_ROLE = RETAIL_PR_DEPLOY DEFAULT_WAREHOUSE = RETAIL_CICD_WH
      COMMENT = 'Retail demo: trusted PRs; CI schemas only';
    CREATE USER IF NOT EXISTS RETAIL_DEV_SVC
      TYPE = SERVICE
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222:environment:dev'
        OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
      )
      DEFAULT_ROLE = RETAIL_DEV_DEPLOY DEFAULT_WAREHOUSE = RETAIL_CICD_WH;
    CREATE USER IF NOT EXISTS RETAIL_QA_SVC
      TYPE = SERVICE
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222:environment:qa'
        OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
      )
      DEFAULT_ROLE = RETAIL_QA_DEPLOY DEFAULT_WAREHOUSE = RETAIL_CICD_WH;
    CREATE USER IF NOT EXISTS RETAIL_PROD_SVC
      TYPE = SERVICE DISABLED = TRUE
      WORKLOAD_IDENTITY = (
        TYPE = OIDC
        ISSUER = 'https://token.actions.githubusercontent.com'
        SUBJECT = 'repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222:environment:prod'
        OIDC_AUDIENCE_LIST = ('snowflakecomputing.com')
      )
      DEFAULT_ROLE = RETAIL_PROD_DEPLOY DEFAULT_WAREHOUSE = RETAIL_CICD_WH
      COMMENT = 'Disabled until private repository production approval is supported and verified';
    GRANT ROLE RETAIL_PR_DEPLOY TO USER RETAIL_PR_SVC;
    GRANT ROLE RETAIL_DEV_DEPLOY TO USER RETAIL_DEV_SVC;
    GRANT ROLE RETAIL_QA_DEPLOY TO USER RETAIL_QA_SVC;
    GRANT ROLE RETAIL_PROD_DEPLOY TO USER RETAIL_PROD_SVC;
END;
$$;
DESC USER RETAIL_PR_SVC;
DESC USER RETAIL_DEV_SVC;
DESC USER RETAIL_QA_SVC;
DESC USER RETAIL_PROD_SVC;
SHOW GRANTS TO USER RETAIL_PR_SVC;
SHOW GRANTS TO USER RETAIL_DEV_SVC;
SHOW GRANTS TO USER RETAIL_QA_SVC;
SHOW GRANTS TO USER RETAIL_PROD_SVC;
-- Review inherited PUBLIC grants too; these scripts never revoke existing account grants.
SHOW GRANTS TO ROLE PUBLIC;
