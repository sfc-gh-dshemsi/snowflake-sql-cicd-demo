-- Independent constants, not derived by calling the implementation under test.
-- 15% GOLD discount: 30/15 discounts, 170/85 net amounts, 504.99 total net sales.
CALL <% database %>.<% silver %>.PROCESS_ORDERS();
EXECUTE IMMEDIATE $$
DECLARE
    failures NUMBER;
    test_failed EXCEPTION (-20010, 'Retail SQL assertions failed; inspect fixture and business definitions');
BEGIN
    SELECT COUNT(*) INTO :failures FROM (
      SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(200, ' gold ') AS ACTUAL, 30.00 AS EXPECTED
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(100, 'GOLD'), 15.00
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(99.99, 'GOLD'), 0.00
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(200, 'STANDARD'), 0.00
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(NULL, 'GOLD'), 0.00
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(200, NULL), 0.00
      UNION ALL SELECT <% database %>.<% silver %>.CALCULATE_DISCOUNT(-10, 'GOLD'), 0.00
    ) WHERE ACTUAL IS DISTINCT FROM EXPECTED;
    IF (failures <> 0) THEN RAISE test_failed; END IF;

    SELECT COUNT(*) INTO :failures FROM (
      SELECT * FROM VALUES
        (101, 'ACCEPTED', NULL,               170.00),
        (102, 'ACCEPTED', NULL,                99.99),
        (103, 'ACCEPTED', NULL,               150.00),
        (104, 'ACCEPTED', NULL,                85.00),
        (105, 'REJECTED', 'CANCELLED',          NULL),
        (106, 'REJECTED', 'INVALID_AMOUNT',     NULL),
        (107, 'REJECTED', 'UNKNOWN_CUSTOMER',   NULL),
        (108, 'REJECTED', 'INVALID_AMOUNT',     NULL),
        (109, 'REJECTED', 'INVALID_STATUS',     NULL),
        (110, 'REJECTED', 'INVALID_AMOUNT',     NULL),
        (111, 'REJECTED', 'MISSING_DATE',       NULL)
      AS expected(ORDER_ID, VALIDATION_STATUS, REJECTION_REASON, NET_AMOUNT)
    ) AS expected
    LEFT JOIN <% database %>.<% silver %>.PROCESSED_ORDERS AS actual
      ON expected.ORDER_ID = actual.ORDER_ID
    WHERE actual.ORDER_ID IS NULL
       OR actual.VALIDATION_STATUS IS DISTINCT FROM expected.VALIDATION_STATUS
       OR actual.REJECTION_REASON IS DISTINCT FROM expected.REJECTION_REASON
       OR actual.NET_AMOUNT IS DISTINCT FROM expected.NET_AMOUNT;
    IF (failures <> 0) THEN RAISE test_failed; END IF;

    SELECT COUNT(*) INTO :failures
    FROM <% database %>.<% silver %>.V_CUSTOMERS_CLEAN
    WHERE CUSTOMER_ID = 1 AND CUSTOMER_NAME = 'Alice Morgan'
      AND EMAIL = 'alice@example.test' AND CUSTOMER_TIER = 'GOLD';
    IF (failures <> 1) THEN RAISE test_failed; END IF;

    SELECT COUNT(*) INTO :failures
    FROM <% database %>.<% gold %>.V_CUSTOMER_SALES
    WHERE CUSTOMER_ID = 4 AND COMPLETED_ORDERS = 0 AND NET_SALES = 0;
    IF (failures <> 1) THEN RAISE test_failed; END IF;

    SELECT COUNT(*) INTO :failures FROM (
      SELECT SUM(NET_SALES) AS TOTAL, SUM(COMPLETED_ORDERS) AS ORDER_COUNT
      FROM <% database %>.<% gold %>.V_CUSTOMER_SALES
    ) WHERE TOTAL = 504.99 AND ORDER_COUNT = 4;
    IF (failures <> 1) THEN RAISE test_failed; END IF;

    SELECT COUNT(*) INTO :failures FROM (
      SELECT ORDER_ID FROM <% database %>.<% silver %>.PROCESSED_ORDERS
      GROUP BY ORDER_ID HAVING COUNT(*) <> 1
    );
    IF (failures <> 0) THEN RAISE test_failed; END IF;
    RETURN 'PASS: discounts, boundaries, nulls, normalization, rejected orders, customer totals';
END;
$$;

-- Compare all columns and multiplicities, not just a row count, across a second CALL.
CREATE TEMP TABLE <% database %>.<% silver %>.CI_PROCESSED_BEFORE AS
SELECT * FROM <% database %>.<% silver %>.PROCESSED_ORDERS;
CALL <% database %>.<% silver %>.PROCESS_ORDERS();
EXECUTE IMMEDIATE $$
DECLARE
    differences NUMBER;
    rerun_failed EXCEPTION (-20011, 'Second procedure call changed processed data');
BEGIN
    SELECT COUNT(*) INTO :differences FROM (
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_PROCESSED_BEFORE GROUP BY ALL
       MINUS
       SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.PROCESSED_ORDERS GROUP BY ALL)
      UNION ALL
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.PROCESSED_ORDERS GROUP BY ALL
       MINUS
       SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_PROCESSED_BEFORE GROUP BY ALL)
    );
    IF (differences <> 0) THEN RAISE rerun_failed; END IF;
    RETURN 'PASS: procedure rerun preserves all processed values';
END;
$$;
EXECUTE IMMEDIATE $$
DECLARE
    task_query VARCHAR;
    matches NUMBER;
    task_failed EXCEPTION (-20012, 'Expected exactly one suspended task');
BEGIN
    SHOW TASKS LIKE 'PROCESS_ORDERS_TASK' IN SCHEMA <% database %>.<% silver %>;
    task_query := SQLID;
    SELECT COUNT(*) INTO :matches FROM TABLE(RESULT_SCAN(:task_query))
    WHERE "name" = 'PROCESS_ORDERS_TASK' AND "state" = 'suspended';
    IF (matches <> 1) THEN RAISE task_failed; END IF;
    RETURN 'PASS: task suspended';
END;
$$;
