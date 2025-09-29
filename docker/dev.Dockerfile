ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20250428-slim

ARG DEV_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${DEV_IMAGE}

ARG TARGETPLATFORM
RUN echo "Building for ${TARGETPLATFORM:?}"

# Install debian packages
RUN apt-get update -qq && \
  apt-get install -y inotify-tools curl git openssh-client jq \
    python3 python3-setuptools python3-wheel python3-dev pipx \
    python3-mutagen locales procps build-essential graphviz zsh unzip

# Install ffmpeg
RUN export FFMPEG_DOWNLOAD=$(case ${TARGETPLATFORM:-linux/amd64} in \
    "linux/amd64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz"   ;; \
    "linux/arm64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linuxarm64-gpl.tar.xz" ;; \
    *)               echo ""        ;; esac) && \
    curl -L ${FFMPEG_DOWNLOAD} --output /tmp/ffmpeg.tar.xz && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/bin/ "ffmpeg" && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/bin/ "ffprobe"

# Install nodejs and Yarn
RUN curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh && \
  bash nodesource_setup.sh && \
  apt-get install -y nodejs && \
  npm install -g yarn && \
  # Install baseline Elixir packages
  mix local.hex --force && \
  mix local.rebar --force && \
  # Install Deno - required for YouTube downloads (See yt-dlp#14404)
  curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh -s -- -y --no-modify-path && \
  # Download and update YT-DLP
  export YT_DLP_DOWNLOAD=$(case ${TARGETPLATFORM:-linux/amd64} in \
  "linux/amd64")   echo "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"   ;; \
  "linux/arm64")   echo "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64" ;; \
  *)               echo "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"        ;; esac) && \
  curl -L ${YT_DLP_DOWNLOAD} -o /usr/local/bin/yt-dlp && \
  chmod a+rx /usr/local/bin/yt-dlp && \
  yt-dlp -U && \
  # Install Apprise
  export PIPX_HOME=/opt/pipx && \
  export PIPX_BIN_DIR=/usr/local/bin && \
  pipx install apprise && \
  # Set up ZSH tools
  chsh -s $(which zsh) && \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

COPY mix.exs mix.lock ./
# Install Elixir deps
# NOTE: this has to be before the bulk copy to ensure that deps are cached
RUN MIX_ENV=dev mix deps.get && MIX_ENV=dev mix deps.compile
RUN MIX_ENV=test mix deps.get && MIX_ENV=test mix deps.compile

COPY . ./

# Gives us iex shell history
ENV ERL_AFLAGS="-kernel shell_history enabled"

EXPOSE 4008
