# ADR 0002 — Star Schema: Modelagem Física da Camada Dimensional

## Metadados

| Campo | Valor |
|---|---|
| **Número** | ADR-0002 |
| **Título** | Star Schema — Modelagem Física da Camada Dimensional |
| **Status** | Aceito |
| **Data** | 2026-07-21 |
| **Projeto** | led-taxi-elt — LED UFPE (Vaga de Pesquisador) |

---

## Contexto

O pipeline ELT `led-taxi-elt` processa ~2,96 milhões de corridas de táxi
amarelo de Nova Iorque (janeiro de 2024) sobre DuckDB. Após as camadas Raw e
Staging, a camada Dimensional deve suportar consultas OLAP por tempo,
localização geográfica e modalidade de pagamento.

Uma revisão técnica (Sprint 4) identificou três falhas no modelo anterior:

1. **Inconsistência de nomenclatura** entre tabelas e campos (mistura de
   português e inglês, ausência de padrão `snake_case`).
2. **Chaves estrangeiras incompletas** — ausência de anotações `FK` explícitas
   no diagrama Mermaid, impedindo rastreabilidade do grafo de dependências.
3. **Dessincronia entre o diagrama Mermaid e o ADR** — campos presentes no
   diagrama não apareciam no mapeamento de atributos e vice-versa.

Este ADR documenta as decisões corretivas e define o esquema canônico de
nomenclatura a ser seguido por todas as sprints subsequentes.

---

## Decisão

### (i) Granularidade atômica

A tabela fato `fact_trips` possui granularidade atômica:

> **Uma linha em `fact_trips` representa exatamente uma viagem de táxi amarelo
> concluída, conforme registrada pelo sistema TPEP e entregue pela camada
> Staging (`stg_yellow_taxi`).**

Não há pré-agregação. Cada corrida individual materializa uma linha na fato,
preservando a capacidade analítica máxima e permitindo qualquer nível de
roll-up posterior.

### (ii) Padronização para inglês (`snake_case`)

Todos os identificadores (tabelas, campos, chaves) são definidos em inglês,
seguindo o dicionário de dados original da fonte TLC NYC. A consistência com a
fonte elimina camadas de tradução que introduzem ambiguidade e dificulta a
rastreabilidade de linhagem de dados.

Esquema canônico de nomenclatura:

| Escopo | Padrão | Exemplos |
|---|---|---|
| Tabelas | `snake_case` em inglês | `fact_trips`, `dim_time`, `dim_location`, `dim_payment` |
| Chaves primárias | `<entidade>_key` | `trip_key`, `time_key`, `location_key`, `payment_key` |
| Chaves estrangeiras (contextualizadas) | `<contexto>_<dimensao>_key` | `pickup_location_key`, `dropoff_location_key` |
| Medidas | substantivo descritivo | `fare_amount`, `trip_distance`, `tip_amount` |

### (iii) Surrogate Keys via hash MD5

Todas as chaves primárias das dimensões e da fato são Surrogate Keys geradas
por `MD5()` sobre a chave natural da entidade. Esse mecanismo garante:

- **Idempotência**: a mesma entrada sempre produz o mesmo hash, tornando
  reexecuções do pipeline seguras sem duplicação.
- **Independência de sequência**: não há dependência de `AUTO_INCREMENT`,
  `SEQUENCE` ou qualquer mecanismo de numeração sequencial nativo do banco,
  o que é obrigatório no contexto DuckDB + ELT puro.

Expressões SQL de referência (DuckDB):

```sql
-- dim_time
MD5(STRFTIME(CAST(pickup_datetime AS DATE), '%Y-%m-%d')) AS time_key

-- dim_location
MD5(CAST(location_id AS VARCHAR)) AS location_key

-- dim_payment
MD5(CAST(payment_type_code AS VARCHAR)) AS payment_key

-- fact_trips (chave composta com separador para evitar colisões)
MD5(
    CAST(pickup_datetime    AS VARCHAR) || '|' ||
    CAST(dropoff_datetime   AS VARCHAR) || '|' ||
    CAST(vendor_id          AS VARCHAR) || '|' ||
    CAST(pickup_location_id AS VARCHAR) || '|' ||
    CAST(dropoff_location_id AS VARCHAR) || '|' ||
    CAST(trip_distance AS VARCHAR) || '|' ||
    CAST(passenger_count AS VARCHAR)
) AS trip_key
```

---

## Mapeamento de Atributos

### `fact_trips` — Tabela Fato

