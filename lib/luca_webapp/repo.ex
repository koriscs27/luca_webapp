defmodule LucaWebapp.Repo do
  use Ecto.Repo,
    otp_app: :luca_webapp,
    adapter: Ecto.Adapters.Postgres
end
