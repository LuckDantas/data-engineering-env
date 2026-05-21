# Data Engineering Environment

A fully containerized, end-to-end data engineering platform built with Docker Compose. Designed as a learning and development environment covering the complete modern data stack: ingestion, orchestration, transformation, distributed processing, and visualization.

---

## Architecture

```
External Sources                 Ingestion (Airflow)            Storage (PostgreSQL)
────────────────                 ───────────────────            ────────────────────
Kaggle API (Olist)    ────────►  DAG: OLIST__INGESTION          data_lake.olist.*
                                                                        │
                                                                        ▼
                                                         dbt (Medallion Architecture)
                                                         ─────────────────────────────
                                                         Bronze → Silver → Gold → Data Marts
                                                                        │
                                                         ───────────────┼───────────────
                                                         pgAdmin     Spark/Jupyter   Power BI
```

---

## Stack

| Tool | Version | Role |
|---|---|---|
| **Apache Airflow** | 2.7.2 | Pipeline orchestration (CeleryExecutor + Redis) |
| **dbt** | 1.9.0 | SQL transformation — Medallion architecture |
| **Apache Spark** | PySpark | Distributed processing via JupyterLab |
| **PostgreSQL** | 15 | Data warehouse (`data_lake`, `dev`, `pro`) |
| **pgAdmin** | 4 | Database GUI |
| **Redis** | — | Celery message broker |
| **Docker Compose** | — | Full-stack local orchestration |

---

## Services & Ports

| Service | URL | Credentials |
|---|---|---|
| Airflow | http://localhost:8080 | `admin` / `admin` |
| Jupyter (Spark) | http://localhost:8888 | Token: `spark` |
| Spark UI | http://localhost:4040 | — |
| pgAdmin | http://localhost:5050 | `admin@admin.com` / `admin` |
| dbt Docs | http://localhost:8081 | — |
| PostgreSQL (dbt) | `localhost:5434` | `dbt` / `dbt` |
| PostgreSQL (Airflow) | `localhost:5433` | `airflow` / `airflow` |

---

## Quick Start

```bash
docker compose up -d
```

First run downloads images and initializes databases (~3 min). Then access Airflow at http://localhost:8080.

```bash
docker compose down       # stop (keep data)
docker compose down -v    # stop + delete all volumes
```

---

## Pipelines

### Olist — Brazilian E-Commerce (Kaggle)

Full historical load from the [Olist public dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle.

**Setup:**

1. **Kaggle API token** — Airflow UI → **Admin → Variables → +**

   | Key | Value |
   |---|---|
   | `kaggle_api_token` | *(token from kaggle.com → Account → API → Create New Token)* |

2. **PostgreSQL connection** — Airflow UI → **Admin → Connections → +**

   | Field | Value |
   |---|---|
   | Connection Id | `postgres_dbt_conn` |
   | Connection Type | `Postgres` |
   | Host | `postgres-dbt` |
   | Database | `data_lake` |
   | Login | `dbt` |
   | Password | `dbt` |
   | Port | `5432` |

3. **SSH connection to dbt** — Airflow UI → **Admin → Connections → +**

   | Field | Value |
   |---|---|
   | Connection Id | `dbt_conn` |
   | Connection Type | `SSH` |
   | Host | `dbt` |
   | Username | `root` |
   | Port | `22` |
   | Private Key File Path | `/opt/airflow/dbt_ssh_keys/id_rsa` |
   | Extra (JSON) | `{"DBLINK_USER": "dbt", "DBLINK_PASSWORD": "dbt", "DBLINK_HOST": "postgres-dbt", "DBLINK_DBNAME": "data_lake"}` |

4. Trigger `OLIST__INGESTION__ONCE` with config `{ "target": "dev" }` or `{ "target": "pro" }`

**Flow:** Kaggle download → `data_lake.olist.*` (9 tables) → dbt Star Schema

**dbt models:**
```
Bronze (views)       Silver (tables)         Gold (tables)           Data Marts (views)
──────────────       ───────────────         ─────────────           ──────────────────
olist_orders    →    stg_olist_orders   →    fct_pedidos        →    agg_olist_vendas_mensais
olist_customers →    stg_olist_customers→    dim_clientes_olist →    agg_olist_vendas_por_estado
olist_products  →    stg_olist_products →    dim_produtos_olist →    agg_olist_vendas_por_categoria
olist_sellers   →    stg_olist_sellers  →    dim_vendedores_olist
+ 4 more tables →    + 3 more models
```

---

## dbt

### Medallion Layers

| Layer | Materialization | Responsibility |
|---|---|---|
| **Bronze** | View | Raw data exposed via `dblink` from `data_lake` |
| **Silver** | Table | Type casting, null handling, surrogate keys |
| **Gold** | Table | Star Schema — facts and dimensions |
| **Data Marts** | View | Pre-aggregated metrics for BI tools |

### Environments

| Target | Database | Usage |
|---|---|---|
| `dev` | `dev` | Local development |
| `pro` | `pro` | Production (triggered by Airflow) |

**Run manually:**
```bash
docker compose run --rm --entrypoint bash dbt -c \
  "dbt deps && dbt build --select tag:olist --target dev"
```

**dbt Docs** (lineage graph + documentation): http://localhost:8081

---

## Spark / Jupyter

The `jupyter-spark` service provides a local PySpark environment for exploratory analysis and Delta Lake processing.

- Notebooks: `./notebooks/` (persisted on host)
- Data: `./data/` mapped to `/home/jovyan/data`
- Access: http://localhost:8888 (token: `spark`)

---

## Project Structure

```
├── airflow/
│   └── dags/                           # Airflow DAGs
├── dbt/
│   ├── models/
│   │   ├── bronze/                     # Raw views (dblink from data_lake)
│   │   ├── silver/                     # Cleaned and typed tables
│   │   ├── gold/                       # Star Schema
│   │   └── data_marts/                 # Aggregated reporting views
│   ├── macros/generate_schema_name.sql # Schema naming convention
│   └── profiles.yml
├── notebooks/                          # PySpark / Delta Lake notebooks
├── postgres_config/
│   └── init_postgres_dbt.sql           # Database initialization
├── .github/workflows/ci.yml            # CI pipeline
├── docker-compose.yml
└── .env                                # Local config (not versioned)
```

---

## CI/CD

GitHub Actions runs on every Pull Request to `main`:

| Job | Validates |
|---|---|
| `lint_yaml_and_compose` | `docker-compose.yml` is valid |
| `airflow_dag_validation` | All DAG files are valid Python |
| `dbt_checks` | `dbt parse` — model syntax and inter-model references |
| `dbt_smoke_dev` | `dbt compile` — full SQL rendering without source data |
