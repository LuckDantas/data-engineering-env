# Data Engineering Environment (Airflow + dbt + Spark + Postgres + Docker)

A containerized data platform for orchestration (Airflow), transformation (dbt), distributed processing (Spark), and persistence (Postgres). Everything is orchestrated via Docker Compose.

## Stack

- **Airflow** (2.7.2): Orchestration (Webserver, Scheduler, 3 Workers) using CeleryExecutor & Redis.
- **Spark** (PySpark): JupyterLab environment acting as a driver node for local distributed processing.
- **dbt** (Postgres): Transformation layer with Medallion architecture (bronze → silver → gold).
- **Postgres**:
  - `postgres-airflow`: Metadata for Airflow.
  - `postgres-dbt`: Data Lake storage (databases `data_lake`, `dev`, `pro`).
- **pgAdmin**: GUI for PostgreSQL management.
- **Docker Compose**: Local orchestration with Healthchecks.

## Services & Ports

| Service            | URL/Port                 | Credentials (default)          |
|--------------------|--------------------------|--------------------------------|
| **Airflow Web**    | http://localhost:8080    | `admin` / `admin`              |
| **Jupyter (Spark)**| http://localhost:8888    | Token: `spark`                 |
| **Spark UI**       | http://localhost:4040    | N/A                            |
| **pgAdmin**        | http://localhost:5050    | `admin@admin.com` / `admin`    |
| **dbt Docs**       | http://localhost:8081    | N/A                            |
| **Postgres Data**  | `localhost:5434`         | `dbt` / `dbt`                  |
| **Postgres Airflow**| `localhost:5433`        | `airflow` / `airflow`          |
| **SSH (dbt)**      | `localhost:2222`         | `root` (key volume mapped)     |

## Configuration (.env)

The project now uses a `.env` file to manage configuration. A default file is created automatically.
Key variables:
- `AIRFLOW_USER` / `AIRFLOW_PASSWORD`
- `POSTGRES_DBT_USER` / `POSTGRES_DBT_PASSWORD`
- `JUPYTER_PORT`
- `SPARK_UI_PORT`

## Quick Start

1. **Start the environment**:
   ```bash
   docker-compose up -d
   ```
   *Note: First run takes a few minutes to download images and initialize databases.*

2. **Access Services**:
   - Go to **Jupyter** (http://localhost:8888) to run Spark notebooks.
   - Go to **Airflow** (http://localhost:8080) to run DAGs.

3. **Stop the environment**:
   ```bash
   docker-compose down
   ```
   *To remove volumes adds `-v`*

## Developing with Spark

The `jupyter-spark` service provides a "Databricks-like" local notebook experience.
- **Notebooks Folder**: Mapped to `./notebooks` on your host. Work saved here is persisted.
- **Data Access**: `./data` is mapped to `/home/jovyan/data`.
- **Postgres Connection**: Spark is on the `dbt_network`, so it can reach `postgres-dbt` at hostname `postgres-dbt`.
  *(Note: You may need to add a JDBC driver jar to the spark classpath if reading from Postgres directly).*

## Project Structure

- `airflow/`: DAGs and config.
- `dbt/`: dbt project (Medallion architecture).
- `notebooks/`: Spark/Python notebooks.
- `data/`: Raw data files.
- `postgres_config/`: Init scripts for generic Postgres setup.
- `docker-compose.yml`: Service definition.
- `.env`: Environment configuration.

## CI/CD

GitHub Actions workflow (`CI`) validates:
1. Docker Compose config.
2. Airflow DAGs integrity.
3. dbt project parsing/building (smoke test).

