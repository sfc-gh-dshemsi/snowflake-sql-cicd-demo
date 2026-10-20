CREATE TASK IF NOT EXISTS <% database %>.<% silver %>.PROCESS_ORDERS_TASK
    WAREHOUSE = RETAIL_CICD_WH
    SCHEDULE = '60 MINUTE'
    USER_TASK_TIMEOUT_MS = 300000
AS CALL <% database %>.<% silver %>.PROCESS_ORDERS();
ALTER TASK <% database %>.<% silver %>.PROCESS_ORDERS_TASK SUSPEND;
ALTER TASK <% database %>.<% silver %>.PROCESS_ORDERS_TASK
    MODIFY AS CALL <% database %>.<% silver %>.PROCESS_ORDERS();
-- Intentionally no RESUME or EXECUTE TASK. The workflow tests CALL directly.
