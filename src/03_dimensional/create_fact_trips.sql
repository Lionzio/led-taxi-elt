-- =============================================================================
-- Camada: Dimensional - Criação da tabela fato
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Materialização das dimensões do nosso esquema estrela, definido em
--            docs/adrs/0002-star-schema.md.
-- =============================================================================

-- =============================================================================
-- Bloco 1: fact_trips
-- Descrição: Materiaização da tabela fato(fact_trips).
-- =============================================================================

CREATE OR REPLACE TABLE fact_trips(
    trip_key VARCHAR,
    time_key VARCHAR,
    pickup_location_key VARCHAR,
    dropoff_location_key VARCHAR,
    payment_key VARCHAR,
    pickup_datetime TIMESTAMP,
    dropoff_datetime TIMESTAMP,
    passenger_count INTEGER,
    trip_distance FLOAT,
    fare_amount DECIMAL,
    tip_amount DECIMAL,
    tolls_amount DECIMAL,
    total_amount DECIMAL,
    PRIMARY KEY (trip_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key),
    FOREIGN KEY (pickup_location_key) REFERENCES dim_location(location_key),
    FOREIGN KEY (dropoff_location_key) REFERENCES dim_location(location_key),
    FOREIGN KEY (payment_key) REFERENCES dim_payment(payment_key));

INSERT INTO fact_trips
SELECT DISTINCT
    MD5(
        CAST(pickup_datetime    AS VARCHAR) || '|' ||
        CAST(dropoff_datetime   AS VARCHAR) || '|' ||
        CAST(vendor_id          AS VARCHAR) || '|' ||
        CAST(pickup_location_id AS VARCHAR) || '|' ||
        CAST(dropoff_location_id AS VARCHAR) || '|' ||
        CAST(trip_distance AS VARCHAR) || '|' ||
        CAST(passenger_count AS VARCHAR)
    ) AS trip_key,
    time.time_key,
    pickup.location_key AS pickup_location_key,
    dropoff.location_key AS dropoff_location_key,
    pay.payment_key,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    fare_amount,
    tip_amount,
    tolls_amount,
    total_amount
FROM stg_yellow_taxi stg
LEFT JOIN dim_time time ON time.date = CAST(stg.pickup_datetime AS DATE)
LEFT JOIN dim_location pickup ON pickup.location_id = stg.pickup_location_id
LEFT JOIN dim_location dropoff ON dropoff.location_id = stg.dropoff_location_id
LEFT JOIN dim_payment pay ON pay.payment_type_code = stg.payment_type_code;

DESCRIBE fact_trips;