| Campo | Tipo | Papel | Descrição |
|---|---|---|---|
| `trip_key` | `VARCHAR` | PK | Surrogate Key da viagem (MD5 composto) |
| `time_key` | `VARCHAR` | FK → `dim_time` | Data de embarque |
| `pickup_location_key` | `VARCHAR` | FK → `dim_location` | Localização de embarque (Role-Playing) |
| `dropoff_location_key` | `VARCHAR` | FK → `dim_location` | Localização de desembarque (Role-Playing) |
| `payment_key` | `VARCHAR` | FK → `dim_payment` | Método de pagamento |
| `pickup_datetime` | `TIMESTAMP` | Atributo operacional | Data/hora de embarque |
| `dropoff_datetime` | `TIMESTAMP` | Atributo operacional | Data/hora de desembarque |
| `passenger_count` | `INT` | Medida semiaditiva | Número de passageiros |
| `trip_distance` | `FLOAT` | Medida aditiva | Distância percorrida (milhas) |
| `fare_amount` | `DECIMAL` | Medida aditiva | Tarifa base |
| `tip_amount` | `DECIMAL` | Medida aditiva | Gorjeta |
| `tolls_amount` | `DECIMAL` | Medida aditiva | Pedágios |
| `total_amount` | `DECIMAL` | Medida aditiva | Valor total cobrado |

---

### `dim_time` — Dimensão Tempo

| Campo | Tipo | Descrição |
|---|---|---|
| `time_key` | `VARCHAR` | Surrogate Key (MD5 da data `YYYY-MM-DD`) |
| `date` | `DATE` | Data completa |
| `year` | `INT` | Ano |
| `semester` | `INT` | Semestre (1 ou 2) |
| `quarter` | `INT` | Trimestre (1–4) |
| `month` | `INT` | Mês (1–12) |
| `day` | `INT` | Dia do mês |
| `day_of_week` | `VARCHAR` | Nome do dia da semana |
| `is_weekend` | `BOOLEAN` | Verdadeiro se sábado ou domingo |

Gerada a partir das datas de embarque (`pickup_datetime`) presentes em
`stg_yellow_taxi`. A data de desembarque é mantida desnormalizada em
`fact_trips` para cálculo de duração sem JOIN adicional.

---

### `dim_location` — Dimensão Localização (Role-Playing)

| Campo | Tipo | Descrição |
|---|---|---|
| `location_key` | `VARCHAR` | Surrogate Key (MD5 de `location_id`) |
| `location_id` | `INT` | Chave natural — ID de zona TLC NYC |
| `borough` | `VARCHAR` | Borough (ex.: Manhattan, Brooklyn) |
| `zone` | `VARCHAR` | Nome da zona geográfica |
| `service_zone` | `VARCHAR` | Tipo de zona de serviço |

Uma única tabela física. Referenciada duas vezes por `fact_trips` com FKs de
papéis distintos (`pickup_location_key` e `dropoff_location_key`). Máximo de
265 linhas (cardinalidade total de `stg_zone_lookup`).

---

### `dim_payment` — Dimensão Pagamento

| Campo | Tipo | Descrição |
|---|---|---|
| `payment_key` | `VARCHAR` | Surrogate Key (MD5 de `payment_type_code`) |
| `payment_type_code` | `INT` | Código numérico — Natural Key (dicionário TLC) |
| `payment_description` | `VARCHAR` | Descrição textual do método de pagamento |

Dimensão de baixa cardinalidade (7 linhas). Construída a partir do dicionário
oficial TLC NYC.

---

## Consequências

### Positivos

| Trade-off | Impacto |
|---|---|
| Star Schema puro | JOINs diretos entre fato e dimensões sem hierarquias intermediárias; favorece o planejador colunar vetorizado do DuckDB |
| Surrogate Keys por MD5 | Idempotência de carga garantida sem dependência de mecanismo sequencial externo |
| Role-Playing em `dim_location` | Elimina duplicação física de dados de zona; uma única tabela de 265 linhas atende dois papéis distintos na fato |
| Nomenclatura em inglês | Alinhamento direto com o dicionário de dados TLC NYC; elimina camada de tradução na rastreabilidade de linhagem |
| Granularidade atômica | Preserva flexibilidade máxima para roll-up em qualquer dimensão sem perda de informação |

### Negativos

| Trade-off | Impacto assumido |
|---|---|
| Desnormalização de `dim_time` | `semester` e `quarter` são atributos derivados de `month`, introduzindo redundância calculada; aceitável em OLAP onde a leitura supera a escrita por ordens de magnitude |
| Role-Playing sem views de alias | Sem views `dim_pickup_location` / `dim_dropoff_location`, ferramentas de consulta exibem `dim_location` com ambiguidade de papel; mitigável com `CREATE OR REPLACE VIEW` sem custo de armazenamento |
| MD5 e colisões | Probabilidade de colisão desprezível (~2⁻⁶⁴) para ~2,96 milhões de viagens; MD5 não é criptograficamente seguro, mas é suficiente para Surrogate Keys em DW de pequeno e médio porte |
| `pickup_datetime` e `dropoff_datetime` na fato | Viola a forma normal dimensional pura, mas é prática Kimball aceita quando os timestamps são necessários para métricas de duração que não cabem em `dim_time` |
