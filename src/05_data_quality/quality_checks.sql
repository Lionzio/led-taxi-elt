-- =============================================================================
-- Camada: Data Quality
-- Projeto: LED UFPE - Pipeline ELT Yellow Taxi NYC
-- Descrição: Bateria de testes automatizados baseada no ADR-0002 para atestar 
--            unicidade, completude, consistência, integridade referencial e 
--            reconciliação (volumétrica e financeira).
-- =============================================================================

-- =============================================================================
-- Teste 1: Completude
-- Objetivo: Garantir que as chaves estrangeiras (FKs) e as medidas críticas não sejam nulas.
-- Resultado Esperado: 0
-- =============================================================================
SELECT 
    COUNT(*) AS falhas_completude
FROM 
    fact_trips
WHERE 
    pickup_location_key IS NULL 
    OR dropoff_location_key IS NULL
    OR time_key IS NULL
    OR payment_key IS NULL
    OR total_amount IS NULL;

-- =============================================================================
-- Teste 2: Unicidade
-- Objetivo: Validar que a Surrogate Key (trip_key) gerada por MD5 seja única na Fato.
-- Resultado Esperado: 0 linhas.
-- =============================================================================
SELECT 
    trip_key, 
    COUNT(*) AS repeticoes
FROM 
    fact_trips
GROUP BY 
    trip_key 
HAVING 
    COUNT(*) > 1;

-- =============================================================================
-- Teste 3: Consistência Lógica (Avançado)
-- Objetivo: Garantir regras de domínio rigorosas do contexto TLC NYC Taxi.
-- Resultado Esperado: 0
-- =============================================================================
SELECT 
    COUNT(*) AS falhas_consistencia
FROM 
    fact_trips
WHERE 
    -- Regra 1: Erro de sistema ou taxímetro (desembarque anterior ao embarque)
    dropoff_datetime < pickup_datetime 
    
    -- Regra 2: Filtra estornos e cancelamentos (valores financeiros negativos)
    OR total_amount < 0 
    
    -- Regra 3: Remove vazamento de dados fora do mês de janeiro de 2024
    OR pickup_datetime < '2024-01-01 00:00:00' 
    OR pickup_datetime >= '2024-02-01 00:00:00' 
    
    -- Regra 4: Falha de GPS indicando viagem fisicamente inviável (> 300 milhas)
    OR trip_distance > 300 
    
    -- Regra 5: Erro de digitação gerando tarifa exorbitante (> $ 1000)
    OR total_amount > 1000 
    
    -- Regra 6: Corridas canceladas no embarque ou falha de captura (0 milhas)
    OR trip_distance = 0 
    
    -- Regra 7: Viagens de teste ou isenções sem movimentação financeira ($ 0)
    OR total_amount = 0 
    
    -- Regra 8: Possível fraude ou falha (distância < 2 milhas e tarifa > $ 150)
    OR (trip_distance > 0 AND trip_distance < 2 AND total_amount > 150) 
    
    -- Regra 9: Taxímetro desligado ou erro (distância > 50 milhas e tarifa < $ 10)
    OR (trip_distance > 50 AND total_amount < 10)

    -- Regra 10: Erro de GPS indicando velocidade média impraticável (> 70 mph)
    OR (
        trip_distance > 0 
        AND DATE_DIFF('second', pickup_datetime, dropoff_datetime) > 0
        AND (trip_distance / (DATE_DIFF('second', pickup_datetime, dropoff_datetime) / 3600.0)) > 70
    )
    
    -- Regra 11: Gorjeta anômala ou erro de terminal (> $50 ou > 50% da tarifa)
    OR tip_amount > 50 
    OR (tip_amount > (fare_amount * 0.5) AND fare_amount > 20)
    
    -- Regra 12: Excesso de passageiros além da lotação máxima permitida (> 6)
    OR passenger_count > 6;

-- =============================================================================
-- Teste 4: Integridade Referencial 
-- Objetivo: Validar se todas as FKs da fato existem nas dimensões correspondentes.
-- Resultado Esperado: 0
-- =============================================================================
SELECT 
    COUNT(*) AS falhas_integridade
FROM 
    fact_trips
WHERE 
    pickup_location_key NOT IN (SELECT location_key FROM dim_location)
    OR dropoff_location_key NOT IN (SELECT location_key FROM dim_location)
    OR time_key NOT IN (SELECT time_key FROM dim_time)
    OR payment_key NOT IN (SELECT payment_key FROM dim_payment);

-- =============================================================================
-- Teste 5: Reconciliação Volumétrica 
-- Objetivo: Provar que Raw = Fato + Rejeições (Garante que nenhum registro foi 
--           perdido durante a modelagem ou JOINs).
-- Resultado Esperado: delta_linhas = 0
-- =============================================================================
SELECT 
    (SELECT COUNT(*) FROM raw_yellow_taxi) AS total_raw,
    (SELECT COUNT(*) FROM fact_trips) AS total_fato,
    (SELECT COUNT(*) FROM rejected_records) AS total_rejeitados,
    (SELECT COUNT(*) FROM raw_yellow_taxi) - 
    ((SELECT COUNT(*) FROM fact_trips) + (SELECT COUNT(*) FROM rejected_records)) AS delta_linhas;

-- =============================================================================
-- Teste 6: Reconciliação Financeira Exata 
-- Objetivo: Verificar consistência matemática monetária, somando os dados finais 
--           carregados e o que foi desviado para a auditoria.
-- Resultado Esperado: diferenca_financeira = 0.00
-- =============================================================================
SELECT 
    (SELECT SUM(TRY_CAST(total_amount AS DECIMAL(18,2))) FROM raw_yellow_taxi) AS total_bruto,
    
    (
        (SELECT SUM(total_amount) FROM fact_trips) + 
        (SELECT SUM(TRY_CAST(total_amount AS DECIMAL(18,2))) FROM rejected_records)
    ) AS total_reconciliado,
    
    (SELECT SUM(TRY_CAST(total_amount AS DECIMAL(18,2))) FROM raw_yellow_taxi) - 
    (
        (SELECT SUM(total_amount) FROM fact_trips) + 
        (SELECT SUM(TRY_CAST(total_amount AS DECIMAL(18,2))) FROM rejected_records)
    ) AS diferenca_financeira;