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

-- =============================================================================
-- Bloco 5: Verificação de inconsistências nas colunas PULocationID e DOLocationID
--          da tabela raw_yellow_taxi.
-- Descrição: Checagem se existem valores em PULocationID e em DOLocationID que não
--            estão presentes na tabela auxiliar raw_zone_lookup, caso existissem,
--            isso indicaria uma possível inconsistência, dado que não teriamos as 
--            informações de adicionais para essas localidades.
-- =============================================================================

SELECT
COUNT(CASE WHEN PULocationID NOT IN (SELECT LocationID FROM raw_zone_lookup) 
THEN 1 END) AS qtd_PULocation_invalid,
COUNT(CASE WHEN DOLocationID NOT IN (SELECT LocationID FROM raw_zone_lookup) 
THEN 1 END) AS qtd_DOLocation_invalid
FROM raw_yellow_taxi;

-- =============================================================================
-- Bloco 6: Investigação de duplicidades parciais
-- Descrição: Identificar registros com a mesma chave lógica de viagem, mas 
--            com tarifas diferentes, o que indica transações de estorno/cancelamento.
-- =============================================================================

SELECT COALESCE(SUM(qtd), 0) AS total_linhas_mesma_viagem_tarifa_diferente
FROM (
    SELECT COUNT(*) AS qtd
    FROM raw_yellow_taxi
    GROUP BY 
        VendorID, tpep_pickup_datetime, tpep_dropoff_datetime,
        PULocationID, DOLocationID, trip_distance, passenger_count
    HAVING COUNT(*) > 1 
       AND COUNT(DISTINCT total_amount) > 1
) AS sub;

SELECT 
    VendorID, tpep_pickup_datetime, tpep_dropoff_datetime,
    PULocationID, DOLocationID, trip_distance, passenger_count,
    COUNT(*) AS quantidade_registros,
    LIST(DISTINCT total_amount) AS tarifas_diferentes
FROM raw_yellow_taxi
GROUP BY 
    VendorID, tpep_pickup_datetime, tpep_dropoff_datetime,
    PULocationID, DOLocationID, trip_distance, passenger_count
HAVING COUNT(*) > 1 
   AND COUNT(DISTINCT total_amount) > 1
ORDER BY quantidade_registros DESC
LIMIT 10;

-- =============================================================================
-- Bloco 7: Verificação de aderência ao Dicionário de Dados
-- Descrição: Validar a distribuição dos dados categóricos principais.
-- =============================================================================

-- Distribuição de VendorID
SELECT 
    CASE WHEN VendorID IS NULL THEN 'NULL' ELSE CAST(VendorID AS VARCHAR) END AS VendorID_str,
    COUNT(*) AS quantidade
FROM raw_yellow_taxi
GROUP BY VendorID
ORDER BY VendorID NULLS FIRST;



-- Distribuição de RatecodeID
SELECT 
    CASE WHEN RatecodeID IS NULL THEN 'NULL' ELSE CAST(RatecodeID AS VARCHAR) END AS RatecodeID_str,
    COUNT(*) AS quantidade
FROM raw_yellow_taxi
GROUP BY RatecodeID
ORDER BY RatecodeID NULLS FIRST;


-- Distribuição de payment_type
SELECT 
    CASE WHEN payment_type IS NULL THEN 'NULL' ELSE CAST(payment_type AS VARCHAR) END AS payment_type_str,
    COUNT(*) AS quantidade
FROM raw_yellow_taxi
GROUP BY payment_type
ORDER BY payment_type NULLS FIRST;

-- =============================================================================
-- Bloco 8: Análise de escopo temporal
-- Descrição: Identificar viagens cujas datas de embarque estão fora do 
--            período alvo da análise (Janeiro de 2024).
-- =============================================================================

SELECT COUNT(*) AS total_fora_jan2024
FROM raw_yellow_taxi 
WHERE tpep_pickup_datetime < '2024-01-01' 
   OR tpep_pickup_datetime >= '2024-02-01';

SELECT 
    MIN(tpep_pickup_datetime) AS menor_data_fora_jan2024,
    MAX(tpep_pickup_datetime) AS maior_data_fora_jan2024
FROM raw_yellow_taxi 
WHERE tpep_pickup_datetime < '2024-01-01' 
   OR tpep_pickup_datetime >= '2024-02-01';

SELECT VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, trip_distance, total_amount
FROM raw_yellow_taxi 
WHERE tpep_pickup_datetime < '2024-01-01' 
   OR tpep_pickup_datetime >= '2024-02-01'
LIMIT 5;

-- =============================================================================
-- Bloco 9: Análise aprofundada de anomalias (Outliers)
-- Descrição: Detalhamento estatístico e agrupamento em faixas (buckets) de 
--            Distância e Tarifa para apoiar a definição de regras de rejeição.
-- =============================================================================

-- Estatísticas adicionais de Distância (Milhas)
SELECT 
    MIN(trip_distance) AS minimo,
    MAX(trip_distance) AS maximo,
    AVG(trip_distance) AS media,
    MEDIAN(trip_distance) AS mediana,
    COUNT(*) FILTER (WHERE trip_distance > 1000) AS qtd_acima_1000_milhas
FROM raw_yellow_taxi;

SELECT VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, trip_distance, total_amount
FROM raw_yellow_taxi 
ORDER BY trip_distance DESC 
LIMIT 10;

-- Faixas (Buckets) de Distância
SELECT 
    COUNT(*) FILTER (WHERE trip_distance > 50 AND trip_distance <= 100) AS dist_50_a_100,
    COUNT(*) FILTER (WHERE trip_distance > 100 AND trip_distance <= 300) AS dist_100_a_300,
    COUNT(*) FILTER (WHERE trip_distance > 300 AND trip_distance <= 1000) AS dist_300_a_1000,
    COUNT(*) FILTER (WHERE trip_distance > 1000) AS dist_acima_1000
FROM raw_yellow_taxi;

-- Estatísticas adicionais de Valores (Dólares)
SELECT 
    MIN(total_amount) AS minimo,
    MAX(total_amount) AS maximo,
    AVG(total_amount) AS media,
    MEDIAN(total_amount) AS mediana,
    COUNT(*) FILTER (WHERE total_amount > 500) AS qtd_acima_500_dolares
FROM raw_yellow_taxi;

SELECT VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, trip_distance, total_amount
FROM raw_yellow_taxi 
ORDER BY total_amount DESC 
LIMIT 10;

-- Faixas (Buckets) de Valores Pagos
SELECT 
    COUNT(*) FILTER (WHERE total_amount > 200 AND total_amount <= 400) AS valor_200_a_400,
    COUNT(*) FILTER (WHERE total_amount > 400 AND total_amount <= 1000) AS valor_400_a_1000,
    COUNT(*) FILTER (WHERE total_amount > 1000) AS valor_acima_1000
FROM raw_yellow_taxi;