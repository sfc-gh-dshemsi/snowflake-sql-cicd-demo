-- Persistent input data: never replace these tables during deployment.
CREATE TABLE IF NOT EXISTS <% database %>.<% bronze %>.CUSTOMERS (
    CUSTOMER_ID NUMBER(38,0) NOT NULL,
    CUSTOMER_NAME VARCHAR,
    EMAIL VARCHAR,
    CUSTOMER_TIER VARCHAR
);

CREATE TABLE IF NOT EXISTS <% database %>.<% bronze %>.ORDERS (
    ORDER_ID NUMBER(38,0) NOT NULL,
    CUSTOMER_ID NUMBER(38,0),
    ORDER_DATE DATE,
    ORDER_AMOUNT NUMBER(12,2),
    ORDER_STATUS VARCHAR
);
