from __future__ import annotations

import logging
import os
import shutil
import subprocess
import sys

from airflow.decorators import dag, task
from airflow.models import Variable
from pendulum import datetime as pendulum_datetime

logger = logging.getLogger(__name__)

DEST_DIR = "/opt/airflow/data/olist/raw"
KAGGLE_DATASET = "olistbr/brazilian-ecommerce"


@dag(
    dag_id="OLIST__DOWNLOAD__ONCE",
    description="Baixa o dataset Olist do Kaggle via kagglehub e salva em /data/olist/raw/.",
    tags=["olist", "kaggle", "download"],
    start_date=pendulum_datetime(2025, 1, 1),
    schedule_interval=None,  # Trigger manual — rodar apenas uma vez
    catchup=False,
)
def olist_download():

    @task
    def download_dataset() -> str:
        """
        Installs kagglehub, authenticates via Airflow Variables, downloads the Olist
        dataset and copies the CSV files to the shared data directory.

        Airflow Variables required:
          - kaggle_api_token  (token shown on kaggle.com → Settings → API)
        """
        # Install kagglehub in the worker (not pre-installed in the base image)
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "kagglehub", "--quiet"],
            check=True,
        )
        import kagglehub  # noqa: PLC0415

        # Inject credentials — new Kaggle single-token format
        os.environ["KAGGLE_API_TOKEN"] = Variable.get("kaggle_api_token")

        logger.info("Iniciando download: %s", KAGGLE_DATASET)
        cached_path = kagglehub.dataset_download(KAGGLE_DATASET)
        logger.info("Download concluído em: %s", cached_path)

        # Copy CSVs from kagglehub cache to the shared data volume
        os.makedirs(DEST_DIR, exist_ok=True)
        copied = []
        for fname in os.listdir(cached_path):
            if fname.endswith(".csv"):
                src = os.path.join(cached_path, fname)
                dst = os.path.join(DEST_DIR, fname)
                shutil.copy2(src, dst)
                copied.append(fname)
                logger.info("Copiado: %s → %s", fname, dst)

        logger.info("Total de arquivos copiados: %d", len(copied))
        return DEST_DIR

    @task
    def list_files(raw_dir: str) -> list[str]:
        """Lists the downloaded CSV files for verification."""
        files = sorted(f for f in os.listdir(raw_dir) if f.endswith(".csv"))
        for f in files:
            size_mb = os.path.getsize(os.path.join(raw_dir, f)) / 1_048_576
            logger.info("  %-55s %.1f MB", f, size_mb)
        return files

    raw_dir = download_dataset()
    list_files(raw_dir)


olist_download()
