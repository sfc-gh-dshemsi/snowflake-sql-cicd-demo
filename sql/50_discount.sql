-- Returns a discount amount, not a rate. GOLD orders >= 100 qualify.
-- CI/CD demo change: qualifying GOLD orders receive a 15% discount.
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
        THEN ROUND(ORDER_AMOUNT * 0.15, 2)
      ELSE 0.00
    END
$$;
