# pgAdmin Setup Guide

## Accessing pgAdmin

1. Start the services:
   ```bash
   docker-compose up -d
   ```

2. Open pgAdmin in your browser:
   - URL: http://localhost:5050
   - Email: `admin@admin.com`
   - Password: `admin`

## Adding Database Connections

### 1. DBT Database (PostgreSQL for dbt models)

Right-click on "Servers" → "Register" → "Server"

**General Tab:**
- Name: `DBT Database` (or any name you prefer)

**Connection Tab:**
- Host name/address: `postgres-dbt`
- Port: `5432`
- Maintenance database: `dbt_db`
- Username: `dbt`
- Password: `dbt`
- ☑ Save password

**Click "Save"**

**Available Databases:**
- `data_lake` - Raw data landing zone
- `dev` - Development environment
- `pro` - Production environment
- `dbt_db` - Default database

### 2. Airflow Database (PostgreSQL for Airflow metadata)

Right-click on "Servers" → "Register" → "Server"

**General Tab:**
- Name: `Airflow Database` (or any name you prefer)

**Connection Tab:**
- Host name/address: `postgres-airflow`
- Port: `5432`
- Maintenance database: `airflow_db`
- Username: `airflow`
- Password: `airflow`
- ☑ Save password

**Click "Save"**

## Exploring Your dbt Models

Once connected to the DBT Database, you can explore:

1. **data_lake database:**
   - `forex.customer_transactions` - Raw transaction data

2. **dev database:**
   - `dev.bronze.*` - Bronze layer models (views)
   - `dev.silver.*` - Silver layer models (tables)
   - `dev.gold.*` - Gold layer models (tables)
   - `dev.data_marts.*` - Data mart views

3. **pro database:**
   - `pro.bronze.*` - Bronze layer models (views)
   - `pro.silver.*` - Silver layer models (tables)
   - `pro.gold.*` - Gold layer models (tables)
   - `pro.data_marts.*` - Data mart views

## Tips

- Use the Query Tool (right-click on database → Query Tool) to run SQL queries
- Browse tables and views to see your dbt model structures
- Check indexes and constraints to understand your data model
- Use the ERD tool to visualize relationships between tables
