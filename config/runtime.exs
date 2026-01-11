import Config

config :cognito_poc, :cognito,
  user_pool_id: System.fetch_env!("COGNITO_USER_POOL_ID"),
  client_id: System.fetch_env!("COGNITO_CLIENT_ID"),
  client_secret: System.fetch_env!("COGNITO_CLIENT_SECRET"),
  region: System.fetch_env!("AWS_REGION"),
  oauth_urls: %{
    authorize: System.fetch_env!("COGNITO_AUTHORIZE_URL"),
    token: System.fetch_env!("COGNITO_TOKEN_URL"),
    user_info: System.fetch_env!("COGNITO_USER_INFO_URL")
  }

config :aws,
  access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
  region: System.fetch_env!("AWS_REGION"),
  endpoint: System.get_env("AWS_ENDPOINT_URL")
