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

-- =============================================================================
-- Bloco 3: Cardinalidade  das colunas da tabela raw_yellow_taxi
-- Descrição: Obter a cardinalidade(quantidade de valores únicos) das colunas da 
--            tabela raw_yellow_taxi, para conseguir identificar colunas de alta e
--            baixa cardinalidade.
-- =============================================================================

SELECT
COUNT(DISTINCT VendorID) AS card_vendor_id,
COUNT(DISTINCT tpep_pickup_datetime) AS card_tpep_pickup_datetime,
COUNT(DISTINCT tpep_dropoff_datetime) AS card_tpep_dropoff_datetime,
COUNT(DISTINCT passenger_count) AS card_passenger_count,
COUNT(DISTINCT trip_distance) AS card_trip_distance,
FROM raw_yellow_taxi;

SELECT
COUNT(DISTINCT RatecodeID) AS card_ratecodeID,
COUNT(DISTINCT store_and_fwd_flag) AS card_store_and_fwd_flag,
COUNT(DISTINCT PULocationID) AS card_PULocationID,
COUNT(DISTINCT DOLocationID) AS card_DOLocationID,
COUNT(DISTINCT payment_type) AS card_payment_type,
FROM raw_yellow_taxi;

SELECT
COUNT(DISTINCT fare_amount) AS card_fare_amount,
COUNT(DISTINCT extra) AS card_extra,
COUNT(DISTINCT mta_tax) AS card_mta_tax,
COUNT(DISTINCT tip_amount) AS card_tip_amount,
COUNT(DISTINCT tolls_amount) AS card_tolls_amount,
FROM raw_yellow_taxi;

SELECT
COUNT(DISTINCT improvement_surcharge) AS card_improvement_surcharge,
COUNT(DISTINCT total_amount) AS card_total_amount,
COUNT(DISTINCT congestion_surcharge) AS card_congestion_surcharge,
COUNT(DISTINCT Airport_fee) AS card_Airport_fee
FROM raw_yellow_taxi;

-- =============================================================================
-- Bloco 4: Análise da distribuição das colunas numéricas da tabela raw_yellow_taxi
-- Descrição: Obter os valores mínimos, médios e máximos das colunas numéricas da 
--            tabela raw_yellow_taxi, para identificar possíveis inconsistências 
--            e outliers.
-- Observação: A análise foi feita focando nos atributos monetários, de tempo e
--             de distância, não sendo analisadas colunas de ID, pois julgamos 
--             que a distribuição dos IDs não seria relevante para nossas análises
--             de negócio. 
-- =============================================================================

SELECT
MIN(trip_distance) AS min_trip_distance,
AVG(trip_distance) AS avg_trip_distance,
MAX(trip_distance) AS max_trip_distance,
FROM raw_yellow_taxi;

SELECT
MIN(fare_amount) AS min_fare_amount,
AVG(fare_amount) AS avg_fare_amount,
MAX(fare_amount) AS max_fare_amount,
FROM raw_yellow_taxi;

SELECT
MIN(extra) AS min_extra,
AVG(extra) AS avg_extra,
MAX(extra) AS max_extra,
FROM raw_yellow_taxi;

SELECT
MIN(mta_tax) AS min_mta_tax,
AVG(mta_tax) AS avg_mta_tax,
MAX(mta_tax) AS max_mta_tax,
FROM raw_yellow_taxi;

SELECT
MIN(tip_amount) AS min_tip_amount,
AVG(tip_amount) AS avg_tip_amount,
MAX(tip_amount) AS max_tip_amount,
FROM raw_yellow_taxi;

SELECT
MIN(tolls_amount) AS min_tolls_amount,
AVG(tolls_amount) AS avg_tolls_amount,
MAX(tolls_amount) AS max_tolls_amount,
FROM raw_yellow_taxi;

SELECT
MIN(improvement_surcharge) AS min_improvement_surcharge,
AVG(improvement_surcharge) AS avg_improvement_surcharge,
MAX(improvement_surcharge) AS max_improvement_surcharge,
FROM raw_yellow_taxi;

SELECT
MIN(total_amount) AS min_total_amount,
AVG(total_amount) AS avg_total_amount,
MAX(total_amount) AS max_total_amount,
FROM raw_yellow_taxi;

SELECT
MIN(congestion_surcharge) AS min_congestion_surcharge,
AVG(congestion_surcharge) AS avg_congestion_surcharge,
MAX(congestion_surcharge) AS max_congestion_surcharge,
FROM raw_yellow_taxi;

SELECT
MIN(Airport_fee) AS min_Airport_fee,
AVG(Airport_fee) AS avg_Airport_fee,
MAX(Airport_fee) AS max_Airport_fee
FROM raw_yellow_taxi;