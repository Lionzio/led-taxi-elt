# ADR 0002 — Desenho do Star Schema para o Pipeline LED Yellow Taxi NYC

## Status

Aceito

---

## Contexto

O pipeline ELT do projeto LED/UFPE processa dados de corridas de táxi amarelo
de Nova Iorque (janeiro de 2024, ~2,96 milhões de viagens) sobre DuckDB. A
camada Staging (`stg_yellow_taxi`, `stg_zone_lookup`) entrega dados limpos e
tipados com segurança via `TRY_CAST`. A próxima camada (Dimensional) deve
suportar consultas analíticas por tempo, localização geográfica e modalidade
de pagamento, com desempenho aceitável em ambiente DuckDB embarcado (arquivo
único, sem cluster distribuído).

A equipe avaliou dois esquemas de modelagem multidimensional:

- **Star Schema** (Kimball): tabela fato central ligada diretamente a dimensões
  desnormalizadas.
- **Snowflake Schema**: dimensões normalizadas em hierarquias de subtabelas.

---

## Decisão

Adoto **Star Schema** como modelo físico da camada dimensional.

### Justificativa contra Snowflake Schema

O Snowflake Schema normaliza as dimensões em tabelas filhas (ex.:
`dim_borough → dim_zone → dim_location`), reduzindo redundância de
armazenamento. Essa vantagem é irrelevante neste contexto pelos seguintes
motivos técnicos objetivos:

1. **Volume de dimensões:** `dim_location` terá no máximo 265 linhas
   (cardinalidade total de `raw_zone_lookup`). Normalizar 265 linhas em
   subtabelas não produz economia mensurável de espaço em DuckDB.
2. **Custo de JOINs em cadeia:** DuckDB é um motor OLAP colunar com execução
   vetorizada; múltiplos JOINs em cadeia (hierarquia Snowflake) penalizam o
   planejador de consultas mais do que a redundância de strings em dimensões
   de baixa cardinalidade.
3. **Legibilidade e manutenibilidade:** O Star Schema permite que consultas
   analíticas finais (Sprint 7) sejam escritas com um único JOIN por dimensão,
   reduzindo a complexidade cognitiva para o squad em formação.
4. **Alinhamento metodológico:** A metodologia Kimball recomenda explicitamente
   Star Schema como ponto de partida para data marts de pequeno e médio porte,
   priorizando desempenho de leitura sobre economia de escrita.

---

## Granularidade da Tabela Fato

**Uma linha em `fct_trips` representa exatamente uma corrida de táxi amarelo
registrada pelo sistema TPEP, tal como entregue pela camada Staging
(`stg_yellow_taxi`), sem agregação ou deduplicação.**

---

## Mapeamento das Tabelas

### Fato: `fct_trips`

