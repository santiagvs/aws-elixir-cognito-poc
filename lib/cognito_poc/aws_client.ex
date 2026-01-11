defmodule CognitoPoc.AwsClient do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_client do
    GenServer.call(__MODULE__, :get_client)
  end

  @impl true
  def init(_state) do
    client = create_aws_client()
    {:ok, %{client: client}}
  end

  @impl true
  def handle_call(:get_client, _from, state) do
    {:reply, state.client, state}
  end

  defp create_aws_client do
    access_key = Application.get_env(:aws, :access_key_id)
    secret_key = Application.get_env(:aws, :secret_access_key)
    region = Application.get_env(:aws, :region)
    endpoint = Application.get_env(:aws, :endpoint)

    client = AWS.Client.create(access_key, secret_key, region)

    case endpoint do
      nil ->
        client

      url ->
        uri = URI.parse(url)

        %{client | endpoint: uri.host, port: uri.port, proto: uri.scheme}
    end
  end
end
