defmodule CognitoPocWeb.Router do
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  alias CognitoPoc.Cognito

  post "/login" do
    %{"username" => username, "password" => password} = conn.body_params

    case Cognito.lazy_login(username, password) do
      {:ok, tokens} ->
        send_json(conn, 200, %{tokens: tokens})

      {:error, reason} ->
        send_json(conn, 401, %{error: reason})
    end
  end

  post "/forgot-password" do
    {:ok, _body, conn} = Plug.Conn.read_body(conn)
    send_resp(conn, 501, "Password reset functionality not yet implemented")
  end

  post "/disable-user" do
    %{"username" => username} = conn.body_params

    case Cognito.deactivate_user(username) do
      {:ok, message} ->
        send_json(conn, 200, %{message: message})

      {:error, reason} ->
        send_json(conn, 500, %{error: reason})
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  # defp verify_jwt(conn) do
  #   case get_req_header(conn, "authorization") do
  #     ["Bearer " <> token] ->
  #       {:ok, %{"sub" => "user_id"}}

  #     _ ->
  #       :error
  #   end
  # end
end
