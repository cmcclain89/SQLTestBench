
CREATE TABLE composite_key_order_test (
  primary_id int NOT NULL,
  secondary_key int NOT NULL,
  tertiary_key int NOT NULL,
  boss_key int NOT NULL,
  some_content varchar(255)
 );

INSERT INTO composite_key_order_test (primary_id, secondary_key, tertiary_key, boss_key, some_content)
SELECT 
(i % 1000) + 1,
i / 1000 + 1,
round(random() * 10),
round(random() * 10000000),
md5(random()::text)
FROM generate_series(1, 10000000) as i;

CREATE UNIQUE INDEX composite_key_order_test_idx ON composite_key_order_test (primary_id, secondary_key, tertiary_key)

-- With all keys. Just grab one set to test!
SELECT * FROM composite_key_order_test where primary_id = 500

-- Since we're using all the keys of the index, this will use the index cond
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE primary_id = 500 and secondary_key = 268 and tertiary_key = 8;

EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE tertiary_key = 8 and primary_id = 500 and secondary_key = 268;

-- Only using two, still fine...
-- This uses the index cond still, or might use a bitmap index scan until it figures out its unique
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE primary_id = 500 and secondary_key = 268;

-- This switches to using bitmap index scan, then a heap scan
-- but still isn't bad
EXPLAIN ANALYZE
SELECT * FROM composite_key_order_test WHERE primary_id = 500 and tertiary_key = 8;

-- but wait..., this uses seq scan! Even though it's using the index.
EXPLAIN ANALYZE
SELECT * FROM composite_key_order_test WHERE secondary_key = 268 and tertiary_key = 8;

EXPLAIN ANALYZE
SELECT * FROM composite_key_order_test WHERE tertiary_key = 8 and secondary_key = 268;

-- only using one. The first will use the index cond > bitmap indexscan, 
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE primary_id = 500;

-- parallel seq scan
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE secondary_key = 268;

-- seq scan ;(
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE tertiary_key = 8;

-- What if we change the key order?
DROP INDEX composite_key_order_test_idx
CREATE UNIQUE INDEX composite_key_order_test_idx ON composite_key_order_test (secondary_key, tertiary_key, primary_id)

-- This is still fine, uses index cond
EXPLAIN ANALYZE 
SELECT * FROM composite_key_order_test WHERE primary_id = 500 and secondary_key = 268 and tertiary_key = 8;

-- What about this?
EXPLAIN ANALYZE
SELECT * FROM composite_key_order_test WHERE secondary_key = 268 and tertiary_key = 8;

-- that was stil index cond. what about the following?
EXPLAIN ANALYZE
SELECT * FROM composite_key_order_test WHERE primary_id = 500 and tertiary_key = 8;

-- the seq scan is back

-- DROP TABLE composite_key_order_test