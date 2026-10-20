-- Written only after all tests succeed. Earlier failed DDL is not rolled back.
INSERT INTO <% database %>.<% silver %>.DEPLOYMENT_HISTORY
    (COMMIT_SHA, RUN_ID, RUN_ATTEMPT, DEPLOYED_BY, ROLE_NAME)
SELECT '<% commit_sha %>', '<% run_id %>', '<% run_attempt %>', CURRENT_USER(), CURRENT_ROLE();
SELECT * FROM <% database %>.<% silver %>.DEPLOYMENT_HISTORY ORDER BY DEPLOYED_AT DESC;
SELECT * FROM <% database %>.<% gold %>.V_CUSTOMER_SALES ORDER BY CUSTOMER_ID;
