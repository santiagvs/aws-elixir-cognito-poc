#!/bin/bash

echo "🔄 Configurando Cognito Local..."

COGNITO_ENDPOINT="http://localhost:9229"

# Verificar se o cognito-local está rodando
if ! curl -s "$COGNITO_ENDPOINT/" > /dev/null 2>&1; then
  echo "❌ Cognito Local não está rodando!"
  echo "Execute: docker compose up -d"
  exit 1
fi

echo "1. Criando User Pool..."
USER_POOL_RESPONSE=$(curl -s -X POST "$COGNITO_ENDPOINT/" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.CreateUserPool" \
  -d '{
    "PoolName": "TestPoolLocal",
    "AutoVerifiedAttributes": ["email"],
    "UsernameAttributes": ["email"]
  }')

USER_POOL_ID=$(echo "$USER_POOL_RESPONSE" | jq -r '.UserPool.Id')

if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "null" ]; then
  echo "❌ Erro ao criar User Pool"
  echo "$USER_POOL_RESPONSE"
  exit 1
fi

echo "✅ User Pool ID: $USER_POOL_ID"

echo "2. Criando App Client..."
CLIENT_RESPONSE=$(curl -s -X POST "$COGNITO_ENDPOINT/" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.CreateUserPoolClient" \
  -d "{
    \"UserPoolId\": \"$USER_POOL_ID\",
    \"ClientName\": \"TestClientLocal\",
    \"ExplicitAuthFlows\": [\"USER_PASSWORD_AUTH\", \"ADMIN_NO_SRP_AUTH\"],
    \"GenerateSecret\": true
  }")

CLIENT_ID=$(echo "$CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientId')
CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientSecret')

if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "null" ]; then
  echo "❌ Erro ao criar App Client"
  echo "$CLIENT_RESPONSE"
  exit 1
fi

echo "✅ Client ID: $CLIENT_ID"
echo "✅ Client Secret: $CLIENT_SECRET"

echo "3. Criando usuário de teste..."
curl -s -X POST "$COGNITO_ENDPOINT/" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.AdminCreateUser" \
  -d "{
    \"UserPoolId\": \"$USER_POOL_ID\",
    \"Username\": \"migrated@test.com\",
    \"TemporaryPassword\": \"TempPass123!\",
    \"MessageAction\": \"SUPPRESS\"
  }" > /dev/null

curl -s -X POST "$COGNITO_ENDPOINT/" \
  -H "Content-Type: application/x-amz-json-1.1" \
  -H "X-Amz-Target: AWSCognitoIdentityProviderService.AdminSetUserPassword" \
  -d "{
    \"UserPoolId\": \"$USER_POOL_ID\",
    \"Username\": \"migrated@test.com\",
    \"Password\": \"MigratedPass123!\",
    \"Permanent\": true
  }" > /dev/null

echo "✅ Usuário 'migrated@test.com' criado"

echo ""
echo "4. Salvando configurações em .env..."
cat > .env << EOF
# Configurações AWS para Cognito Local
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_ENDPOINT_URL=http://localhost:9229

# Configurações Cognito
export COGNITO_USER_POOL_ID=$USER_POOL_ID
export COGNITO_CLIENT_ID=$CLIENT_ID
export COGNITO_CLIENT_SECRET=$CLIENT_SECRET

# URLs
export COGNITO_AUTHORIZE_URL=http://localhost:9229/oauth2/authorize
export COGNITO_TOKEN_URL=http://localhost:9229/oauth2/token
export COGNITO_USER_INFO_URL=http://localhost:9229/oauth2/userInfo

# Mock do sistema legado
export LEGACY_API_URL=http://localhost:8001/login_endpoint.php
EOF

echo "✅ Setup concluído!"
echo ""
echo "📋 Credenciais salvas em .env"
echo ""
echo "🚀 Para usar:"
echo "   source .env"
echo ""
echo "📝 Credenciais:"
echo "   User Pool ID: $USER_POOL_ID"
echo "   Client ID: $CLIENT_ID"
echo "   Client Secret: $CLIENT_SECRET"