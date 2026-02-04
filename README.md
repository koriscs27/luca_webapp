# LucaWebapp

## Local dev with Docker + Postgres

1. Ensure Docker Desktop (or Docker Engine) is running.
2. `start-dev.bat` will create `secrets\postgres_password` with a default value if it does not exist.
3. Update `secrets\postgres_password` if you want a custom DB password.
4. Run `start-dev.bat`.

This will start Postgres in Docker, install deps, create/migrate the DB, and run the Phoenix server.

## Docker-only (no local Elixir/Erlang)

The app can run fully inside Docker for both dev and prod.

### Dev (default)
Run:
```
start-dev.bat
```

### Prod-style container
Run:
```
docker compose --profile prod up --build app_prod
```

Before running in production mode, create these secret files:

1. `secrets/postgres_password`
2. `secrets/secret_key_base`

Generate a secure `SECRET_KEY_BASE` with:
```
mix phx.gen.secret
```

Then put the generated value on a single line in `secrets/secret_key_base`.

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

Test change for SSH push.
