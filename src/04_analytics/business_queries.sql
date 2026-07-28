-- =============================================================================
-- Arquivo  : business_queries.sql
-- Finalidade: Centralizo aqui as consultas analíticas que alimentam os
--             dashboards de negócio do projeto LED Taxi ELT. Cada bloco é
--             independente e pode ser executado isoladamente no DuckDB.
--
-- Dashboard 1 — KPIs Globais de Operação e Finanças
-- Objetivo  : Ofereço uma visão consolidada do desempenho operacional e
--             financeiro da frota, calculando as principais métricas globais
--             que serão exibidas como cartões de indicadores no dashboard.
--
-- Métricas calculadas:
--   • Valor médio pago por viagem       — ticket médio financeiro da operação
--   • Distância média por viagem        — cobertura geográfica típica (milhas)
--   • Tempo médio por viagem            — duração típica em minutos
--   • Velocidade média da operação      — razão entre distância e tempo (mph)
--   • Porcentagem média de gorjeta      — gorjeta em relação à tarifa base (%)
--   • Valor médio cobrado por milha     — receita tarifária por unidade de
--                                         distância percorrida
-- =============================================================================

-- Dashboard 1 — KPIs Globais de Operação e Finanças
WITH trip_metrics AS (
    SELECT
        trip_distance,
        fare_amount,
        tip_amount,
        total_amount,
        DATE_DIFF('minute', pickup_datetime, dropoff_datetime) AS duration_minutes,
        DATE_DIFF('second', pickup_datetime, dropoff_datetime) / 3600.0 AS duration_hours
    FROM fact_trips
    WHERE
        trip_distance > 0
        AND DATE_DIFF('minute', pickup_datetime, dropoff_datetime) > 0
)

SELECT
    -- 1. Valor médio pago por viagem
    ROUND(AVG(total_amount), 2)                                              AS avg_total_amount,

    -- 2. Distância média da viagem (milhas)
    ROUND(AVG(trip_distance), 2)                                             AS avg_trip_distance_miles,

    -- 3. Tempo médio da viagem (minutos)
    ROUND(AVG(duration_minutes), 2)                                          AS avg_duration_minutes,

    -- 4. Velocidade média da operação (mph)
    ROUND(
        SUM(trip_distance) / NULLIF(SUM(duration_hours), 0),
        2
    )                                                                        AS avg_speed_mph,

    -- 5. Porcentagem média de gorjeta em relação à tarifa base
    ROUND(
        AVG(tip_amount / NULLIF(fare_amount, 0)) * 100,
        2
    )                                                                        AS avg_tip_pct,

    -- 6. Valor médio cobrado por milha
    ROUND(
        AVG(fare_amount / NULLIF(trip_distance, 0)),
        2
    )                                                                        AS avg_fare_per_mile

FROM trip_metrics;


-- =============================================================================
-- Dashboard 2 — Análise Espacial e Fluxos
-- Finalidade: Identifico os principais fluxos de viagens entre zonas de
--             origem e destino, permitindo análises de demanda, mobilidade
--             urbana e concentração operacional da frota.
--
-- Métricas apresentadas:
--   • Ranking do fluxo        — posição do par origem–destino por volume
--   • Zona de origem          — localização de embarque (pickup)
--   • Zona de destino         — localização de desembarque (dropoff)
--   • Volume de viagens       — total de corridas realizadas no fluxo
--
-- Observação: dim_location é utilizada como Role-Playing Dimension,
--             representando simultaneamente origem (alias pickup) e
--             destino (alias dropoff).
-- =============================================================================

-- Dashboard 2 — Análise Espacial e Fluxos
WITH spatial_flows AS (
    SELECT
        pickup.zone                                                 AS zona_origem,
        dropoff.zone                                                AS zona_destino,
        COUNT(ft.trip_key)                                          AS volume_viagens,
        DENSE_RANK() OVER (
            ORDER BY COUNT(ft.trip_key) DESC
        )                                                           AS ranking_fluxo
    FROM fact_trips AS ft
    INNER JOIN dim_location AS pickup
        ON ft.pickup_location_key  = pickup.location_key
    INNER JOIN dim_location AS dropoff
        ON ft.dropoff_location_key = dropoff.location_key
    WHERE
        pickup.zone <> 'Unknown'
        AND dropoff.zone <> 'Unknown'
    GROUP BY
        pickup.zone,
        dropoff.zone
)

