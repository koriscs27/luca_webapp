@echo off
setlocal EnableDelayedExpansion

if not exist "secrets" (
  mkdir secrets
)

if not exist "secrets\\postgres_password" (
  echo secrets\postgres_password not found. Creating a default password.
  echo postgres> secrets\postgres_password
  echo Please change secrets\postgres_password for anything beyond local dev.
)

echo Starting Postgres with Docker...
docker compose up -d
if %errorlevel% neq 0 exit /b 1

echo Waiting for Postgres to be ready...
set /a tries=0
:pg_wait
set /a tries+=1
docker compose exec -T postgres pg_isready -U %POSTGRES_USER% -d %POSTGRES_DB% >nul 2>&1
if %errorlevel% neq 0 (
  if %tries% GEQ 30 (
    echo Postgres did not become ready in time.
    exit /b 1
  )
  timeout /t 2 /nobreak >nul
  goto pg_wait
)

echo Preparing database...
echo Installing dependencies in Docker...
docker compose run --rm app mix deps.get
if %errorlevel% neq 0 exit /b 1

docker compose run --rm app mix ecto.create
if %errorlevel% neq 0 exit /b 1
docker compose run --rm app mix ecto.migrate
if %errorlevel% neq 0 exit /b 1

echo Starting Phoenix in Docker...
docker compose up --build app
