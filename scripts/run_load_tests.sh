#!/bin/bash

echo "🧪 Preparando ambiente de testes..."

# Criar diretório de resultados
mkdir -p test_results

# Verificar se os serviços estão rodando
echo "🔍 Verificando serviços..."

if ! curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "❌ Serviço Elixir não está rodando em http://localhost:4000"
    exit 1
fi

if ! curl -s http://localhost:8000 > /dev/null 2>&1; then
    echo "❌ Serviço Python não está rodando em http://localhost:8000"
    exit 1
fi

echo "✅ Ambos os serviços estão rodando"
echo ""
echo "🚀 Iniciando testes de carga..."
echo ""

# Executar K6
k6 run k6_load_test.js

# Verificar resultado
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Testes concluídos com sucesso!"
    echo "📁 Resultados salvos em: test_results/"
    echo ""
    echo "Arquivos gerados:"
    ls -lh test_results/ | tail -n +2
else
    echo ""
    echo "❌ Testes falharam!"
    exit 1
fi