| Coluna | Tipo DuckDB | Origem (`stg_yellow_taxi`) | Descrição |
|---|---|---|---|
| `trip_sk` | VARCHAR | gerada via MD5 | Surrogate Key da viagem |
| `date_sk` | VARCHAR | derivada de `pickup_datetime` | FK → `dim_date` |
| `pickup_location_sk` | VARCHAR | derivada de `pickup_location_id` | FK → `dim_location` (papel: embarque) |
| `dropoff_location_sk` | VARCHAR | derivada de `dropoff_location_id` | FK → `dim_location` (papel: desembarque) |
| `payment_sk` | VARCHAR | derivada de `payment_type_code` | FK → `dim_payment` |
| `vendor_id` | INTEGER | `vendor_id` | Identificador do fornecedor TPEP |
| `ratecode_id` | INTEGER | `ratecode_id` | Código da tarifa |
| `store_and_fwd_flag` | VARCHAR | `store_and_fwd_flag` | Flag de buffer de transmissão |
| `passenger_count` | INTEGER | `passenger_count` | Quantidade de passageiros |
| `trip_distance` | DOUBLE | `trip_distance` | Distância percorrida (milhas) |
| `fare_amount` | DOUBLE | `fare_amount` | Tarifa base |
| `extra_amount` | DOUBLE | `extra_amount` | Acréscimos extras |
| `mta_tax_amount` | DOUBLE | `mta_tax_amount` | Imposto MTA |
| `tip_amount` | DOUBLE | `tip_amount` | Gorjeta |
| `tolls_amount` | DOUBLE | `tolls_amount` | Pedágios |
| `improvement_surcharge_amount` | DOUBLE | `improvement_surcharge_amount` | Taxa de melhoria |
| `congestion_surcharge_amount` | DOUBLE | `congestion_surcharge_amount` | Taxa de congestionamento |
| `airport_fee_amount` | DOUBLE | `airport_fee_amount` | Taxa de aeroporto |
| `total_amount` | DOUBLE | `total_amount` | Valor total cobrado |
| `pickup_datetime` | TIMESTAMP | `pickup_datetime` | Data/hora de embarque (desnormalizada para cálculo de duração) |
| `dropoff_datetime` | TIMESTAMP | `dropoff_datetime` | Data/hora de desembarque (desnormalizada para cálculo de duração) |

---

### Dimensão: `dim_date`

Gerada a partir das datas de embarque (`pickup_datetime`) presentes em
`stg_yellow_taxi`. A ligação da fato com a dimensão de tempo se dá
exclusivamente pela data de embarque. A data de desembarque é mantida
desnormalizada na fato para cálculos de duração de viagem.

| Coluna | Tipo DuckDB | Descrição |
|---|---|---|
| `date_sk` | VARCHAR | Surrogate Key (MD5 da data no formato `YYYY-MM-DD`) |
| `full_date` | DATE | Data completa |
| `year` | INTEGER | Ano |
| `month` | INTEGER | Mês (número) |
| `month_name` | VARCHAR | Nome do mês (em inglês, conforme padrão TLC) |
| `day` | INTEGER | Dia do mês |
| `day_of_week` | INTEGER | Dia da semana (0 = domingo, conforme `DAYOFWEEK()` do DuckDB) |
| `day_name` | VARCHAR | Nome do dia da semana |
| `week_of_year` | INTEGER | Semana ISO do ano |
| `is_weekend` | BOOLEAN | Verdadeiro se sábado ou domingo |

---

### Dimensão: `dim_location` — Role-Playing (embarque e desembarque)

Uma única tabela física `dim_location` é referenciada duas vezes em
`fct_trips` com foreign keys de papéis distintos:

- `pickup_location_sk` → papel de **embarque**
- `dropoff_location_sk` → papel de **desembarque**

Essa abordagem evita duplicação física dos dados de zona e é o padrão Kimball
para dimensões reutilizadas com papéis diferentes. Se necessário para
legibilidade em consultas analíticas, views nomeadas `dim_pickup_location` e
`dim_dropoff_location` podem ser criadas como aliases sem custo de
armazenamento adicional.

| Coluna | Tipo DuckDB | Origem (`stg_zone_lookup`) | Descrição |
|---|---|---|---|
| `location_sk` | VARCHAR | gerada via MD5 | Surrogate Key da zona |
| `location_id` | INTEGER | `location_id` | ID original da zona (NYC TLC) |
| `borough` | VARCHAR | `borough` | Bairro/Borough |
| `zone` | VARCHAR | `zone` | Nome da zona geográfica |
| `service_zone` | VARCHAR | `service_zone` | Tipo de zona de serviço |

---

### Dimensão: `dim_payment`

Dimensão de baixa cardinalidade construída a partir do dicionário de dados
NYC TLC. Contém os 7 tipos de pagamento definidos pelo dicionário oficial.

