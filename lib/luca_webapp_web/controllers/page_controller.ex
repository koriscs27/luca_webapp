defmodule LucaWebappWeb.PageController do
  use LucaWebappWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
