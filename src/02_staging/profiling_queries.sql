-- =============================================================================
-- Camada: Staging (Processamento) - Profiling queries
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Análise dos dados brutos e investigação de possíveis problemas
--            de qualidade.
-- =============================================================================

-- =============================================================================
-- Bloco 1: Quantidade de registros e descrição das tabelas brutas 
--          (raw_yellow_taxi e raw_zone_lookup)
-- Descrição: Obter a informação da quantidade de registros das tabelas brutas 
--            e o nome e tipo de cada coluna.
-- =============================================================================

SELECT  
COUNT(*) AS total_registros_raw_yellow_taxi
FROM raw_yellow_taxi;

DESCRIBE raw_yellow_taxi;

SELECT  
COUNT(*) AS total_registros_raw_zone_lookup
FROM raw_zone_lookup;

DESCRIBE raw_zone_lookup;

-- =============================================================================
-- Bloco 2: Quantidade de valores nulos em cada coluna da tabela raw_yellow_taxi
-- Descrição: Tomar conhecimento de quais colunas da tabela raw_yellow_taxi
--            possuem valores nulos e a quantidade desses valores.
-- Observação: A consulta foi divida em 4 partes para possibilitar uma melhor 
--             visualização dos resultados, sem ocultar alguma coluna.
-- =============================================================================

SELECT
COUNT(CASE WHEN VendorID IS NULL THEN 1 END) AS qtd_null_vendor_id,
COUNT(CASE WHEN tpep_pickup_datetime IS NULL THEN 1 END) AS qtd_null_tpep_pickup_datetime,
COUNT(CASE WHEN tpep_dropoff_datetime IS NULL THEN 1 END) AS qtd_null_tpep_dropoff_datetime,
COUNT(CASE WHEN passenger_count IS NULL THEN 1 END) AS qtd_null_passenger_count,
COUNT(CASE WHEN trip_distance IS NULL THEN 1 END) AS qtd_null_trip_distance,
FROM raw_yellow_taxi;

SELECT
COUNT(CASE WHEN RatecodeID IS NULL THEN 1 END) AS qtd_null_ratecodeID,
COUNT(CASE WHEN store_and_fwd_flag IS NULL THEN 1 END) AS qtd_null_store_and_fwd_flag,
COUNT(CASE WHEN PULocationID IS NULL THEN 1 END) AS qtd_null_PULocationID,
COUNT(CASE WHEN DOLocationID IS NULL THEN 1 END) AS qtd_null_DOLocationID,
COUNT(CASE WHEN payment_type IS NULL THEN 1 END) AS qtd_null_payment_type,
FROM raw_yellow_taxi;

SELECT
COUNT(CASE WHEN fare_amount IS NULL THEN 1 END) AS qtd_null_fare_amount,
COUNT(CASE WHEN extra IS NULL THEN 1 END) AS qtd_null_extra,
COUNT(CASE WHEN mta_tax IS NULL THEN 1 END) AS qtd_null_mta_tax,
COUNT(CASE WHEN tip_amount IS NULL THEN 1 END) AS qtd_null_tip_amount,
COUNT(CASE WHEN tolls_amount IS NULL THEN 1 END) AS qtd_null_tolls_amount,
FROM raw_yellow_taxi;

SELECT
COUNT(CASE WHEN improvement_surcharge IS NULL THEN 1 END) AS qtd_null_improvement_surcharge,
COUNT(CASE WHEN total_amount IS NULL THEN 1 END) AS qtd_null_total_amount,
COUNT(CASE WHEN congestion_surcharge IS NULL THEN 1 END) AS qtd_null_congestion_surcharge,
COUNT(CASE WHEN Airport_fee IS NULL THEN 1 END) AS qtd_null_Airport_fee
FROM raw_yellow_taxi;