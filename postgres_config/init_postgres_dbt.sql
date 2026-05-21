-- Creates three databases: "data_lake", "dev" and "pro"
-- Creates the schema "olist" in the "data_lake" database as the landing zone for raw data
-- Creates the function "Word2Number" to convert number words (e.g. "Two Hundred" or "fifteen") to numeric digits (e.g. 200 or 15). This will be used in our silver model

CREATE DATABASE data_lake;
CREATE DATABASE dev;
CREATE DATABASE pro;

\c data_lake;

SET timezone = 'UTC';

CREATE SCHEMA IF NOT EXISTS olist;

\c dev;

SET timezone = 'UTC';

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION read_number(num NUMERIC) 
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT  
    LOWER(
        TRIM(
            REPLACE(
                REGEXP_REPLACE(
                    CASH_WORDS(num::money),
                    ' dollar.*', -- Cuts out currency and fractions
                    ''
                ),
                '  ', -- Removes accidental double spaces
                ' ' 
            )
        )
    )
$$;

CREATE TABLE number_readings AS 
    SELECT num,read_number(num) AS num_reading
    FROM generate_series(0,2e5,1) AS a(num);

CREATE INDEX ON number_readings (num_reading) INCLUDE (num) WITH (fillfactor=100);

CREATE OR REPLACE FUNCTION word2number(txt varchar)
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT num*(CASE WHEN LOWER(txt) ~ '^minus.*' THEN -1 ELSE 1 END)
FROM number_readings 
WHERE num_reading=TRIM(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                LOWER(txt),
                                ' and',
                                ''),
                            '-',
                            ' '),
                        'minus ',
                        '')
                    );
$$;

\c pro;

SET timezone = 'UTC';

CREATE EXTENSION dblink;

CREATE OR REPLACE FUNCTION read_number(num NUMERIC) 
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT  
    LOWER(
        TRIM(
            REPLACE(
                REGEXP_REPLACE(
                    CASH_WORDS(num::money),
                    ' dollar.*',-- Cuts out currency and fractions
                    ''
                ),
                '  ',-- Removes accidental double spaces
                ' ' 
            )
        )
    )
$$;

CREATE TABLE number_readings AS 
    SELECT num,read_number(num) AS num_reading
    FROM generate_series(0,2e5,1) AS a(num);

CREATE INDEX ON number_readings (num_reading) INCLUDE (num) WITH (fillfactor=100);

CREATE OR REPLACE FUNCTION word2number(txt varchar)
RETURNS VARCHAR 
LANGUAGE SQL 
IMMUTABLE STRICT 
AS 
$$
SELECT num*(CASE WHEN LOWER(txt) ~ '^minus.*' THEN -1 ELSE 1 END)
FROM number_readings 
WHERE num_reading=TRIM(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                LOWER(txt),
                                ' and',
                                ''),
                            '-',
                            ' '),
                        'minus ',
                        '')
                    );
$$;