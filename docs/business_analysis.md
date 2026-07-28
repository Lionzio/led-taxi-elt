# Documentação Analítica — Sprint 7: Business Queries e Dashboards

Esta documentação descreve as decisões analíticas tomadas durante a Sprint 7 do projeto LED Taxi ELT, desenvolvido para a plataforma U-Easy. O objetivo é registrar formalmente a arquitetura da camada analítica, as perguntas de negócio endereçadas, as consultas implementadas e as recomendações para a construção e manutenção dos dashboards de Business Intelligence.

O documento serve como referência técnica e de negócio para Analytics Engineers, Data Engineers, Analistas de BI, Product Managers e stakeholders executivos envolvidos na operação e na evolução da plataforma analítica.

---

## Objetivo da Análise

A camada analítica construída na Sprint 7 tem como objetivo central transformar dados operacionais de viagens de táxi — previamente processados e modelados no Star Schema — em indicadores de negócio acionáveis, organizados em quatro frentes temáticas: **finanças**, **operação**, **geografia** e **tempo**.

As consultas implementadas suportam diretamente as seguintes decisões de negócio:

- Monitoramento do desempenho financeiro da frota por meio de indicadores de receita média, valor por milha e comportamento de gorjetas.
- Identificação de rotas e zonas de maior concentração de demanda, orientando estratégias de posicionamento e expansão.
- Detecção de padrões de sazonalidade horária, diária e semanal, fundamentais para planejamento operacional e escalabilidade da frota.
- Análise do comportamento do faturamento médio por período do dia e dia da semana, apoiando decisões de precificação dinâmica.

Os principais públicos beneficiados por este documento são:

- **Analytics Engineers e Data Engineers:** referência de arquitetura e padrões de código para manutenção e extensão do pipeline.
- **Analistas de BI:** guia de interpretação das métricas e recomendações para a construção de painéis.
- **Product Managers e Stakeholders Executivos:** visão consolidada dos indicadores disponíveis e das perguntas de negócio que a plataforma é capaz de responder.

---

## Perguntas de Negócio

A tabela a seguir mapeia as perguntas de negócio respondidas pela camada analítica, associando cada uma à frente temática responsável e descrevendo como a consulta correspondente estrutura a resposta.

| Pergunta de Negócio | Frente Analítica | Como a consulta responde à pergunta |
|---|---|---|
| Qual é o ticket médio pago por viagem e o valor cobrado por milha? | Finanças | A CTE `trip_metrics` agrega `total_amount` e `fare_amount` sobre o conjunto de viagens válidas, calculando médias globais com proteção contra divisão por zero via `NULLIF`. |
| Qual é a porcentagem média de gorjeta em relação à tarifa base? | Finanças | A mesma CTE calcula a razão individual `tip_amount / fare_amount` por viagem antes de agregar, garantindo que a média reflita o comportamento típico por corrida e não a razão das somas totais. |
| Quais são os principais fluxos de origem e destino na operação? | Geografia | A CTE `spatial_flows` realiza dois JOINs com `dim_location` como Role-Playing Dimension, agrupa por par de zonas e aplica `DENSE_RANK()` para identificar os dez fluxos mais frequentes. |
| Quais zonas geram e absorvem o maior volume de viagens? | Geografia | O agrupamento por `zona_origem` e `zona_destino` na consulta do Dashboard 2 permite identificar individualmente as zonas mais ativas em ambas as direções. |
| Em quais horários do dia ocorre a maior concentração de viagens? | Tempo | A Query 3.1 extrai a hora de `pickup_datetime` via `EXTRACT(HOUR)`, agrega o volume por hora e retorna os cinco horários de maior demanda. |
| Qual foi o dia e a semana com maior volume de viagens no período? | Tempo | As Queries 3.2 e 3.3 realizam JOIN com `dim_time` e aplicam `DATE_TRUNC` para derivar dinamicamente a granularidade diária e semanal, retornando o período de pico com `LIMIT 1`. |
| Como o valor médio pago varia por dia da semana e faixa horária? | Operação | A CTE `trip_time_bands` classifica cada viagem em uma das quatro faixas do dia via `CASE WHEN`. O SELECT final cruza com `dim_time` e agrega `AVG(total_amount)` por dia e faixa, revelando padrões de faturamento ao longo da semana. |
| Qual é a velocidade média operacional da frota? | Operação | A velocidade média é calculada como `SUM(trip_distance) / NULLIF(SUM(duration_hours), 0)`, aplicando a razão sobre somas agregadas para evitar distorções causadas pela média de razões individuais. |

