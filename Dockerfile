# Extend from the official Elixir image.
FROM elixir:latest

# Install debian packages
RUN apt-get update -qq
RUN apt-get install -y inotify-tools postgresql-client ffmpeg 

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install nodejs
RUN npm install -g yarn

# Install Phoenix packages
RUN mix local.hex --force
RUN mix local.rebar --force

# Create app directory and copy the Elixir projects into it.
WORKDIR /app
COPY . ./

# Needs permissions to be updated AFTER the copy step
RUN chmod +x ./docker-run.sh

# # Compile the project.
EXPOSE 4008
