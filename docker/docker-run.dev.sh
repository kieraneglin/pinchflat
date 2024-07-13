#!/bin/sh

set -e

echo "\nInstalling Elixir deps..."
mix deps.get

# Install both project-level and assets-level JS dependencies
echo "\nInstalling JS deps..."
yarn install && cd assets && yarn install
cd ..

# Potentially Set up the database
mix ecto.create
mix ecto.migrate

# Start the phoenix web server (interactive)
echo "\n Launching Phoenix web server..."
iex -S mix phx.server
