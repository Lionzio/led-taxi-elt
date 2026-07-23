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