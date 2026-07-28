# U-Easy Mobility Analytics - Pipeline ELT Yellow Taxi NYC (Equipe 8)

Este repositório contém a infraestrutura de código SQL para a construção de um pipeline de dados analítico, reproduzível e idempotente utilizando o motor **DuckDB**, desenvolvido como solução para o desafio prático da Liga Acadêmica de Engenharia de Dados (LED - UFPE).

---

## 1. Sobre o Projeto

A equipe do aplicativo **U-Easy** busca otimizar a mobilidade urbana em grandes centros, mas carece de expertise interna para tratar grandes volumes de dados inconsistentes. 

Nossa missão é transformar a base pública de registros de viagens de táxi de Nova York (NYC Yellow Taxi) referente a **Janeiro de 2024**, juntamente com a tabela de mapeamento de zonas, em um banco de dados analítico confiável (Star Schema). Este banco de dados serve como motor para responder perguntas de negócio complexas envolvendo tempo, geografia, comportamento financeiro e eficiência operacional.

Para garantir a máxima confiabilidade e alinhamento com as melhores práticas de Engenharia de Dados, assumimos as seguintes premissas técnicas:
* **Processamento 100% ELT em SQL:** Nenhuma ferramenta visual, planilha eletrônica ou linguagem secundária (como Python/R) foi utilizada para limpeza. O dado bruto é ingerido nativamente pelo DuckDB e transformado internamente.
* **Tolerância Zero a Edições Manuais:** É proibido mascarar falhas alterando arquivos originais.
* **Governança e Transparência:** Nenhuma linha de dado é apagada silenciosamente. Tudo o que não atende às regras de negócio é desviado para uma trilha de auditoria explícita.

---

## 2. Estratégia de Divisão em Sprints

Para organizar o desenvolvimento dentro do prazo estrito de 15 dias, adotamos a metodologia de **Micro-sprints** de aproximadamente 48 horas. A governança da equipe foi pautada na *Servant Leadership*, garantindo que o conhecimento não ficasse retido em silos (o "desenvolvedor herói"). Todos os membros realizaram revisões cruzadas (*Pull Requests*) para dominar a totalidade do código.

O fluxo de dados foi dividido logicamente e executado ao longo das seguintes Sprints:

1. **Camada Raw (S1):** Ingestão pura, cópia fiel da fonte.
2. **Perfilamento (S2):** Investigação de anomalias e estatísticas.
3. **Camada Staging (S3):** Limpeza analítica, `TRY_CAST` e auditoria de rejeições.
4. **Modelagem Dimensional (S4):** Desenho arquitetural do Esquema Estrela (ADRs).
5. **Materialização (S5):** Criação das Fatos e Dimensões usando chaves substitutas.
6. **Data Quality (S6):** Testes SQL de reconciliação matemática.
7. **Camada Analítica (S7):** Consultas OLAP de negócio para o app U-Easy.
8. **Auditoria Final (S8):** Defesa técnica, polimento e teste do pipeline zero.

---

## 3. Execução do Pipeline Analítico

Abaixo, detalhamos a evolução do pipeline e os principais *insights* técnicos e de negócio documentados pela nossa equipe diretamente nos códigos-fonte (`/src`).

### Sprint 1: Setup do ambiente e ingestão bruta
* **O que foi feito:** Criação do script `create_raw_tables.sql` para mapear os arquivos Parquet (`yellow_tripdata_2024-01.parquet`) e CSV (`taxi_zone_lookup.csv`) diretamente para dentro do DuckDB.
* **Insights Técnicos:** As tabelas `raw_yellow_taxi` e `raw_zone_lookup` foram criadas como cópias fiéis da origem. Nenhuma tipagem forçada ou filtro foi aplicado nesta etapa. Isso garante total preservação da fonte para rastreabilidade e mantém a idempotência do pipeline: o sistema pode ser recarregado do zero repetidas vezes produzindo o exato mesmo ponto de partida.

### Sprint 2: Perfilamento de Dados Analítico
* **O que foi feito:** Execução massiva de queries investigativas (`profiling_queries.sql`) para identificar anomalias numéricas, volumetria de nulos, cardinalidades e vazamentos de escopo.
* **Insights do Profiling:** 
  * Descobrimos mais de 140 mil registros nulos em colunas vitais como contagem de passageiros e taxas financeiras.
  * Identificamos viagens fisicamente impossíveis (corridas com mais de 300 milhas ou velocidades acima de 70 mph).
  * Detectamos vazamento de dados temporais (viagens registradas antes de 01/01/2024 e após 31/01/2024).
  * Encontramos "duplicidades parciais": corridas com a mesma chave lógica de local e tempo, mas tarifas diferentes (possíveis cancelamentos ou estornos do taxímetro).
  * Estes achados impediram que as regras de limpeza fossem criadas baseadas em "intuição", fundamentando cientificamente os filtros da Sprint 3.

