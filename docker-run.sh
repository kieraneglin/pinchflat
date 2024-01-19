#!/bin/sh

set -e

# Ensure the app's deps are installed
mix deps.get

# Install JS deps
echo "\nInstalling JS..."
cd assets && yarn install
cd ..

# Wait for Postgres to become available.
export PGPASSWORD=$(echo $POSTGRES_PASSWORD)
until psql -h postgres -U $POSTGRES_USER -c '\q' 2>/dev/null; do
  echo >&2 "Postgres is unavailable - sleeping"
  sleep 1
done

echo "\nPostgres is available: continuing with database setup..."

# Potentially Set up the database
mix ecto.create
mix ecto.migrate

# Start the phoenix web server
echo "\n Launching Phoenix web server..."
mix phx.server
