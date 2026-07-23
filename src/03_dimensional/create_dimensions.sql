-- =============================================================================
-- Camada: Dimensional - Criação das dimensões
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Materialização das dimensões do nosso esquema estrela, definido em
--            docs/adrs/0002-star-schema.md.
-- =============================================================================

-- =============================================================================
-- Bloco 1: dim_location
-- Descrição: Materiaização da dimensão de localização(dim_location).
-- =============================================================================

CREATE OR REPLACE TABLE dim_location AS
SELECT DISTINCT
    MD5(CAST(location_id AS VARCHAR)) AS location_key,
    location_id,
    borough,
    zone,
    service_zone
FROM stg_zone_lookup
UNION ALL
SELECT 
    'MD5_UNKNOWN' AS location_key,
    -1 AS location_id,
    'UNKNOWN' AS borough,
    'UNKNOWN' AS zone,
    'UNKNOWN' AS service_zone;

DESCRIBE dim_location;
-- =============================================================================
-- Bloco 2: dim_time
-- Descrição: Materiaização da dimensão de tempo(dim_time).
-- =============================================================================

CREATE OR REPLACE TABLE dim_time AS
SELECT DISTINCT
    MD5(STRFTIME(CAST(pickup_datetime AS DATE), '%Y-%m-%d')) AS time_key,
    CAST(pickup_datetime AS DATE) AS date,
    YEAR(pickup_datetime) AS year,
    CASE
        WHEN MONTH(pickup_datetime) BETWEEN 1 AND 6 THEN 1
        ELSE 2
    END AS semester,
    QUARTER(pickup_datetime) AS quarter,
    MONTH(pickup_datetime) AS month,
    DAY(pickup_datetime) AS day,
    DAYOFWEEK(pickup_datetime) AS day_of_week,
    CASE
        WHEN day_of_week == 0 OR day_of_week == 6 THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM stg_yellow_taxi
UNION ALL
SELECT
    'MD5_UNKNOWN' AS time_key,
    DATE('1900-01-01') AS date,
    -1 AS year,
    -1 AS semester,
    -1 AS quarter,
    -1 AS month,
    -1 AS day,
    -1 AS day_of_week,
    FALSE AS is_weekend;

DESCRIBE dim_time;