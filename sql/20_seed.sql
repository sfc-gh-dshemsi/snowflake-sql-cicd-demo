-- Synthetic fixtures. Insert missing keys only; do not overwrite existing data.
MERGE INTO <% database %>.<% bronze %>.CUSTOMERS AS target
USING (
    SELECT CUSTOMER_ID, CUSTOMER_NAME, EMAIL, CUSTOMER_TIER
    FROM VALUES
        (1, ' Alice Morgan ', ' ALICE@example.test ', ' gold '),
        (2, 'Ben Carter', 'ben@example.test', 'standard'),
        (3, 'Cara Reed', 'cara@example.test', 'GOLD'),
        (4, 'Drew Stone', 'drew@example.test', 'STANDARD')
    AS source(CUSTOMER_ID, CUSTOMER_NAME, EMAIL, CUSTOMER_TIER)
) AS source
ON target.CUSTOMER_ID = source.CUSTOMER_ID
WHEN NOT MATCHED THEN INSERT (CUSTOMER_ID, CUSTOMER_NAME, EMAIL, CUSTOMER_TIER)
VALUES (source.CUSTOMER_ID, source.CUSTOMER_NAME, source.EMAIL, source.CUSTOMER_TIER);

MERGE INTO <% database %>.<% bronze %>.ORDERS AS target
USING (
    SELECT ORDER_ID, CUSTOMER_ID, TO_DATE(ORDER_DATE) AS ORDER_DATE,
           ORDER_AMOUNT, ORDER_STATUS
    FROM VALUES
        (101, 1, '2026-10-01', 200.00, ' completed '),
        (102, 1, '2026-10-02',  99.99, 'COMPLETED'),
        (103, 2, '2026-10-03', 150.00, 'COMPLETED'),
        (104, 3, '2026-10-04', 100.00, 'COMPLETED'),
        (105, 1, '2026-10-05',  75.00, 'CANCELLED'),
        (106, 2, '2026-10-06', -10.00, 'COMPLETED'),
        (107, 99,'2026-10-07',  50.00, 'COMPLETED'),
        (108, 3, '2026-10-08',   NULL, 'COMPLETED'),
        (109, 3, '2026-10-09',  50.00, NULL),
        (110, 2, '2026-10-10',   0.00, 'COMPLETED'),
        (111, 2, NULL,          20.00, 'COMPLETED')
    AS source(ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_AMOUNT, ORDER_STATUS)
) AS source
ON target.ORDER_ID = source.ORDER_ID
WHEN NOT MATCHED THEN INSERT (ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_AMOUNT, ORDER_STATUS)
VALUES (source.ORDER_ID, source.CUSTOMER_ID, source.ORDER_DATE,
        source.ORDER_AMOUNT, source.ORDER_STATUS);
