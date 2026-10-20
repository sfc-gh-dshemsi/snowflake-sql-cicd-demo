-- Conservative visibility checks: an unexpected cross-environment grant fails CI.
EXECUTE IMMEDIATE $$
DECLARE
    metadata_query VARCHAR;
    unexpected NUMBER;
    isolation_failed EXCEPTION (-20014, 'Cross-environment visibility detected; inspect role and PUBLIC grants');
BEGIN
    SHOW DATABASES;
    metadata_query := SQLID;
    SELECT COUNT(*) INTO :unexpected FROM TABLE(RESULT_SCAN(:metadata_query))
    WHERE "name" IN ('DEV_DB', 'QA_DB', 'PROD_DB') AND "name" <> '<% database %>';
    IF (unexpected <> 0) THEN RAISE isolation_failed; END IF;
    SHOW SCHEMAS IN DATABASE <% database %>;
    metadata_query := SQLID;
    SELECT COUNT(*) INTO :unexpected FROM TABLE(RESULT_SCAN(:metadata_query))
    WHERE "name" IN ('BRONZE', 'SILVER', 'GOLD', 'CI_BRONZE', 'CI_SILVER', 'CI_GOLD')
      AND "name" NOT IN ('<% bronze %>', '<% silver %>', '<% gold %>');
    IF (unexpected <> 0) THEN RAISE isolation_failed; END IF;
    RETURN 'PASS: no other demo environment visible to this identity';
END;
$$;