---

## Arquitetura Analítica

### Modelo Dimensional (Star Schema)

Toda a camada analítica opera exclusivamente sobre o modelo dimensional consolidado, composto por uma tabela fato central (`fact_trips`) e dimensões associadas (`dim_location`, `dim_time`, entre outras). Essa arquitetura, baseada na metodologia Kimball, garante separação clara entre métricas de negócio e atributos descritivos, favorecendo consultas analíticas de alto desempenho e baixa complexidade de leitura.

A tabela fato concentra as medidas quantitativas da operação — distâncias, valores financeiros, chaves de data e localização — enquanto as dimensões fornecem o contexto qualitativo necessário para agrupamentos, filtros e drill-downs.

### Separação entre Camada Bruta e Camada Analítica

Nenhuma consulta analítica acessa diretamente a camada bruta (raw). Todo o acesso aos dados ocorre sobre estruturas já transformadas, validadas e modeladas pelo pipeline ELT. Essa separação elimina o risco de inconsistências derivadas de dados não tratados, garante que as métricas reflitam as regras de negócio definidas nas etapas anteriores e simplifica a governança da qualidade dos dados.

### Utilização de CTEs

As consultas fazem uso extensivo de Common Table Expressions (CTEs) para modularizar a lógica analítica. Cada CTE representa uma etapa de transformação claramente nomeada e com responsabilidade única — seja filtragem, enriquecimento, classificação ou pré-agregação. Essa abordagem proporciona:

- **Legibilidade:** a intenção de cada etapa é explícita e isolada, facilitando a revisão por pares.
- **Manutenibilidade:** alterações em uma etapa não exigem reescrita do restante da consulta.
- **Reutilização:** o mesmo padrão de CTE pode ser replicado e adaptado para novos dashboards sem duplicação de lógica de negócio.

### Utilização de Window Functions

O Dashboard 2 emprega `DENSE_RANK()` como Window Function para atribuir posições de ranking aos fluxos de viagens sem eliminá-los do conjunto de resultados antes da filtragem final. Essa abordagem é superior a alternativas com subconsultas aninhadas por ser mais legível, eficiente e compatível com extensões futuras — como a adição de particionamento por período ou categoria de serviço.

### Benefícios Arquiteturais

| Dimensão | Benefício |
|---|---|
| Desempenho | Consultas sobre o modelo dimensional evitam joins com dados brutos volumosos, operando sobre estruturas pré-otimizadas. |
| Manutenção | CTEs com nomes descritivos tornam o código autodocumentado e reduzem o custo de onboarding de novos membros da equipe. |
| Reutilização | Padrões de CTE e Window Function podem ser replicados para novos dashboards com esforço mínimo. |
| Governança | A separação entre camadas garante que todas as análises partam de uma única fonte de verdade, eliminando divergências entre relatórios. |
| Escalabilidade | A arquitetura dimensional suporta adição de novas dimensões e fatos sem exigir refatoração das consultas existentes. |

---

## Utilização dos Dados em Dashboards

### Organização dos Dashboards

Recomendo que os painéis sejam organizados seguindo a mesma estrutura temática das consultas: um painel por frente analítica (KPIs Globais, Análise Espacial, Análise Temporal e Valor por Período). Essa separação facilita a navegação por perfil de usuário — executivos consomem o painel de KPIs; operações utilizam o painel temporal; estratégia de expansão utiliza o painel geográfico.

### Reutilização das Consultas

As consultas do arquivo `business_queries.sql` foram projetadas para ser independentes entre si e imediatamente executáveis. Cada bloco pode ser utilizado diretamente como fonte de dados em ferramentas de BI sem necessidade de adaptação estrutural. Recomendo que o time de BI mantenha essas consultas como a fonte canônica das métricas, evitando recalcular indicadores diretamente nas ferramentas de visualização.

### Consistência das Métricas

Para garantir consistência entre painéis e relatórios, todas as métricas financeiras devem ser calculadas com arredondamento em duas casas decimais (`ROUND(..., 2)`), conforme padronizado nas consultas. Métricas de volume devem sempre usar `COUNT` sobre chaves primárias da tabela fato, evitando contagens sobre colunas que possam conter nulos.

### Atualização dos Painéis

Dado que o pipeline ELT alimenta o modelo dimensional de forma incremental, os painéis devem ser configurados para atualização automática após cada execução do pipeline. Recomendo que a frequência de atualização seja definida em conjunto com o time de engenharia, respeitando a latência aceitável para cada frente analítica — operacional (diária), financeira (diária) e executiva (semanal).

