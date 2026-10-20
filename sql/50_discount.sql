-- Returns a discount amount, not a rate. GOLD orders >= 100 qualify.
-- Feature demo: change 0.10 to 0.15 AND update independent expectations in tests.
CREATE OR REPLACE FUNCTION <% database %>.<% silver %>.CALCULATE_DISCOUNT(
    ORDER_AMOUNT NUMBER(12,2), CUSTOMER_TIER VARCHAR
)
COPY GRANTS
RETURNS NUMBER(12,2)
IMMUTABLE
AS $$
    CASE
      WHEN ORDER_AMOUNT IS NULL OR ORDER_AMOUNT <= 0 THEN 0.00
      WHEN UPPER(TRIM(CUSTOMER_TIER)) = 'GOLD' AND ORDER_AMOUNT >= 100.00
        THEN ROUND(ORDER_AMOUNT * 0.10, 2)
      ELSE 0.00
    END
$$;
