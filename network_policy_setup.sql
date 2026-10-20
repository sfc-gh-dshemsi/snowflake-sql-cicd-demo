-- MANUAL SNOWSIGHT ONLY. Network direction: GitHub-hosted runners -> Snowflake.
-- Run the inspection section first. Review with your account security administrator.
-- A user-level policy can supersede account-level restrictions: do not treat this as
-- an additive exception. Keep any organizational requirements after explicit review.
USE ROLE ACCOUNTADMIN;
SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME(), CURRENT_USER();
SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN ACCOUNT;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' FOR USER RETAIL_PR_SVC;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' FOR USER RETAIL_DEV_SVC;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' FOR USER RETAIL_QA_SVC;
SHOW PARAMETERS LIKE 'NETWORK_POLICY' FOR USER RETAIL_PROD_SVC;
SHOW NETWORK POLICIES LIKE 'RETAIL_GITHUB_RUNNERS';

-- Run this entire block only after review. It refuses to overwrite another policy.
-- It never changes DSHEMSI or the account-level policy.
EXECUTE IMMEDIATE $$
DECLARE
    wrong_target EXCEPTION (-20001, 'STOP: expected demo account / DSHEMSI');
    policy_conflict EXCEPTION (-20002, 'STOP: an automation user has a different effective policy; review manually');
    users RESULTSET DEFAULT (
        SELECT COLUMN1 AS USER_NAME FROM VALUES
          ('RETAIL_PR_SVC'), ('RETAIL_DEV_SVC'), ('RETAIL_QA_SVC'), ('RETAIL_PROD_SVC')
    );
    statement_text VARCHAR;
    policy_query_id VARCHAR;
    conflicts NUMBER;
BEGIN
    IF (CURRENT_ORGANIZATION_NAME() <> 'SFSENORTHAMERICA'
        OR CURRENT_ACCOUNT_NAME() <> 'DSHEMSI_AWS1'
        OR CURRENT_USER() <> 'DSHEMSI') THEN
        RAISE wrong_target;
    END IF;
    FOR service_user IN users DO
        statement_text := 'SHOW PARAMETERS LIKE ''NETWORK_POLICY'' FOR USER ' || service_user.USER_NAME;
        EXECUTE IMMEDIATE :statement_text;
        policy_query_id := SQLID;
        SELECT COUNT(*) INTO :conflicts
        FROM TABLE(RESULT_SCAN(:policy_query_id))
        WHERE COALESCE("value", '') NOT IN ('', 'RETAIL_GITHUB_RUNNERS');
        IF (conflicts > 0) THEN
            RAISE policy_conflict;
        END IF;
    END FOR;
    CREATE NETWORK POLICY IF NOT EXISTS RETAIL_GITHUB_RUNNERS
      ALLOWED_NETWORK_RULE_LIST = ('SNOWFLAKE.NETWORK_SECURITY.GITHUBACTIONS_GLOBAL')
      COMMENT = 'Retail demo automation users only; not repository identity enforcement';
    -- IF NOT EXISTS preserves existing policy contents. Review DESC before attaching
    -- on rerun; use a separately reviewed ALTER if contents differ from this definition.
END;
$$;
DESC NETWORK POLICY RETAIL_GITHUB_RUNNERS;

-- Deliberately commented: after reviewing the policy and ALL four effective policies,
-- select/uncomment the block below. Its guard is repeated to prevent wrong-account use.
/*
EXECUTE IMMEDIATE $$
DECLARE
    wrong_target EXCEPTION (-20001, 'STOP: expected demo account / DSHEMSI');
    policy_conflict EXCEPTION (-20002, 'STOP: different effective policy; no attachments changed');
    users RESULTSET DEFAULT (
        SELECT COLUMN1 AS USER_NAME FROM VALUES
          ('RETAIL_PR_SVC'), ('RETAIL_DEV_SVC'), ('RETAIL_QA_SVC'), ('RETAIL_PROD_SVC')
    );
    statement_text VARCHAR;
    policy_query_id VARCHAR;
    conflicts NUMBER;
BEGIN
    IF (CURRENT_ORGANIZATION_NAME() <> 'SFSENORTHAMERICA'
        OR CURRENT_ACCOUNT_NAME() <> 'DSHEMSI_AWS1'
        OR CURRENT_USER() <> 'DSHEMSI') THEN
        RAISE wrong_target;
    END IF;
    FOR service_user IN users DO
        statement_text := 'SHOW PARAMETERS LIKE ''NETWORK_POLICY'' FOR USER ' || service_user.USER_NAME;
        EXECUTE IMMEDIATE :statement_text;
        policy_query_id := SQLID;
        SELECT COUNT(*) INTO :conflicts
        FROM TABLE(RESULT_SCAN(:policy_query_id))
        WHERE COALESCE("value", '') NOT IN ('', 'RETAIL_GITHUB_RUNNERS');
        IF (conflicts > 0) THEN RAISE policy_conflict; END IF;
    END FOR;
    ALTER USER RETAIL_PR_SVC SET NETWORK_POLICY = RETAIL_GITHUB_RUNNERS;
    ALTER USER RETAIL_DEV_SVC SET NETWORK_POLICY = RETAIL_GITHUB_RUNNERS;
    ALTER USER RETAIL_QA_SVC SET NETWORK_POLICY = RETAIL_GITHUB_RUNNERS;
    ALTER USER RETAIL_PROD_SVC SET NETWORK_POLICY = RETAIL_GITHUB_RUNNERS;
END;
$$;
*/
-- Verify by repeating the four SHOW PARAMETERS statements above.