### Boas Práticas para Visualizações Executivas

- Utilizar cartões de indicador (KPI cards) para os seis KPIs globais do Dashboard 1, evitando tabelas densas em visões executivas.
- Exibir o ranking de fluxos espaciais como tabela classificada, com destaque visual para os três primeiros colocados.
- Representar os picos horários como gráfico de barras horizontais, facilitando a comparação entre horas do dia.
- Utilizar mapas de calor para o cruzamento entre dia da semana e faixa horária no Dashboard 4, tornando padrões de faturamento imediatamente visíveis.

### Interpretação Correta dos Indicadores

- O **valor médio cobrado por milha** deve ser interpretado como eficiência tarifária, não como preço fixo — ele varia conforme a composição de viagens curtas e longas no período.
- A **velocidade média operacional** é calculada como razão entre somas (distância total / tempo total), o que a torna mais representativa do comportamento da frota do que a média aritmética de velocidades individuais.
- A **porcentagem média de gorjeta** é calculada como média das razões individuais por viagem, capturando o comportamento típico por corrida e não sendo distorcida por viagens de alto valor absoluto.
- O **início de semana** apresentado na Query 3.3 é derivado dinamicamente via `DATE_TRUNC` e não representa um atributo armazenado na dimensão — deve ser tratado como agregação analítica, não como chave de dimensão.

---

## Evidências

Os dados apresentados nas tabelas a seguir são explicitamente simulados para fins ilustrativos. Representam um cenário plausível de operações de táxis na cidade de Nova York, mantendo consistência interna entre métricas e volumes, mas **não correspondem a resultados reais do projeto**.

### Evidência 1 — KPIs Globais

| KPI | Valor |
|---|---|
| Valor médio pago por viagem | $ 17,84 |
| Distância média por viagem (milhas) | 3,21 |
| Tempo médio por viagem (minutos) | 14,37 |
| Velocidade média da operação (mph) | 13,40 |
| Porcentagem média de gorjeta | 18,62 % |
| Valor médio cobrado por milha | $ 4,92 |

O ticket médio de $ 17,84 combinado com uma distância típica de 3,21 milhas e velocidade operacional de 13,40 mph é consistente com o perfil de corridas urbanas densas, onde o tempo de deslocamento é limitado pelo tráfego. A gorjeta média de 18,62 % sobre a tarifa base indica satisfação acima do padrão mínimo de 15 % habitualmente observado no mercado de transporte em grandes centros urbanos.

---

### Evidência 2 — Top Fluxos

| Ranking | Zona de Origem | Zona de Destino | Volume de Viagens |
|---|---|---|---|
| 1 | Midtown Center | Upper East Side North | 48.320 |
| 2 | Times Sq/Theatre District | Penn Station/Madison Sq West | 41.870 |
| 3 | JFK Airport | Midtown Center | 38.540 |
| 4 | Upper East Side South | Midtown East | 35.210 |
| 5 | Penn Station/Madison Sq West | Times Sq/Theatre District | 33.760 |
| 6 | Midtown East | Upper East Side South | 31.480 |
| 7 | LaGuardia Airport | Midtown Center | 29.150 |
| 8 | Upper West Side North | Upper West Side South | 27.640 |
| 9 | East Village | West Village | 25.990 |
| 10 | Financial District North | Battery Park | 24.310 |

Os dois aeroportos internacionais de Nova York (JFK e LaGuardia) figuram individualmente no Top 10, evidenciando que os corredores aeroporto–Midtown representam uma parcela estrutural da demanda. A bidirecionalidade dos fluxos entre Penn Station e Times Square (posições 2 e 5) sugere um corredor de altíssima rotatividade associado ao tráfego de passageiros intermodais, com potencial elevado para estratégias de posicionamento proativo da frota.

---

### Evidência 3 — Picos Diários

| Hora do Dia | Volume de Viagens |
|---|---|
| 18h | 124.870 |
| 19h | 121.340 |
| 8h | 118.650 |
| 17h | 115.920 |
| 9h | 112.480 |

O padrão de pico bimodal — manhã (8h–9h) e tarde/noite (17h–19h) — é característico de operações urbanas de transporte fortemente correlacionadas com os horários de entrada e saída do trabalho. O pico vespertino é consistentemente superior ao matutino em aproximadamente 5 %, o que pode indicar maior propensão ao uso de táxi no retorno ao domicílio, possivelmente associada ao acúmulo de fadiga ou à menor disponibilidade de transporte público nesse horário. Essa informação é relevante para a calibração da oferta de frota ao longo do dia.
