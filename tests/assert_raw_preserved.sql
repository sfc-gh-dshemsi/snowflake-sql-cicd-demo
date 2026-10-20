EXECUTE IMMEDIATE $$
DECLARE
    differences NUMBER;
    preservation_failed EXCEPTION (-20013, 'Redeployment changed raw data or multiplicities');
BEGIN
    SELECT COUNT(*) INTO :differences FROM (
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_CUSTOMERS_BEFORE GROUP BY ALL
       MINUS SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% bronze %>.CUSTOMERS GROUP BY ALL)
      UNION ALL
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% bronze %>.CUSTOMERS GROUP BY ALL
       MINUS SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_CUSTOMERS_BEFORE GROUP BY ALL)
    );
    IF (differences <> 0) THEN RAISE preservation_failed; END IF;
    SELECT COUNT(*) INTO :differences FROM (
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_ORDERS_BEFORE GROUP BY ALL
       MINUS SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% bronze %>.ORDERS GROUP BY ALL)
      UNION ALL
      (SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% bronze %>.ORDERS GROUP BY ALL
       MINUS SELECT *, COUNT(*) AS COPIES FROM <% database %>.<% silver %>.CI_ORDERS_BEFORE GROUP BY ALL)
    );
    IF (differences <> 0) THEN RAISE preservation_failed; END IF;
    RETURN 'PASS: second deployment preserved every raw row';
END;
$$;
