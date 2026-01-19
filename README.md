# Data Platform (Airflow + dbt + Postgres + Docker)

Plataforma de dados em contêineres para orquestração (Airflow), transformação (dbt) e persistência (Postgres), com observabilidade básica via dbt docs e acesso a banco via pgAdmin. Pipeline exemplo em arquitetura medallion (bronze → silver → gold → data marts).

## Stack

- Airflow (webserver, scheduler, 3 workers) com CeleryExecutor
- Redis (broker do Celery)
- Postgres para Airflow metadata
- Postgres para dados (dbt) com bases `data_lake`, `dev`, `pro`
- dbt (dbt-postgres) + dbt docs server
- pgAdmin para acesso visual aos bancos
- Docker Compose para orquestração local
- CI (GitHub Actions): valida `docker-compose.yml`, DAGs, `dbt deps/parse` e smoke `dbt build --target dev`

## Serviços e portas

- Airflow Web: http://localhost:8080 (user/pass: admin/admin)
- pgAdmin: http://localhost:5050 (admin@admin.com / admin)
- dbt docs: http://localhost:8081
- Postgres Airflow: localhost:5433 (airflow/airflow, db airflow_db)
- Postgres dbt: localhost:5434 (dbt/dbt, bases data_lake/dev/pro)
- Redis: localhost:6379
- SSH dbt container: localhost:2222 (root, chave gerada no volume)

## Estrutura de diretórios (principal)

- `airflow/dags/` — DAGs (ex.: `forex__customer_transactions__hourly.py`)
- `airflow/logs/` — logs (ignorado no git)
- `dbt/` — projeto dbt (modelos bronze/silver/gold/data_marts)
- `postgres_config/` — init SQL para Postgres dbt (`init_postgres_dbt.sql`)
- `data/` — dados de exemplo (CSV)
- `docker-compose.yml` — orquestração dos serviços

## Subindo o ambiente

```bash
docker-compose up -d
```

Acessos rápidos:
- Airflow: http://localhost:8080
- pgAdmin: http://localhost:5050
- dbt docs: http://localhost:8081

## Credenciais padrão

- Airflow DB: user/pass `airflow` / DB `airflow_db`
- Postgres dbt: user/pass `dbt` / DBs `data_lake`, `dev`, `pro`
- Airflow UI: admin / admin
- pgAdmin: admin@admin.com / admin

## Pipeline de exemplo (DAG FOREX__CUSTOMER_TRANSACTIONS__HOURLY)

1) Extract: divide CSV em chunks.
2) Load: MERGE em `data_lake.forex.customer_transactions` via Dynamic Task Mapping.
3) Transform: `dbt deps && dbt build --target pro` via SSHOperator.

## dbt

- Alvos: `dev` e `pro`; leitura de `data_lake` via dblink (variáveis `DBLINK_*`).
- Estrutura medallion:
  - bronze (views, leitura bruta)
  - silver (tabelas limpas)
  - gold (fatos/dimensões)
  - data_marts (views de consumo)
- Variáveis/credenciais: ver `dbt/profiles.yml` e `dbt/dbt_project.yml`.

## Acesso a bancos (pgAdmin)

- Host dbt: `postgres-dbt`, port 5432, user/pass `dbt`, DBs `data_lake` / `dev` / `pro`.
- Host Airflow: `postgres-airflow`, port 5432, user/pass `airflow`, DB `airflow_db`.

## dbt docs

- Serviço `dbt-docs` gera e serve documentação em http://localhost:8081.
- Comandos internos: `dbt deps && dbt docs generate && dbt docs serve --host 0.0.0.0 --port 8081`.

## CI (GitHub Actions)

Workflow `CI` roda em push/PR:
- `lint_yaml_and_compose`: `docker compose -f docker-compose.yml config`
- `airflow_dag_validation`: `python -m py_compile airflow/dags/*.py`
- `dbt_checks`: `dbt deps && dbt parse` (override entrypoint do container)
- `dbt_smoke_dev`: sobe `postgres-dbt`, espera `pg_isready`, roda `dbt build --target dev`, depois `docker compose down`

Branch protection (configure no GitHub):
- Exigir PR antes de merge.
- Exigir status checks do workflow `CI`.
- Opcional: branch up-to-date, code owners, signed commits.

## Comandos úteis

- Subir tudo: `docker-compose up -d`
- Parar: `docker-compose down`
- Parar e limpar volumes: `docker-compose down -v`
- Logs Airflow web: `docker-compose logs -f airflow-webserver`
- Entrar no container dbt: `docker exec -it dbt bash`
- PSQL no Postgres dbt: `docker exec -it postgres-dbt psql -U dbt -d data_lake`

## Próximos passos

- Adicionar testes de dados (dbt tests ou Great Expectations).
- Observabilidade: Prometheus/Grafana, logs centralizados.
- Segurança: Docker secrets / vault para credenciais.
- CI otimizado: state:modified + defer para dbt (Slim CI).
