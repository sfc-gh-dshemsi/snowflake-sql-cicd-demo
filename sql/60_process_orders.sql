CREATE OR REPLACE PROCEDURE <% database %>.<% silver %>.PROCESS_ORDERS()
COPY GRANTS
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS $$
DECLARE
    bad_keys NUMBER;
    duplicate_key EXCEPTION (-20003, 'Duplicate customer/order/processed keys: MERGE refused');
BEGIN
    SELECT COUNT(*) INTO :bad_keys FROM (
      SELECT CUSTOMER_ID FROM <% database %>.<% bronze %>.CUSTOMERS
      GROUP BY CUSTOMER_ID HAVING COUNT(*) > 1
      UNION ALL
      SELECT ORDER_ID FROM <% database %>.<% bronze %>.ORDERS
      GROUP BY ORDER_ID HAVING COUNT(*) > 1
      UNION ALL
      SELECT ORDER_ID FROM <% database %>.<% silver %>.PROCESSED_ORDERS
      GROUP BY ORDER_ID HAVING COUNT(*) > 1
    );
    IF (bad_keys > 0) THEN RAISE duplicate_key; END IF;

    MERGE INTO <% database %>.<% silver %>.PROCESSED_ORDERS AS target
    USING (
      SELECT ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_AMOUNT,
             IFF(REJECTION_REASON IS NULL,
                 <% database %>.<% silver %>.CALCULATE_DISCOUNT(ORDER_AMOUNT, CUSTOMER_TIER),
                 0.00) AS DISCOUNT_AMOUNT,
             IFF(REJECTION_REASON IS NULL,
                 ORDER_AMOUNT - <% database %>.<% silver %>.CALCULATE_DISCOUNT(ORDER_AMOUNT, CUSTOMER_TIER),
                 NULL) AS NET_AMOUNT,
             IFF(REJECTION_REASON IS NULL, 'ACCEPTED', 'REJECTED') AS VALIDATION_STATUS,
             REJECTION_REASON
      FROM <% database %>.<% silver %>.V_ORDERS_CLEAN
    ) AS source
    ON target.ORDER_ID = source.ORDER_ID
    WHEN MATCHED THEN UPDATE SET
      CUSTOMER_ID = source.CUSTOMER_ID, ORDER_DATE = source.ORDER_DATE,
      ORDER_AMOUNT = source.ORDER_AMOUNT, DISCOUNT_AMOUNT = source.DISCOUNT_AMOUNT,
      NET_AMOUNT = source.NET_AMOUNT, VALIDATION_STATUS = source.VALIDATION_STATUS,
      REJECTION_REASON = source.REJECTION_REASON
    WHEN NOT MATCHED THEN INSERT (
      ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_AMOUNT, DISCOUNT_AMOUNT,
      NET_AMOUNT, VALIDATION_STATUS, REJECTION_REASON
    ) VALUES (
      source.ORDER_ID, source.CUSTOMER_ID, source.ORDER_DATE, source.ORDER_AMOUNT,
      source.DISCOUNT_AMOUNT, source.NET_AMOUNT, source.VALIDATION_STATUS, source.REJECTION_REASON
    );
    RETURN 'Orders processed; rejected rows retained with reasons';
END;
$$;
