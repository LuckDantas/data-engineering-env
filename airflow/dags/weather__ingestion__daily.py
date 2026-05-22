from __future__ import annotations

import json
import logging
import os

import requests
from airflow.models.param import Param            # Param: defines typed, documented trigger parameters shown in the UI
from airflow.decorators import dag, task
from airflow.hooks.base_hook import BaseHook
from airflow.providers.ssh.operators.ssh import SSHOperator
from pendulum import datetime as pendulum_datetime

logger = logging.getLogger(__name__)

RAW_DIR = "/opt/airflow/data/weather/raw"

CITIES = [
    {"city": "São Paulo",      "lat": -23.55, "lon": -46.63, "timezone": "America/Sao_Paulo"},
    {"city": "Rio de Janeiro", "lat": -22.91, "lon": -43.17, "timezone": "America/Sao_Paulo"},
    {"city": "Belo Horizonte", "lat": -19.92, "lon": -43.94, "timezone": "America/Sao_Paulo"},
    {"city": "Curitiba",       "lat": -25.43, "lon": -49.27, "timezone": "America/Sao_Paulo"},
    {"city": "Porto Alegre",   "lat": -30.03, "lon": -51.23, "timezone": "America/Sao_Paulo"},
    {"city": "Fortaleza",      "lat":  -3.72, "lon": -38.54, "timezone": "America/Fortaleza"},
    {"city": "Salvador",       "lat": -12.97, "lon": -38.50, "timezone": "America/Bahia"},
    {"city": "Manaus",         "lat":  -3.10, "lon": -60.02, "timezone": "America/Manaus"},
    {"city": "Recife",         "lat":  -8.05, "lon": -34.88, "timezone": "America/Recife"},
    {"city": "Brasília",       "lat": -15.78, "lon": -47.93, "timezone": "America/Sao_Paulo"},
]

DAILY_VARS = [
    "temperature_2m_max",
    "temperature_2m_min",
    "precipitation_sum",
    "wind_speed_10m_max",
    "sunrise",
    "sunset",
]


@dag(
    dag_id="WEATHER__INGESTION__DAILY",
    description="Fetches daily weather for 10 Brazilian cities from Open-Meteo → PostgreSQL → dbt Star Schema.",
    tags=["weather", "open-meteo", "ingestion", "dbt"],
    start_date=pendulum_datetime(2025, 1, 1),
    schedule_interval="@daily",
    catchup=False,
    default_args={"retries": 2},
    params={
        "target": Param(
            default="pro",
            enum=["dev", "pro"],
            description="dbt target environment: 'dev' for development, 'pro' for production.",
        )
    },
)
def weather_pipeline():

    # -------------------------------------------------------------------------
    # TASK 1: fetch_weather
    # Calls Open-Meteo (no API key required) and saves one JSON file per day
    # -------------------------------------------------------------------------
    @task
    def fetch_weather(data_interval_end=None) -> str:
        from datetime import date, timezone
        if data_interval_end is not None:
            target_date = data_interval_end.astimezone(timezone.utc).strftime("%Y-%m-%d")
        else:
            target_date = date.today().strftime("%Y-%m-%d")

        os.makedirs(RAW_DIR, exist_ok=True)

        records = []
        for city in CITIES:
            params = {
                "latitude": city["lat"],
                "longitude": city["lon"],
                "daily": ",".join(DAILY_VARS), # Open-Meteo expects a comma-separated string for list parameters
                "timezone": city["timezone"],
                "start_date": target_date,
                "end_date": target_date,
            }
            resp = requests.get(
                "https://api.open-meteo.com/v1/forecast",
                params=params,
                timeout=10,
            )
            resp.raise_for_status()
            data = resp.json()

            daily = data.get("daily", {})
            record = {"city": city["city"], "lat": city["lat"], "lon": city["lon"], "date": target_date}
            for var in DAILY_VARS:
                values = daily.get(var, [None])
                record[var] = values[0] if values else None

            records.append(record)
            logger.info("Fetched %s for %s", city["city"], target_date)

        out_path = os.path.join(RAW_DIR, f"{target_date}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(records, f, indent=2, ensure_ascii=False)

        logger.info("Saved %d records → %s", len(records), out_path)
        return out_path

    # -------------------------------------------------------------------------
    # TASK 2: create_schema
    # Ensures the weather schema and landing table exist in data_lake before
    # any data is written.
    # -------------------------------------------------------------------------
    @task
    def create_schema(json_path: str) -> str:
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        hook = PostgresHook(postgres_conn_id="postgres_dbt_conn")
        hook.run("""
            CREATE SCHEMA IF NOT EXISTS weather;
            CREATE TABLE IF NOT EXISTS weather.daily_forecast (
                city               VARCHAR,
                lat                DOUBLE PRECISION,
                lon                DOUBLE PRECISION,
                date               VARCHAR,
                temperature_2m_max REAL,
                temperature_2m_min REAL,
                precipitation_sum  REAL,
                wind_speed_10m_max REAL,
                sunrise            VARCHAR,
                sunset             VARCHAR,
                loaded_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        return json_path

    # -------------------------------------------------------------------------
    # TASK 3: load_postgres
    # Reads the JSON file and upserts into data_lake.weather.daily_forecast.
    # DELETE + INSERT is the simplest idempotent pattern for a single date:
    # re-running the DAG for the same date overwrites the existing rows cleanly.
    # -------------------------------------------------------------------------
    @task
    def load_postgres(json_path: str) -> str:
        import pandas as pd
        from sqlalchemy import create_engine, text
        from airflow.providers.postgres.hooks.postgres import PostgresHook

        hook = PostgresHook(postgres_conn_id="postgres_dbt_conn")
        conn_uri = hook.get_uri()
        engine = create_engine(conn_uri)

        with open(json_path, encoding="utf-8") as f:
            records = json.load(f)

        df = pd.DataFrame(records)
        target_date = df["date"].iloc[0]

        # DELETE + INSERT in a single transaction — if the insert fails,
        # the delete is rolled back automatically and no data is lost.
        with engine.begin() as conn:
            conn.execute(
                text("DELETE FROM weather.daily_forecast WHERE date = :d"),
                {"d": target_date},
            )
            df.to_sql(
                "daily_forecast",
                conn,
                schema="weather",
                if_exists="append",
                index=False,
                method="multi",
            )
        logger.info("Loaded %d rows into weather.daily_forecast (date=%s)", len(df), target_date)
        return target_date

    # -------------------------------------------------------------------------
    # TASK 3: transform_dbt (SSHOperator)
    # Runs dbt build for weather models only (tag:weather).
    # Silver uses an incremental model — only the new date is processed.
    # -------------------------------------------------------------------------
    dbt_conn_extra = {}
    try:
        dbt_conn_extra = BaseHook.get_connection("dbt_conn").extra_dejson
    except Exception:
        pass

    transform_dbt = SSHOperator(
        task_id="transform_dbt",
        ssh_conn_id="dbt_conn",
        command="cd /usr/app && dbt deps && dbt build --select tag:weather --target {{ dag_run.conf.get('target', 'dev') }}",
        environment=dbt_conn_extra,
        cmd_timeout=300,
    )

    json_path  = fetch_weather()
    ready      = create_schema(json_path)
    loaded     = load_postgres(ready)
    loaded >> transform_dbt


weather_pipeline()
