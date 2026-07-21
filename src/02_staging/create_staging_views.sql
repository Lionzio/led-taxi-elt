-- =============================================================================
-- Camada: Staging (Processando) - Criação de views
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Tratamento de tipagem segura e isolamento de registros corrompidos.
-- =============================================================================

-- =============================================================================
-- Bloco 1: Auditoria Ativa (Criação da tabela rejected_records)
-- Descrição: Isolar e registrar anomalias baseadas nas descobertas do profiling,
--            garantindo que dados corrompidos ou fora de escopo não avancem 
--            para as camadas analíticas.
-- Observação: Foram aplicadas 9 regras de rejeição focadas em regras de negócio, 
--             limites físicos (distância/tempo) e integridade financeira.
--             Foi utilizada uma estrutura de CASE WHEN para aplicar as regras 
--             de forma mais clara em uma única leitura da tabela, evitando 
--             também a duplicação de registros rejeitados por múltiplos motivos.
--             A pseudocoluna `rowid` do DuckDB é capturada como `raw_rowid` para
--             garantir uma chave de exclusão inequívoca na view stg_yellow_taxi,
--             eliminando o risco de falsos positivos causados por colisão de
--             chave parcial (VendorID + datetimes + total_amount).
--
-- ALERTA TÉCNICO — rowid no DuckDB:
--   O `rowid` é estável para tabelas estáticas dentro de uma mesma sessão e
--   entre sessões subsequentes, desde que a tabela não seja mutada (DELETE,
--   UPDATE) nem reconstruída (DROP + CREATE). Se raw_yellow_taxi for
--   recriada em uma execução futura sem que rejected_records seja igualmente
--   recriada a partir do novo estado da tabela, os valores de raw_rowid
--   armazenados em rejected_records se tornam inválidos e a lógica de
--   exclusão da view stg_yellow_taxi passa a filtrar linhas erradas.
--   Para este pipeline (carga única, dataset estático), o risco é nulo.
--   Em pipelines incrementais, substituir rowid por uma chave de negócio
--   composta e estável ou por um hash MD5 calculado sobre o conjunto completo
--   de colunas da linha.
-- =============================================================================

DROP TABLE IF EXISTS rejected_records;

CREATE TABLE rejected_records AS
WITH regras_aplicadas AS (
    SELECT 
        rowid AS raw_rowid,
        VendorID, 
        tpep_pickup_datetime, 
        tpep_dropoff_datetime,
        total_amount,
        CASE 
            -- Regra 1: Desembarque antes do embarque
            WHEN TRY_CAST(tpep_dropoff_datetime AS TIMESTAMP) < TRY_CAST(tpep_pickup_datetime AS TIMESTAMP) 
                THEN 'Datas invertidas (Dropoff < Pickup)'
            
            -- Regra 2: Valores totais negativos (Intercepta também os estornos duplicados achados em registros parcialmente duplicados) 
            WHEN TRY_CAST(total_amount AS DOUBLE) < 0 
                THEN 'Valor total cobrado negativo'
            
            -- Regra 3: Viagens fora do escopo (Janeiro de 2024)
            WHEN TRY_CAST(tpep_pickup_datetime AS TIMESTAMP) < '2024-01-01 00:00:00' OR TRY_CAST(tpep_pickup_datetime AS TIMESTAMP) >= '2024-02-01 00:00:00' 
                THEN 'Fora do escopo temporal (Jan 2024)'
            
            -- Regra 4: Distância muito longa descorberta no profiling (> 300 milhas)
            WHEN TRY_CAST(trip_distance AS DOUBLE) > 300 
                THEN 'Distância muito longa (> 300 milhas)'
            
            -- Regra 5: Tarifa muito grande descorberta no Profiling (> $ 1000)
            WHEN TRY_CAST(total_amount AS DOUBLE) > 1000 
                THEN 'Tarifa muito grande (> $ 1000)'
            
            -- Regra 6: Distância percorrida igual a zero 
            WHEN TRY_CAST(trip_distance AS DOUBLE) = 0 
                THEN 'Distância zerada'
            
            -- Regra 7: Valor total pago igual a zero
            WHEN TRY_CAST(total_amount AS DOUBLE) = 0 
                THEN 'Valor total pago zerado'
            
            -- Regra 8: Inconsistência - Distância curta com valor alto
            WHEN TRY_CAST(trip_distance AS DOUBLE) > 0 AND TRY_CAST(trip_distance AS DOUBLE) < 2 AND TRY_CAST(total_amount AS DOUBLE) > 150 
                THEN 'Inconsistência: Distância curta com valor muito alto'
            
            -- Regra 9: Inconsistência - Distância longa com valor baixo
            WHEN TRY_CAST(trip_distance AS DOUBLE) > 50 AND TRY_CAST(total_amount AS DOUBLE) < 10 
                THEN 'Inconsistência: Distância longa com valor muito baixo'
            
            ELSE 'VALIDO'
        END AS rejection_reason
    FROM raw_yellow_taxi
)
SELECT 
    raw_rowid,
    VendorID, 
    tpep_pickup_datetime, 
    tpep_dropoff_datetime,
    total_amount,
    rejection_reason
FROM regras_aplicadas
WHERE rejection_reason != 'VALIDO';

