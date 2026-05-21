from __future__ import annotations

# Standard library imports — available in all Python environments
import logging
import os
import shutil
import subprocess
import sys

# Airflow imports
from airflow.decorators import dag, task          # TaskFlow API — modern way to write DAGs
from airflow.models import Variable               # Airflow Variables: key-value store in the UI (Admin → Variables)
from airflow.models.param import Param            # Param: defines typed, documented trigger parameters shown in the UI
from airflow.providers.ssh.operators.ssh import SSHOperator  # Runs commands on a remote host via SSH
from airflow.hooks.base_hook import BaseHook      # Used to retrieve connection details stored in Airflow Connections
from pendulum import datetime as pendulum_datetime # Airflow's preferred datetime library (timezone-aware)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants — defined at module level so the Airflow scheduler can read them
# without executing any task logic. The scheduler parses all DAG files every
# ~30 seconds to detect changes, so top-level code must be lightweight and
# side-effect free (no DB calls, no API calls here).
# ---------------------------------------------------------------------------

# Path inside the Airflow worker container where CSVs will be stored.
# This maps to ./data/olist/raw/ on the host machine via the docker-compose
# volume mount: ./data:/opt/airflow/data
RAW_DIR = "/opt/airflow/data/olist/raw"

KAGGLE_DATASET = "olistbr/brazilian-ecommerce"

# List of all Olist CSV files and their target PostgreSQL table names.
# Used by Dynamic Task Mapping to create one parallel task per table.
TABLES = [
    {"csv": "olist_orders_dataset.csv",               "table": "orders"},
    {"csv": "olist_order_items_dataset.csv",           "table": "order_items"},
    {"csv": "olist_customers_dataset.csv",             "table": "customers"},
    {"csv": "olist_sellers_dataset.csv",               "table": "sellers"},
    {"csv": "olist_products_dataset.csv",              "table": "products"},
    {"csv": "olist_order_reviews_dataset.csv",         "table": "order_reviews"},
    {"csv": "olist_order_payments_dataset.csv",        "table": "order_payments"},
    {"csv": "olist_geolocation_dataset.csv",           "table": "geolocation"},
    {"csv": "product_category_name_translation.csv",  "table": "category_translation"},
]


