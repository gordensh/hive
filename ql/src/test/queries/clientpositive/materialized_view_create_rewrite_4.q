set hive.support.concurrency=true;
set hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
set hive.strict.checks.cartesian.product=false;
set hive.materializedview.rewriting=true;

create table cmv_basetable (a int, b varchar(256), c decimal(10,2), d int) stored as orc TBLPROPERTIES ('transactional'='true');

insert into cmv_basetable values
 (1, 'alfred', 10.30, 2),
 (2, 'bob', 3.14, 3),
 (2, 'bonnie', 172342.2, 3),
 (3, 'calvin', 978.76, 3),
 (3, 'charlie', 9.8, 1);

analyze table cmv_basetable compute statistics for columns;

create table cmv_basetable_2 (a int, b varchar(256), c decimal(10,2), d int) stored as orc TBLPROPERTIES ('transactional'='true');

insert into cmv_basetable_2 values
 (1, 'alfred', 10.30, 2),
 (3, 'calvin', 978.76, 3);

analyze table cmv_basetable_2 compute statistics for columns;

-- CREATE VIEW WITH REWRITE DISABLED
EXPLAIN
CREATE MATERIALIZED VIEW cmv_mat_view TBLPROPERTIES ('transactional'='true') AS
  SELECT cmv_basetable.a, cmv_basetable_2.c, sum(cmv_basetable_2.d)
  FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
  WHERE cmv_basetable_2.c > 10.0
  GROUP BY cmv_basetable.a, cmv_basetable_2.c;

CREATE MATERIALIZED VIEW cmv_mat_view TBLPROPERTIES ('transactional'='true') AS
  SELECT cmv_basetable.a, cmv_basetable_2.c, sum(cmv_basetable_2.d)
  FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
  WHERE cmv_basetable_2.c > 10.0
  GROUP BY cmv_basetable.a, cmv_basetable_2.c;

analyze table cmv_mat_view compute statistics for columns;

DESCRIBE FORMATTED cmv_mat_view;

-- CANNOT USE THE VIEW, IT IS DISABLED FOR REWRITE
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

insert into cmv_basetable_2 values
 (3, 'charlie', 15.8, 1);

analyze table cmv_basetable_2 compute statistics for columns;

-- ENABLE FOR REWRITE
EXPLAIN
ALTER MATERIALIZED VIEW cmv_mat_view ENABLE REWRITE;

ALTER MATERIALIZED VIEW cmv_mat_view ENABLE REWRITE;

DESCRIBE FORMATTED cmv_mat_view;

-- CANNOT USE THE VIEW, IT IS OUTDATED
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

-- REBUILD
EXPLAIN
ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

DESCRIBE FORMATTED cmv_mat_view;

-- NOW IT CAN BE USED AGAIN
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

-- NOW AN UPDATE
UPDATE cmv_basetable_2 SET a=2 WHERE a=1;

-- INCREMENTAL REBUILD CANNOT BE TRIGGERED
EXPLAIN
ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

-- MV CAN BE USED
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

-- NOW A DELETE
DELETE FROM cmv_basetable_2 WHERE a=2;

-- INCREMENTAL REBUILD CANNOT BE TRIGGERED
EXPLAIN
ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

-- MV CAN BE USED
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

-- NOW AN INSERT
insert into cmv_basetable_2 values
 (1, 'charlie', 15.8, 1);

-- INCREMENTAL REBUILD CAN BE TRIGGERED AGAIN
EXPLAIN
ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

ALTER MATERIALIZED VIEW cmv_mat_view REBUILD;

-- MV CAN BE USED
EXPLAIN
SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable join cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

SELECT cmv_basetable.a, sum(cmv_basetable_2.d)
FROM cmv_basetable JOIN cmv_basetable_2 ON (cmv_basetable.a = cmv_basetable_2.a)
WHERE cmv_basetable_2.c > 10.10
GROUP BY cmv_basetable.a, cmv_basetable_2.c;

drop materialized view cmv_mat_view;
