defmodule CognitoPoc.Cognito do
  @moduledoc """
  Módulo para interagir com o AWS Cognito
  """

  require Logger

  defp user_pool_id do
    Application.get_env(:cognito_poc, :cognito)[:user_pool_id] ||
      raise "COGNITO_USER_POOL_ID não configurado"
  end

  defp client_id do
    Application.get_env(:cognito_poc, :cognito)[:client_id] ||
      raise "COGNITO_CLIENT_ID não configurado"
  end

  defp client_secret do
    Application.get_env(:cognito_poc, :cognito)[:client_secret] ||
      raise "COGNITO_CLIENT_SECRET não configurado"
  end

  defp calculate_secret_hash(username) do
    message = username <> client_id()

    :crypto.mac(:hmac, :sha256, client_secret(), message)
    |> Base.encode64()
  end

  defp aws_client do
    CognitoPoc.AwsClient.get_client()
  end

  @doc """
  Lazy migration: Tenta autenticar no Cognito primeiro.
  Se o usuário não existir, valida no sistema legado e migra.
  """
  def lazy_login(email, password) do
    Logger.info("Iniciando lazy_login para: #{email}")

    case authenticate(email, password) do
      {:ok, tokens} ->
        {:ok, tokens}

      {:error, %{"__type" => "UserNotFoundException"}} ->
        migrate_user_from_legacy(email, password)

      {:error, %{"__type" => "NotAuthorizedException", "message" => _message}} ->
        if user_exists_in_cognito?(email) do
          {:error, "Credenciais inválidas"}
        else
          migrate_user_from_legacy(email, password)
        end

      {:error, reason} ->
        Logger.error("❌ Erro na autenticação: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp authenticate(username, password) do
    client = aws_client()
    secret_hash = calculate_secret_hash(username)

    request = %{
      "AuthFlow" => "USER_PASSWORD_AUTH",
      "AuthParameters" => %{
        "USERNAME" => username,
        "PASSWORD" => password,
        "SECRET_HASH" => secret_hash
      },
      "ClientId" => client_id()
    }

    case AWS.CognitoIdentityProvider.initiate_auth(client, request) do
      {:ok, %{"AuthenticationResult" => tokens}, _metadata} ->
        Logger.info("=== Autenticação bem-sucedida! ===")
        {:ok, tokens}

      {:error, {_reason, %{body: body}}} ->
        case Jason.decode(body) do
          {:ok, %{"__type" => error_type, "message" => message}} ->
            {:error, %{"__type" => error_type, "message" => message}}

          {:error, _} ->
            {:error, "Erro desconhecido: #{inspect(body)}"}
        end

      other ->
        Logger.error("Resposta inesperada: #{inspect(other)}")
        {:error, :unexpected_response}
    end
  end

  defp migrate_user_from_legacy(email, password) do
    case validate_legacy_credentials(email, password) do
      {:ok, user_attrs} ->
        with {:ok, _} <- create_user(email, password, user_attrs),
             {:ok, tokens} <- authenticate(email, password) do
          Logger.info("Migração concluída.")
          {:ok, tokens}
        else
          {:error, reason} ->
            {:error, reason}
        end

      {:error, _reason} ->
        {:error, "Credenciais inválidas"}
    end
  end

  defp user_exists_in_cognito?(username) do
    client = aws_client()

    case AWS.CognitoIdentityProvider.admin_get_user(client, %{
           "UserPoolId" => user_pool_id(),
           "Username" => username
         }) do
      {:ok, _user, _metadata} ->
        Logger.debug("✓ Usuário existe no Cognito")
        true

      {:error, {_reason, %{body: body}}} ->
        case Jason.decode(body) do
          {:ok, %{"__type" => "UserNotFoundException"}} ->
            Logger.debug("✗ Usuário não existe no Cognito")
            false

          _ ->
            Logger.debug("? Erro ao verificar existência do usuário")
            false
        end

      _ ->
        false
    end
  end

  defp validate_legacy_credentials(email, password) do
    headers = [{"Content-Type", "application/json"}]

    body = %{
      email: email,
      password: password
    }

    body_json = Jason.encode!(body)

    case :hackney.request(
           :post,
           "http://localhost:8001/login_endpoint.php",
           headers,
           body_json,
           pool: :legacy_pool
         ) do
      {:ok, 200, _headers, client_ref} ->
        case :hackney.body(client_ref) do
          {:ok, response_body} ->
            attrs = Jason.decode!(response_body)
            {:ok, attrs}

          {:error, reason} ->
            {:error, "Erro ao ler resposta: #{inspect(reason)}"}
        end

      {:ok, status, _headers, _client_ref} ->
        {:error, "Status HTTP #{status}: Credenciais inválidas no sistema legado"}

      {:error, reason} ->
        {:error, "Erro na requisição: #{inspect(reason)}"}
    end
  end

  defp create_user(username, password, user_attrs) do
    client = aws_client()

    cognito_attrs = [
      %{"Name" => "email", "Value" => username},
      %{"Name" => "email_verified", "Value" => "true"}
    ]

    cognito_attrs =
      case user_attrs do
        %{"name" => name} -> cognito_attrs ++ [%{"Name" => "name", "Value" => name}]
        _ -> cognito_attrs
      end

    case AWS.CognitoIdentityProvider.admin_create_user(client, %{
           "UserPoolId" => user_pool_id(),
           "Username" => username,
           "TemporaryPassword" => password,
           "UserAttributes" => cognito_attrs,
           "MessageAction" => "SUPPRESS"
         }) do
      {:ok, _response, _metadata} ->
        Logger.info("✅ Usuário criado, definindo senha permanente...")
        set_permanent_password(username, password)

      {:error, {_reason, %{body: body}}} ->
        case Jason.decode(body) do
          {:ok, error} ->
            Logger.error("Erro ao criar usuário: #{inspect(error)}")
            {:error, "Falha ao criar usuário: #{error["message"]}"}

          _ ->
            {:error, "Falha ao criar usuário no Cognito"}
        end

      {:error, {reason, metadata}} ->
        Logger.error("Erro ao criar usuário: #{inspect(reason)}")
        Logger.debug("Detalhe do erro:\n#{inspect(metadata)}")
        {:error, "Falha ao criar usuário no Cognito"}
    end
  end

  defp set_permanent_password(username, password) do
    client = aws_client()

    case AWS.CognitoIdentityProvider.admin_set_user_password(client, %{
           "UserPoolId" => user_pool_id(),
           "Username" => username,
           "Password" => password,
           "Permanent" => true
         }) do
      {:ok, _response, _metadata} -> {:ok, "Usuário criado com sucesso"}
      {:error, {reason, _metadata}} -> {:error, "Falha ao definir senha: #{inspect(reason)}"}
    end
  end

  @spec deactivate_user(String.t()) :: {:error, String.t()} | {:ok, String.t()}
  def deactivate_user(username) do
    client = aws_client()

    case AWS.CognitoIdentityProvider.admin_disable_user(client, %{
           "UserPoolId" => user_pool_id(),
           "Username" => username
         }) do
      {:ok, _response, _metadata} ->
        {:ok, "Usuário desabilitado com sucesso!"}

      {:error, {reason, _metadata}} ->
        {:error, "Falha ao desabilitar usuário: #{inspect(reason)}"}
    end
  end

  def forgot_password(email) do
    client = aws_client()
    secret_hash = calculate_secret_hash(email)

    case AWS.CognitoIdentityProvider.forgot_password(client, %{
           "ClientId" => client_id(),
           "Username" => email,
           "SecretHash" => secret_hash
         }) do
      {:ok, _response, _metadata} -> {:ok, "Código de recuperação enviado"}
      {:error, {reason, _metadata}} -> {:error, reason}
    end
  end
end
