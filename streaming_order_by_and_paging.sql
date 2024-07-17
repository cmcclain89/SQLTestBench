-- Wanted to test some things I learned while reading https://use-the-index-luke.com/sql/partial-results/fetch-next-page
CREATE TABLE resources (
  id serial PRIMARY KEY,
  merchant_id int NOT NULL,
  resource_id int NOT NULL,
  type varchar(255),
  syncable bool NOT NULL,
  ignored bool NOT NULL,
  warnings text[],
  attributes jsonb,
  inserted_at timestamp,
  updated_at timestamp
 );

INSERT INTO resources (merchant_id, resource_id, type, syncable, ignored, warnings, attributes, inserted_at, updated_at)
SELECT 
	(i % 10) + 1,
  200000000 + i,
  case 
  	when i % 3 = 0 THEN 'doll'
  	when i % 3 = 1 THEN 'customer'
    when i % 3 = 2 THEN 'order'
  end,
  case 
  	when i % 13 = 0 THEN FALSE
  	else TRUE
  end,
  case
  	when i % 29 = 0 THEN TRUE
    else FALSE
  end,
  case
  	when i % 10 = 1 THEN ARRAY['group code mismatch']
    when i % 10 = 2 THEN ARRAY['color added but no group code']
    when i % 10 = 3 THEN ARRAY['weird lookin fella', 'something something']
    else null
  end,
  ('{
    "price": 1000, 
    "color": "red",
    "size": "large"
    }'::jsonb || ('{"barcode": "abc-12' || cast(i as text) || '"}')::jsonb),
  current_timestamp - (round(random() * 1000) || ' minutes')::interval,
  current_timestamp - (round(random() * 1000) || ' minutes')::interval
FROM generate_series(1, 5000000) as i;

-- Start with this! If you write queries that start from the top of the sort order for updated_at,
-- you'll get pretty fast results. As you go back in time, the time required to find and return the results
-- increases. This has to go back page by page.
CREATE INDEX updated_at_sort_idx ON resources (updated_at DESC);
-- Fast!
SELECT * from resources ORDER BY updated_at DESC LIMIT 10;
-- Not so fast...
SELECT * from resources ORDER BY updated_at DESC OFFSET 100000 LIMIT 10;
-- Yikes!
SELECT * from resources ORDER BY updated_at DESC OFFSET 450000 LIMIT 10;

-- Let's drop the previous index and try a different approach
DROP INDEX updated_at_sort_idx;
CREATE INDEX updated_at_id_sort_idx ON resources (updated_at, id);

-- We'll include Id since it's a deterministic value, and we need that for paging
-- The (column, column) is row-values syntax.

-- Still kind of slow. But we can improve this by including a where clause. In the below, grab the last id and updated_at value.
SELECT * FROM resources ORDER BY updated_at DESC, id DESC LIMIT 10 OFFSET 450000;

-- The below are the two I had as the last row at the time I wrote this; obviously yours will be different
-- 6693469
-- 2024-05-02 22:27:51.269268

-- Use this just to confirm we are getting the same 10 that we expect
SELECT * FROM resources ORDER BY updated_at DESC, id DESC OFFSET 450010 LIMIT 10;

-- This is much faster. Either syntax is fine.
SELECT * FROM resources WHERE (updated_at, id) < ('2024-05-02 22:27:51.269268', 6693469) ORDER BY updated_at DESC, id DESC LIMIT 10;
SELECT * FROM resources WHERE (updated_at, id) < ('2024-05-02 22:27:51.269268', 6693469) ORDER BY updated_at DESC, id FETCH FIRST 10 ROWS ONLY;
