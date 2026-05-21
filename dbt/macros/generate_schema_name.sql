-- Overrides dbt's default schema naming so models always land in the layer
-- directory name (bronze, silver, gold, data_marts). The database itself
-- (dev vs pro) provides environment separation — no prefix needed.

{% macro generate_schema_name(custom_schema_name, node) %}
  {% set node_path = node.path %}
  {% set path_parts = node_path.split('/') %}
  {{ path_parts[0] | trim }}
{% endmacro %}