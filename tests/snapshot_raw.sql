CREATE TEMP TABLE <% database %>.<% silver %>.CI_CUSTOMERS_BEFORE AS
SELECT * FROM <% database %>.<% bronze %>.CUSTOMERS;
CREATE TEMP TABLE <% database %>.<% silver %>.CI_ORDERS_BEFORE AS
SELECT * FROM <% database %>.<% bronze %>.ORDERS;
