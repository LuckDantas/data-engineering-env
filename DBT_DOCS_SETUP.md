# dbt Docs - Interface Interativa

## O que é o dbt Docs?

O dbt Docs é uma interface web interativa que fornece:
- **Linha de dados (Lineage)**: Visualização gráfica das dependências entre modelos
- **Documentação**: Descrição detalhada de cada modelo, coluna e teste
- **Navegação**: Exploração fácil da estrutura do seu projeto dbt
- **Resultados de testes**: Visualização dos resultados dos testes de qualidade de dados

## Como Acessar

1. **Inicie o serviço dbt-docs:**
   ```bash
   docker-compose up -d dbt-docs
   ```

2. **Acesse a interface:**
   - URL: http://localhost:8081
   - A interface abrirá automaticamente no seu navegador

## Funcionalidades

### 1. Visualização de Linhagem (Lineage)
- Clique em qualquer modelo para ver suas dependências
- Visualize o fluxo completo de dados desde o bronze até os data marts
- Identifique rapidamente modelos upstream e downstream

### 2. Documentação dos Modelos
- Veja a descrição de cada modelo
- Explore as colunas e seus tipos
- Entenda as transformações aplicadas

### 3. Resultados de Testes
- Visualize quais testes passaram ou falharam
- Identifique problemas de qualidade de dados
- Monitore a integridade dos seus dados

### 4. Busca
- Use a barra de busca para encontrar modelos rapidamente
- Filtre por camada (bronze, silver, gold, data_marts)

## Atualizando a Documentação

A documentação é gerada automaticamente quando o container inicia. Para atualizar:

```bash
# Reinicie o serviço para regenerar os docs
docker-compose restart dbt-docs

# Ou force uma reconstrução
docker-compose up -d --force-recreate dbt-docs
```

## Estrutura do Projeto no dbt Docs

Você verá a seguinte estrutura:

```
📁 Bronze (Views)
  └── olist_orders
  └── olist_customers
  └── olist_products
  └── olist_sellers
  └── olist_order_items
  └── olist_order_payments
  └── olist_order_reviews
  └── olist_geolocation
  └── olist_category_translation

📁 Silver (Tables)
  └── stg_olist_orders
  └── stg_olist_customers
  └── stg_olist_products
  └── stg_olist_sellers
  └── stg_olist_order_items

📁 Gold (Tables)
  └── fct_pedidos
  └── dim_clientes_olist
  └── dim_produtos_olist
  └── dim_vendedores_olist
  └── date_dim

📁 Data Marts (Views)
  └── agg_olist_vendas_mensais
  └── agg_olist_vendas_por_estado
  └── agg_olist_vendas_por_categoria
  └── agg_olist_satisfacao_vendedor
```

## Dicas

- **Atalhos de teclado**: Use `Ctrl+F` (ou `Cmd+F` no Mac) para buscar modelos
- **Zoom**: Use a roda do mouse para dar zoom no gráfico de linhagem
- **Navegação**: Clique nos nós do gráfico para navegar entre modelos relacionados
- **Refresh**: A página atualiza automaticamente quando novos modelos são adicionados

## Troubleshooting

### O dbt docs não está acessível
```bash
# Verifique se o container está rodando
docker-compose ps dbt-docs

# Veja os logs para identificar problemas
docker-compose logs dbt-docs
```

### A documentação está desatualizada
```bash
# Force a regeneração dos docs
docker-compose restart dbt-docs
```

### Erro ao gerar documentação
- Certifique-se de que o banco de dados está acessível
- Verifique se os modelos dbt estão corretos
- Veja os logs: `docker-compose logs dbt-docs`
