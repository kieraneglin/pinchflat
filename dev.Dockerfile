ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.2
ARG DEBIAN_VERSION=bookworm-20240130
ARG DEV_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${DEV_IMAGE}

# Install debian packages
RUN apt-get update -qq
RUN apt-get install -y inotify-tools ffmpeg curl git openssh-client jq \
  python3 python3-pip python3-setuptools python3-wheel python3-dev locales procps

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install nodejs
RUN npm install -g yarn

# Install baseline Elixir packages
RUN mix local.hex --force
RUN mix local.rebar --force

# Download and update YT-DLP
# NOTE: If you're seeing weird issues, consider using the FFMPEG released by yt-dlp
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp
RUN yt-dlp -U

# Download Apprise
RUN python3 -m pip install -U apprise --break-system-packages

# Download Mutagen for music thumbnail generation
RUN python3 -m pip install -U mutagen --break-system-packages

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Create app directory and copy the Elixir projects into it.
WORKDIR /app
COPY . ./

# Needs permissions to be updated AFTER the copy step
RUN chmod +x ./docker-run.dev.sh

# Install Elixir deps
# RUN mix archive.install github hexpm/hex branch latest
RUN mix deps.get
# Gives us iex shell history
ENV ERL_AFLAGS="-kernel shell_history enabled"

EXPOSE 4008
