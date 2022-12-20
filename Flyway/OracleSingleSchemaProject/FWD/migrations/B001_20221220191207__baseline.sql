﻿SET DEFINE OFF

CREATE TABLE test_result (
  "ID" NUMBER
);

CREATE TABLE contacts (
  contact_id NUMBER(6),
  first_name VARCHAR2(20 BYTE),
  last_name VARCHAR2(25 BYTE),
  address1 VARCHAR2(30 BYTE),
  address2 VARCHAR2(30 BYTE),
  address3 VARCHAR2(30 BYTE),
  zipcode VARCHAR2(10 BYTE),
  email VARCHAR2(24 BYTE),
  phone_number VARCHAR2(20 BYTE)
);

CREATE TABLE "TEST" (
  "ID" NUMBER
);

DECLARE
  objExists NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO objExists FROM ALL_OBJECTS WHERE OBJECT_TYPE = 'MATERIALIZED VIEW' AND OWNER = 'FWD_SHADOW' AND OBJECT_NAME = 'TEST_RESULT';
  IF (objExists > 0) THEN
     EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW TEST_RESULT';
  END IF;
END;


/

CREATE MATERIALIZED VIEW test_result
ON PREBUILT TABLE
AS SELECT ID
FROM TEST;