SELECT
    ranking_fluxo,
    zona_origem,
    zona_destino,
    volume_viagens
FROM spatial_flows
WHERE ranking_fluxo <= 10
ORDER BY ranking_fluxo ASC;


-- =============================================================================
-- Dashboard 3 — Análise Temporal (Picos, Dias e Semanas)
-- Finalidade: Apoio à análise de sazonalidade operacional e comportamento
--             temporal da demanda, identificando os períodos de maior
--             concentração de viagens ao longo do dia, da semana e do mês.
--
-- Consultas:
--   • Query 3.1 — Top 5 horários de pico por volume de viagens
--   • Query 3.2 — Dia com maior volume de viagens
--   • Query 3.3 — Semana com maior volume de viagens (derivada em tempo de execução)
-- =============================================================================

-- Dashboard 3 — Query 3.1: Top 5 Horários de Pico
SELECT
    EXTRACT(HOUR FROM pickup_datetime)  AS hora_embarque,
    COUNT(trip_key)                     AS volume_viagens
FROM fact_trips
GROUP BY
    hora_embarque
ORDER BY
    volume_viagens DESC
LIMIT 5;


-- Dashboard 3 — Query 3.2: Dia com Maior Volume de Viagens
SELECT
    dt.date                             AS data_viagem,
    dt.day_of_week                      AS dia_semana,
    COUNT(ft.trip_key)                  AS volume_viagens
FROM fact_trips AS ft
INNER JOIN dim_time AS dt
    ON DATE_TRUNC('day', ft.pickup_datetime) = dt.date
GROUP BY
    dt.date,
    dt.day_of_week
ORDER BY
    volume_viagens DESC
LIMIT 1;


-- Dashboard 3 — Query 3.3: Semana com Maior Volume de Viagens
-- Observação: o início da semana é derivado dinamicamente em tempo de
-- execução via DATE_TRUNC e não representa um atributo previamente
-- armazenado na dimensão dim_time.
SELECT
    DATE_TRUNC('week', dt.date)         AS inicio_semana,
    COUNT(ft.trip_key)                  AS volume_viagens
FROM fact_trips AS ft
INNER JOIN dim_time AS dt
    ON DATE_TRUNC('day', ft.pickup_datetime) = dt.date
GROUP BY
    inicio_semana
ORDER BY
    volume_viagens DESC
LIMIT 1;


-- =============================================================================
-- Dashboard 4 — Valor Médio por Dia e Faixa de Horário
-- Finalidade: Analiso a distribuição do faturamento médio por corrida ao
--             longo dos dias da semana e das faixas de horário, apoiando
--             decisões sobre precificação dinâmica e alocação de frota.
--
-- Métricas apresentadas:
--   • Dia da semana       — atributo da dimensão dim_time
--   • Faixa de horário    — classificação por período do dia (manhã, tarde,
--                           noite e madrugada), derivada do horário de embarque
--   • Volume de viagens   — total de corridas no período
--   • Valor médio pago    — média de total_amount por viagem (arredondada)
-- =============================================================================

-- Dashboard 4 — Valor Médio por Dia e Faixa de Horário
WITH trip_time_bands AS (
    SELECT
        DATE_TRUNC('day', pickup_datetime)  AS data_viagem,
        total_amount,
        CASE
            WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN  6 AND 11 THEN '1. Manhã (06h-11h)'
            WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 12 AND 17 THEN '2. Tarde (12h-17h)'
            WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 18 AND 23 THEN '3. Noite (18h-23h)'
            ELSE                                                            '4. Madrugada (00h-05h)'
        END                                 AS faixa_horaria
    FROM fact_trips
)

SELECT
    dt.day_of_week                          AS dia_semana,
    tb.faixa_horaria,
    COUNT(*)                                AS volume_viagens,
    ROUND(AVG(tb.total_amount), 2)          AS valor_medio_pago
FROM trip_time_bands AS tb
INNER JOIN dim_time AS dt
    ON tb.data_viagem = dt.date
GROUP BY
    dt.day_of_week,
    tb.faixa_horaria
ORDER BY
    dt.day_of_week,
    tb.faixa_horaria;
