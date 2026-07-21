-- =============================================================================
-- Camada: Data Quality — Testes de Reconciliação e Integridade
-- Projeto: LED UFPE — Pipeline ELT Yellow Taxi NYC
-- Descrição: Scripts de validação que provam matematicamente a integridade
--            da camada Staging em relação à camada Raw.
-- =============================================================================

-- =============================================================================
-- Teste 1: Reconciliação de contagem de linhas entre Raw, Staging e Rejected
-- Invariante: COUNT(stg_yellow_taxi) + COUNT(rejected_records) = COUNT(raw_yellow_taxi)
-- Descrição: Garante que nenhuma linha foi perdida ou duplicada no processo
--            de filtragem entre a camada Raw e a camada Staging. Retorna uma
--            única linha com os contadores de cada camada, a soma de controle,
--            a diferença absoluta e o status textual da reconciliação.
-- =============================================================================

SELECT
    (SELECT COUNT(*) FROM raw_yellow_taxi)  AS total_raw,
    (SELECT COUNT(*) FROM stg_yellow_taxi)  AS total_staging,
    (SELECT COUNT(*) FROM rejected_records) AS total_rejeitados,
    (
        (SELECT COUNT(*) FROM stg_yellow_taxi) +
        (SELECT COUNT(*) FROM rejected_records)
    )                                        AS soma_staging_mais_rejeitados,
    (SELECT COUNT(*) FROM raw_yellow_taxi) -
    (
        (SELECT COUNT(*) FROM stg_yellow_taxi) +
        (SELECT COUNT(*) FROM rejected_records)
    )                                        AS diferenca,
    CASE
        WHEN (SELECT COUNT(*) FROM raw_yellow_taxi) =
             (
                 (SELECT COUNT(*) FROM stg_yellow_taxi) +
                 (SELECT COUNT(*) FROM rejected_records)
             )
        THEN 'SUCESSO: stg + rejected = raw — nenhuma linha perdida ou duplicada'
        ELSE 'FALHA: divergência de ' ||
             CAST(
                 ABS(
                     (SELECT COUNT(*) FROM raw_yellow_taxi) -
                     (
                         (SELECT COUNT(*) FROM stg_yellow_taxi) +
                         (SELECT COUNT(*) FROM rejected_records)
                     )
                 ) AS VARCHAR
             ) || ' linha(s) — investigar filtro de exclusão em stg_yellow_taxi'
    END AS status_reconciliacao;

-- =============================================================================
-- Teste 2: Integridade temporal em stg_yellow_taxi
-- Invariante: NENHUMA linha em stg_yellow_taxi pode ter dropoff_datetime < pickup_datetime
-- Descrição: Valida que a Regra 1 de rejected_records (datas invertidas) foi
--            aplicada corretamente e que nenhum registro com inversão temporal
--            escapou para a camada Staging. Se a Regra 1 funcionou corretamente,
--            o resultado deve ser 0 violações e status SUCESSO.
-- =============================================================================

SELECT
    COUNT(*) AS total_violacoes_data_invertida,
    CASE
        WHEN COUNT(*) = 0
        THEN 'SUCESSO: nenhuma linha em stg_yellow_taxi possui dropoff_datetime < pickup_datetime'
        ELSE 'FALHA: ' || CAST(COUNT(*) AS VARCHAR) ||
             ' linha(s) com dropoff_datetime < pickup_datetime encontrada(s) em stg_yellow_taxi'
    END AS status_integridade_temporal
FROM stg_yellow_taxi
WHERE dropoff_datetime < pickup_datetime;
