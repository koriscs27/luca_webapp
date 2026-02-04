If `secrets/postgres_password` does not exist, `start-dev.bat` will create it with a default value.
For any non-local usage, replace it with a strong password on a single line.

Example:

postgres

For production container runs (`docker compose --profile prod ...`), also create:

- `secrets/secret_key_base`

Generate it with:

mix phx.gen.secret