| Coluna | Tipo DuckDB | Descrição |
|---|---|---|
| `payment_sk` | VARCHAR | Surrogate Key (MD5 do `payment_type_code`) |
| `payment_type_code` | INTEGER | Código numérico do tipo de pagamento |
| `payment_description` | VARCHAR | Descrição textual conforme dicionário TLC |

Mapeamento do dicionário NYC TLC:

| `payment_type_code` | `payment_description` |
|---|---|
| `0` | Flexível / Não informado |
| `1` | Cartão de crédito |
| `2` | Dinheiro |
| `3` | Sem cobrança |
| `4` | Disputa |
| `5` | Desconhecido |
| `6` | Viagem anulada |

---

## Surrogate Keys via MD5

Todas as dimensões e a tabela fato utilizam Surrogate Keys geradas por hash
`MD5` sobre a chave natural de cada entidade. Essa abordagem garante
**idempotência total na carga**: executar o script de carga múltiplas vezes
produz o mesmo valor de SK para o mesmo input, sem necessidade de sequências
ou mecanismos de auto-incremento externos — comportamento essencial em
ambientes DuckDB sem suporte nativo a `SERIAL`/`IDENTITY` em contexto ELT.

### Expressão SQL padrão adotada no projeto (DuckDB)

```sql
-- SK de dimensão simples (chave natural de um único campo)
MD5(CAST(location_id AS VARCHAR)) AS location_sk

-- SK de dimensão de data
MD5(STRFTIME(CAST(pickup_datetime AS DATE), '%Y-%m-%d')) AS date_sk

-- SK de tabela fato (chave composta — separador '|' previne colisões por concatenação)
MD5(
    CAST(pickup_datetime      AS VARCHAR) || '|' ||
    CAST(dropoff_datetime     AS VARCHAR) || '|' ||
    CAST(vendor_id            AS VARCHAR) || '|' ||
    CAST(pickup_location_id   AS VARCHAR) || '|' ||
    CAST(dropoff_location_id  AS VARCHAR)
) AS trip_sk
```

> **Nota sobre colisões:** MD5 produz hash de 128 bits (~3,4 × 10³⁸ valores
> possíveis). Para ~2,96 milhões de viagens, a probabilidade de colisão é
> desprezível (~2,56 × 10⁻²⁷). Se houver exigência de segurança criptográfica
> futura, o DuckDB suporta `sha256()` com chaves de 256 bits, ao custo de
> strings 2× maiores (64 vs. 32 caracteres hex).

---

## Consequências

### Trade-offs assumidos com a desnormalização (Star Schema)

| Aspecto | Impacto assumido |
|---|---|
| **Redundância de dados** | Strings de `borough` e `zone` repetidas em `dim_location` para cada localização distinta. Aceitável: no máximo 265 linhas na dimensão, impacto de armazenamento negligenciável. |
| **Consistência na recarga** | Alterações nos dados de zona exigem recarga completa de `dim_location`. No contexto do projeto (carga única, dataset estático de janeiro/2024), isso não é uma limitação prática. |
| **Desempenho de leitura** | JOINs diretos sem subtabelas intermediárias favorecem o planejador colunar vetorizado do DuckDB. Ganho esperado em consultas de agregação por zona e período temporal. |
| **Role-Playing sem views de alias** | Sem views nomeadas por papel, ferramentas de consulta podem exibir `dim_location` com ambiguidade de papel (embarque vs. desembarque). Mitigável com `CREATE OR REPLACE VIEW` sem custo de armazenamento adicional. |
| **SK por MD5** | MD5 não é criptograficamente seguro, mas é suficiente e idiomático para Surrogate Keys em data warehouses onde colisão de hash é evento de probabilidade desprezível. Alternativa `sha256()` disponível no DuckDB se necessário. |
| **`pickup_datetime` e `dropoff_datetime` desnormalizadas na fato** | Viola a forma normal da modelagem dimensional pura, mas é prática Kimball aceita quando os timestamps são necessários para métricas de duração que não cabem em `dim_date`. |
