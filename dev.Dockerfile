ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.2
ARG DEBIAN_VERSION=bookworm-20240130
ARG DEV_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${DEV_IMAGE}

ARG TARGETPLATFORM
RUN echo "Building for ${TARGETPLATFORM:?}"

# Install debian packages
RUN apt-get update -qq
RUN apt-get install -y inotify-tools curl git openssh-client jq \
  python3 python3-setuptools python3-wheel python3-dev pipx \
  python3-mutagen locales procps build-essential

# Install ffmpeg
RUN export FFMPEG_DOWNLOAD=$(case ${TARGETPLATFORM:-linux/amd64} in \
    "linux/amd64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz"   ;; \
    "linux/arm64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz" ;; \
    *)               echo ""        ;; esac) && \
    curl -L ${FFMPEG_DOWNLOAD} --output /tmp/ffmpeg.tar.xz && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/bin/ "ffmpeg" && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/bin/ "ffprobe"

# Install nodejs
RUN curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install nodejs
RUN npm install -g yarn

# Install baseline Elixir packages
RUN mix local.hex --force
RUN mix local.rebar --force

# Download and update YT-DLP
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp
RUN yt-dlp -U

# Install Apprise
RUN export PIPX_HOME=/opt/pipx && \
    export PIPX_BIN_DIR=/usr/local/bin && \
    pipx install apprise

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
