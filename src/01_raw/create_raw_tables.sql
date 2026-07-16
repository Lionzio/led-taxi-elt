-- =============================================================================
-- Camada: Raw (Ingestão)
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Criação das tabelas brutas que representam cópia fiel dos dados
--            de origem, sem qualquer transformação, limpeza ou normalização.
--            O script é idempotente e seguro para múltiplas execuções.
-- =============================================================================


-- =============================================================================
-- Bloco 1: Tabela raw_yellow_taxi
-- Origem: data/raw/yellow_tripdata_2024-01.parquet
-- Finalidade: Ingerir a totalidade dos registros de corridas de táxi amarelo
--             de janeiro de 2024 preservando integralmente o esquema inferido
--             pelo DuckDB a partir do arquivo Parquet de origem.
-- =============================================================================

DROP TABLE IF EXISTS raw_yellow_taxi;

CREATE TABLE raw_yellow_taxi AS
    SELECT *
    FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet');


-- =============================================================================
-- Bloco 2: Tabela raw_zone_lookup
-- Origem: data/raw/taxi_zone_lookup.csv
-- Finalidade: Ingerir a tabela de referência de zonas geográficas de táxi
--             de Nova Iorque preservando integralmente o esquema inferido
--             pelo DuckDB a partir do arquivo CSV de origem.
-- =============================================================================

DROP TABLE IF EXISTS raw_zone_lookup;

CREATE TABLE raw_zone_lookup AS
    SELECT *
    FROM read_csv_auto('data/raw/taxi_zone_lookup.csv');
