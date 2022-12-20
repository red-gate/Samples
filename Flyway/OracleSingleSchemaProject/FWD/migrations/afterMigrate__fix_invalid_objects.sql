-- The content of the Oracle afterMigrate__fix_invalid_objects.sql file is a command that re-compiles any invalid database objects.
-- This is required because objects such as procedures, which are managed in repeatable migrations, can have dependencies
-- on other objects but Flyway runs all repeatable migrations in alphabetical order regardless of any dependencies.
-- Therefore some objects may not be properly compiled after flyway migrate completes.

BEGIN
<<objectloop>>
  FOR cur_rec IN (SELECT owner,
                         object_name,
                         object_type,
                         CASE object_type
                           WHEN 'PACKAGE' THEN 1
                           WHEN 'PACKAGE BODY' THEN 2
                           ELSE 3
                           END AS recompile_order
                  FROM sys.all_objects
                  WHERE status != 'VALID'
                  ORDER BY recompile_order ASC)
  LOOP
BEGIN
      IF cur_rec.object_type = 'PACKAGE BODY' THEN
        EXECUTE IMMEDIATE 'ALTER PACKAGE ""' || cur_rec.owner || '"".""' || cur_rec.object_name || '"" COMPILE BODY';
ElSE
        EXECUTE IMMEDIATE 'ALTER ' || cur_rec.object_type || ' ""' || cur_rec.owner || '"".""' || cur_rec.object_name || '"" COMPILE';
END IF;
EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line(cur_rec.object_type || ' : ' || cur_rec.owner || ' : ' || cur_rec.object_name || 'could not be compiled');
END;
END LOOP objectloop;
END;
