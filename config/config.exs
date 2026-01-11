import Config

config :cognito_poc, :cognito,
  user_pool_id: System.get_env("COGNITO_USER_POOL_ID"),
  client_id: System.get_env("COGNITO_CLIENT_ID"),
  client_secret: System.get_env("COGNITO_CLIENT_SECRET"),
  region: System.get_env("AWS_REGION")

config :aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION")

config :logger, level: :debug