### Sprint 3: Limpeza e Camada de Staging
* **O que foi feito:** Desenvolvimento da `create_staging_views.sql`, aplicando conversões de tipo defensivas (`TRY_CAST`) e implementando a tabela de auditoria ativa (`rejected_records`).
* **Insights de Engenharia:**
  * **Tratamento de Nulos Inteligente:** Ao invés de deletar corridas sem `passenger_count`, atribuímos o valor `1` (comportamento padrão). Valores financeiros nulos foram convertidos em `0.00` para não quebrar funções de agregação analítica `SUM()` no futuro.
  * **Auditoria Ativa (Anti-deleção):** O grupo criou 12 regras estritas de negócio (ex: data de desembarque menor que embarque, tarifas > $1000, distância zerada com cobrança, excesso de passageiros > 6). As linhas que violaram essas regras **não foram deletadas**, mas sim isoladas em `rejected_records` com a devida justificativa (`rejection_reason`).
  * Utilizamos a pseudocoluna lógica `rowid` do DuckDB para garantir a exclusão inequívoca desses registros defeituosos da view final de Staging, eliminando falsos positivos.

### Sprint 4: Desenho de Arquitetura Dimensional (ADR-0002)
* **O que foi feito:** Planejamento teórico da transição da staging para o modelo estruturado em *Star Schema*.
* **Insights Arquiteturais:**
  * Mantivemos o **grão atômico**: uma linha na fato é estritamente uma viagem individual concluída.
  * **Surrogate Keys Hash:** Ao invés de usar `AUTO_INCREMENT` (o que quebraria em fluxos distribuídos ou recargas), decidimos utilizar algoritmos de *Hash MD5* baseados nos atributos naturais para as chaves primárias.
  * **Role-Playing Dimension:** Decidimos reaproveitar a dimensão de localização. Uma única tabela `dim_location` atende tanto a zona de embarque quanto a de desembarque na tabela fato.

### Sprint 5: Materialização e Carga do Star Schema
* **O que foi feito:** Codificação da criação e inserção das tabelas `dim_location`, `dim_time`, `dim_payment` e da matriz central `fact_trips`.
* **Insights Técnicos:**
  * **Proteção contra Perda de Dados (Unknown Member):** Inserimos proativamente a linha de salvaguarda `-1` (`MD5_UNKNOWN`) em todas as dimensões. Se uma corrida veio sem código de pagamento ou de zona mapeada, o `LEFT JOIN` na criação da tabela fato a associa a este membro desconhecido, protegendo o banco contra "evaporação" silenciosa de registros na Fato e preservando o faturamento total da companhia.
  * A dimensão temporal (`dim_time`) foi enriquecida nativamente com marcações analíticas úteis, como determinação de dia da semana, trimestres e se a corrida ocorreu no final de semana (`is_weekend`).

### Sprint 6: Plano de Data Quality (DQ) e Reconciliação
* **O que foi feito:** Scripts de testes rigorosos em `quality_checks.sql` e `dq_reconciliation.sql` para avaliar matematicamente a integridade do pipeline.
* **Insights de Garantia de Qualidade:**
  * Provamos através de queries de reconciliação que **Raw = Fato + Rejeições**. A query final resulta em uma diferença absoluta de `0` linhas e `0.00` dólares. Todo centavo original foi rastreado, validado ou descartado de forma justificada.
  * Testes adicionais garantem zero chaves nulas (`completude`), zero chaves duplicadas na Fato (`unicidade`) e perfeita aderência entre a fato e as dimensões (`integridade referencial`).

### Sprint 7: Camada Analítica e Perguntas de Negócio
* **O que foi feito:** Desenvolvimento da suíte de consultas analíticas (`business_queries.sql`) organizadas em quatro pilares estratégicos: Finanças, Operação, Geografia e Tempo, formatadas para consumo direto por ferramentas de BI.
* **Insights Técnicos e de Negócio:**
  * **Isolamento Estrutural:** As queries rodam estritamente sobre as tabelas dimensionais (Star Schema), não acessando a camada bruta. Isso garante a performance analítica e assegura o modelo como a fonte única de verdade corporativa.
  * **Uso de CTEs e Window Functions:** Lógicas complexas de cálculo foram modularizadas através de Common Table Expressions (CTEs) descritivas. Além disso, aplicamos funções de janela como `DENSE_RANK()` para elencar de forma robusta os fluxos espaciais de viagens mais volumosos na cidade (ex: mapeando grandes corredores como Aeroportos e Midtown).
  * **Métricas Acionáveis:** O script consolida os KPIs globais essenciais (ticket médio, velocidade média da operação, percentual médio de gorjeta) e fornece o cruzamento de volumetria e faturamento por faixas de horário (manhã, tarde, noite, madrugada), embasando futuras estratégias de precificação dinâmica (surge pricing) para o aplicativo U-Easy.

### Sprint 8: Auditoria Final e Reprodutibilidade
* **O que foi feito:** Criação do orquestrador mestre `run_pipeline.sql` e consolidação final da documentação técnica e arquitetural.
* **Insights de Engenharia e Defesa:**
  * **Orquestração Transparente e Funcional:** O script mestre foi estruturado para invocar sequencialmente todas as etapas do pipeline. Ao rodar desde a extração bruta, passando pelo perfilamento, limpeza, modelagem, até as consultas de negócio, garantimos que o processo inteiro está interligado e perfeitamente funcional do início ao fim.
  * **Reprodutibilidade Absoluta ("Do Zero"):** O repositório foi exaustivamente testado para garantir que qualquer avaliador consiga clonar o projeto e, com um único comando, recriar todo o banco de dados analítico, validando os dados na íntegra e passando 100% nos testes de Data Quality.