# ---------------------------------------------------------------------------
# DAG definition
# The @dag decorator turns this function into an Airflow DAG.
# DAG naming convention used in this project: DOMAIN__PIPELINE__SCHEDULE
# ---------------------------------------------------------------------------
@dag(
    dag_id="OLIST__INGESTION__ONCE",
    description="Full Olist pipeline: Kaggle download → PostgreSQL Bronze → dbt Star Schema.",
    tags=["olist", "kaggle", "ingestion", "dbt"],
    start_date=pendulum_datetime(2025, 1, 1),
    # schedule_interval=None means this DAG only runs when triggered manually.
    # For a one-time historical load this is correct — no need for a schedule.
    schedule_interval=None,
    # catchup=False prevents Airflow from running historical DAG runs between
    # start_date and today when the DAG is first activated.
    catchup=False,
    default_args={"retries": 1},
    # Params define the trigger form shown in the Airflow UI when you click
    # "Trigger DAG". Each Param renders as a typed input field or dropdown.
    params={
        "target": Param(
            default="dev",
            enum=["dev", "pro"],
            description="dbt target environment: 'dev' for development, 'pro' for production.",
        )
    },
)
def olist_pipeline():

    # -------------------------------------------------------------------------
    # TASK 1: download_dataset
    # Downloads the Olist dataset from Kaggle using the kagglehub library.
    #
    # Why install kagglehub inside the task instead of pre-installing it?
    #   The Airflow image (apache/airflow:2.7.2) doesn't have kagglehub.
    #   Adding _PIP_ADDITIONAL_REQUIREMENTS to docker-compose conflicts with
    #   user: root in this setup (causes restart loops). Installing at task
    #   runtime via subprocess is the pragmatic workaround for a dev environment.
    #   In production you would build a custom Docker image with the package.
    # -------------------------------------------------------------------------
    @task
    def download_dataset() -> str:
        # Install kagglehub in the worker container at runtime
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "kagglehub", "--quiet"],
            check=True,
        )
        import kagglehub

        # Kaggle API credentials stored as Airflow Variables.
        os.environ["KAGGLE_API_TOKEN"] = Variable.get("kaggle_api_token")

        logger.info("Downloading: %s", KAGGLE_DATASET) # Log the dataset name for visibility in Airflow logs
        # kagglehub downloads to a local cache (~/.cache/kagglehub/...) and
        # returns the path to the downloaded files
        cached_path = kagglehub.dataset_download(KAGGLE_DATASET)
        logger.info("Cached at: %s", cached_path)

        # Copy CSVs from kagglehub cache to the shared data volume so all
        # Airflow workers and Jupyter can access them at the same path
        os.makedirs(RAW_DIR, exist_ok=True)
        for fname in os.listdir(cached_path):
            if fname.endswith(".csv"):
                shutil.copy2(os.path.join(cached_path, fname), os.path.join(RAW_DIR, fname))
                logger.info("Copied: %s", fname)

        # Returning RAW_DIR allows the next task to know where to find the files.
        return RAW_DIR

    # -------------------------------------------------------------------------
    # TASK 2: create_schema
    # Creates the olist schema in the data_lake PostgreSQL database (data_lake instace).
    # -------------------------------------------------------------------------
    @task
    def create_schema(raw_dir: str) -> str:
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        hook = PostgresHook(postgres_conn_id="postgres_dbt_conn")
        hook.run("CREATE SCHEMA IF NOT EXISTS olist;")
        logger.info("Schema olist created (or already exists)")
        # Pass raw_dir through so the next task knows the file location
        return raw_dir

    # -------------------------------------------------------------------------
    # TASK 3: load_table (Dynamic Task Mapping)
    # Loads one CSV file into one PostgreSQL table (data_lake).
    #
    # Dynamic Task Mapping: instead of writing 9 separate tasks, we define
    # the logic once and use .partial().expand() to generate one task instance
    # per table at runtime. In the Airflow UI you will see:
    #   load_table[0] → loads orders
    #   load_table[1] → loads order_items
    #   ... (all 9 run in parallel)
    #
    # .partial(raw_dir=ready): fixed argument — same for all instances
    # .expand(table_config=TABLES): varying argument — different per instance
    # -------------------------------------------------------------------------
    @task
    def load_table(table_config: dict, raw_dir: str) -> str:
        import pandas as pd
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        csv_path = os.path.join(raw_dir, table_config["csv"])
        table_name = table_config["table"]

        # dtype=str: read ALL columns as strings (VARCHAR).
        # This is the Bronze philosophy — accept data exactly as-is without
        # making type assumptions. Type casting happens in dbt Silver models.
        df = pd.read_csv(csv_path, dtype=str)
        # Normalize column names: strip whitespace and lowercase
        df.columns = [c.strip().lower() for c in df.columns]

        hook = PostgresHook(postgres_conn_id="postgres_dbt_conn")
        # get_sqlalchemy_engine() returns a SQLAlchemy engine, required by
        # pandas to_sql() for writing DataFrames to a database
        engine = hook.get_sqlalchemy_engine()

        df.to_sql(
            table_name,
            engine,
            schema="olist",
            # if_exists="replace": drops and recreates the table on each run.
            # Safe for a one-time historical load. For incremental loads you
            # would use "append" or implement MERGE logic (like the forex DAG).
            if_exists="replace",
            index=False,    # don't write the DataFrame index as a column
            method="multi", # insert multiple rows per statement (faster than one-by-one)
            chunksize=2000, # commit every 2000 rows to avoid memory issues on large CSVs
        )
        logger.info("Loaded %d rows into olist.%s", len(df), table_name)
        return f"olist.{table_name}"

    # -------------------------------------------------------------------------
    # TASK 4: transform_dbt (SSHOperator)
    # Runs dbt build on the dbt container via SSH.
    #
    # Why SSHOperator instead of a PythonOperator?
    #   dbt is installed in a separate container (ghcr.io/dbt-labs/dbt-postgres).
    #   Airflow workers don't have dbt installed. SSHOperator lets Airflow
    #   remotely execute a shell command on the dbt container.
    #
    # The SSH connection works because:
    #   - The dbt container runs an SSH server (configured in docker-compose)
    #   - The SSH private key is shared via a Docker volume (dbt_ssh_keys)
    #     mounted in both the dbt container and Airflow containers
    #   - dbt_conn is an Airflow SSH Connection storing the host/port/key path
    #
    # dbt_conn_extra: the "extra" JSON field of the dbt_conn Connection.
    #   It contains environment variables (POSTGRES_USER, POSTGRES_PASSWORD, etc.)
    #   that must be passed to the remote SSH session because the dbt container's
    #   non-interactive shell doesn't source environment variables automatically.
    #
    # --select tag:olist: runs only models tagged with 'olist' (set in
    #   dbt_project.yml), skipping unrelated models like the forex pipeline.
    # -------------------------------------------------------------------------
    dbt_conn_extra = {}
    try:
        dbt_conn_extra = BaseHook.get_connection("dbt_conn").extra_dejson
    except Exception:
        # If dbt_conn is not configured, the DAG still loads without crashing.
        # The transform task will fail at runtime with a clear error message.
        pass

    transform = SSHOperator(
        task_id="transform_dbt",
        ssh_conn_id="dbt_conn",
        command="cd /usr/app && dbt deps && dbt build --select tag:olist --target {{ dag_run.conf.get('target', 'dev') }}",
        environment=dbt_conn_extra,
        cmd_timeout=600,  # 10 minutes — dbt build can be slow on first run
    )

    # -------------------------------------------------------------------------
    # Task dependency chain:
    # The >> operator sets dependencies: A >> B means "B runs after A".
    # Dynamic Task Mapping automatically makes transform_dbt wait for all
    # 9 load_table instances to complete before running.
    # -------------------------------------------------------------------------
    raw_dir = download_dataset()
    ready = create_schema(raw_dir)
    loaded = load_table.partial(raw_dir=ready).expand(table_config=TABLES)
    loaded >> transform


olist_pipeline()
