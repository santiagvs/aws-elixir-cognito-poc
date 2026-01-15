# Cognito PoC

Prova de conceito para autenticação com AWS Cognito usando Elixir.

## Pré-requisitos

- Elixir/OTP instalado (versão do Elixir utilizada é 1.19.4 com o Erlang 28.3)
- Docker e Docker Compose
- k6 (para testes de carga)

## Configuração rápida

```bash
# 1) Copie variáveis de ambiente
cp .env.sample .env

# 2) Suba o Cognito local
docker compose up -d cognito-local

# 3) Instale dependências
mix deps.get
```

## Como rodar o servidor Elixir

```bash
mix run --no-halt
```

## Testes automatizados (Elixir)

```bash
mix test
```

## Testes de carga com k6

Com o servidor Elixir rodando:

```bash
k6 run k6_load_test.js
```

Relatórios são salvos em `test_results/` (JSON, MD e HTML).

## Limpeza

```bash
docker compose down
rm -rf _build deps
```