#!/bin/sh

set -e

# Ensure the app's deps are installed
mix deps.get

# Install JS deps
echo "\nInstalling JS..."
cd assets && yarn install
cd ..

# Potentially Set up the database
mix ecto.create
mix ecto.migrate

# Start the phoenix web server (interactive)
echo "\n Launching Phoenix web server..."
iex -S mix phx.server
