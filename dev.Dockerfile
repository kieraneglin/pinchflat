# Extend from the official Elixir image.
FROM elixir:latest

# Install debian packages
RUN apt-get update -qq
RUN apt-get install -y inotify-tools ffmpeg \
  python3 python3-pip python3-setuptools python3-wheel python3-dev

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install nodejs
RUN npm install -g yarn

# Install baseline Elixir packages
RUN mix local.hex --force
RUN mix local.rebar --force

# Download YT-DLP
# NOTE: If you're seeing weird issues, consider using the FFMPEG released by yt-dlp
RUN python3 -m pip install -U --pre yt-dlp

# Create app directory and copy the Elixir projects into it.
WORKDIR /app
COPY . ./

# Needs permissions to be updated AFTER the copy step
RUN chmod +x ./docker-run.sh

# Install Elixir deps
RUN mix deps.get
# Gives us iex shell history
ENV ERL_AFLAGS="-kernel shell_history enabled"

EXPOSE 4008
