#!/bin/bash

if [ ! -f .env ]; then
    echo "Erro: arquivo .env não encontrado. Variáveis de ambiente estão faltando."
    exit 1
fi

source .env

mix run --no-halt