-- =============================================================================
-- Bloco 2: Visão Staging da Tabela Fato (stg_yellow_taxi)
-- Descrição: Aplicar tipagem segura (TRY_CAST) em 100% das colunas brutas, 
--            tratar valores nulos identificados no profiling e filtrar os 
--            registros que falharam nas regras de auditoria.
-- Observação: Colunas financeiras nulas foram convertidas para 0.0 para 
--             preservar a integridade das funções de agregação (SUM) na Sprint 7.
--             Adicionalmente, flags nulas de armazenamento (store_and_fwd_flag) 
--             foram padronizadas para 'Unknown' e códigos inválidos mapeados.
--             A exclusão de registros rejeitados usa rowid NOT IN para garantia
--             de unicidade na filtragem — ver alerta técnico no Bloco 1.
-- =============================================================================
CREATE OR REPLACE VIEW stg_yellow_taxi AS
SELECT
    -- Identificadores Básicos
    TRY_CAST(VendorID AS INTEGER) AS vendor_id,
    TRY_CAST(tpep_pickup_datetime AS TIMESTAMP) AS pickup_datetime,
    TRY_CAST(tpep_dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
    
    -- Tratamento do nulo de passageiros (140.162 casos)
    CASE 
        WHEN TRY_CAST(passenger_count AS INTEGER) IS NULL OR TRY_CAST(passenger_count AS INTEGER) = 0 THEN 1 
        ELSE TRY_CAST(passenger_count AS INTEGER) 
    END AS passenger_count,
    
    TRY_CAST(trip_distance AS DOUBLE) AS trip_distance,
    
    -- Tratamento do RatecodeID nulo ou inválido para 99 (Null/unknown)
    CASE 
        WHEN TRY_CAST(RatecodeID AS INTEGER) IS NULL OR TRY_CAST(RatecodeID AS INTEGER) NOT IN (1, 2, 3, 4, 5, 6, 99) THEN 99
        ELSE TRY_CAST(RatecodeID AS INTEGER)
    END AS ratecode_id,

    -- Tratamento da flag nula (140.162 casos)
    COALESCE(TRY_CAST(store_and_fwd_flag AS VARCHAR), 'Unknown') AS store_and_fwd_flag,

    -- Localizações
    TRY_CAST(PULocationID AS INTEGER) AS pickup_location_id,
    TRY_CAST(DOLocationID AS INTEGER) AS dropoff_location_id,
    
    -- Tratamento de tipos de pagamento inválidos para 5 (Unknown)
    CASE 
        WHEN TRY_CAST(payment_type AS INTEGER) NOT IN (0, 1, 2, 3, 4, 5, 6) THEN 5
        ELSE TRY_CAST(payment_type AS INTEGER)
    END AS payment_type_code,
    
    -- Colunas Financeiras e Taxas Complementares
    TRY_CAST(fare_amount AS DOUBLE) AS fare_amount,
    TRY_CAST(extra AS DOUBLE) AS extra_amount,
    TRY_CAST(mta_tax AS DOUBLE) AS mta_tax_amount,
    TRY_CAST(tip_amount AS DOUBLE) AS tip_amount,
    TRY_CAST(tolls_amount AS DOUBLE) AS tolls_amount,
    TRY_CAST(improvement_surcharge AS DOUBLE) AS improvement_surcharge_amount,
    
    -- Tratamento dos nulos monetários (140.162 casos) para garantir a consistência de soma
    COALESCE(TRY_CAST(congestion_surcharge AS DOUBLE), 0.0) AS congestion_surcharge_amount,
    COALESCE(TRY_CAST(Airport_fee AS DOUBLE), 0.0) AS airport_fee_amount,
    
    TRY_CAST(total_amount AS DOUBLE) AS total_amount

FROM raw_yellow_taxi
WHERE rowid NOT IN (SELECT raw_rowid FROM rejected_records);

-- =============================================================================
-- Bloco 3: Visão Staging da Tabela de Lookup (stg_zone_lookup)
-- Descrição: Aplicar tipagem segura e padronização de nomenclatura na tabela 
--            auxiliar de zonas geográficas.
-- =============================================================================

CREATE OR REPLACE VIEW stg_zone_lookup AS
SELECT 
    TRY_CAST(LocationID AS INTEGER) AS location_id,
    Borough AS borough,
    Zone AS zone,
    service_zone AS service_zone
FROM raw_zone_lookup;

-- =============================================================================
-- Bloco 4: Evidências e Reconciliação (Sanity Check)
-- Descrição: Valida se a quantidade de registros processados (Staging + Rejeitados)
--            é exatamente igual à quantidade de registros na origem (Raw).
-- =============================================================================

SELECT 
    (SELECT COUNT(*) FROM raw_yellow_taxi) AS total_camada_bruta,
    (SELECT COUNT(*) FROM stg_yellow_taxi) AS total_camada_staging,
    (SELECT COUNT(*) FROM rejected_records) AS total_registros_rejeitados,
    ((SELECT COUNT(*) FROM stg_yellow_taxi) + (SELECT COUNT(*) FROM rejected_records)) AS soma_staging_e_rejeitados,
    CASE 
        WHEN (SELECT COUNT(*) FROM raw_yellow_taxi) = ((SELECT COUNT(*) FROM stg_yellow_taxi) + (SELECT COUNT(*) FROM rejected_records)) 
        THEN 'SUCESSO: Nenhuma linha perdida' 
        ELSE 'FALHA: Inconsistência na reconciliação de linhas' 
    END AS status_auditoria;