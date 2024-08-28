# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
ARG ELIXIR_VERSION=1.17.0
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bookworm-20240612-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

ARG TARGETPLATFORM
RUN echo "Building for ${TARGETPLATFORM:?}"

# install build dependencies
RUN apt-get update -y && \
    # System packages
    apt-get install -y \
      build-essential \
      git \
      curl && \
    # Node.js and Yarn
    curl -sL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    # Hex and Rebar
    mix local.hex --force && \
    mix local.rebar --force && \
    # FFmpeg (latest build that doesn't cause an illegal instruction error for some users - see #347)
    export FFMPEG_DOWNLOAD=$(case ${TARGETPLATFORM:-linux/amd64} in \
    "linux/amd64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2024-07-30-14-10/ffmpeg-N-116468-g0e09f6d690-linux64-gpl.tar.xz"   ;; \
    "linux/arm64")   echo "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/autobuild-2024-07-30-14-10/ffmpeg-N-116468-g0e09f6d690-linuxarm64-gpl.tar.xz" ;; \
    *)               echo ""        ;; esac) && \
    curl -L ${FFMPEG_DOWNLOAD} --output /tmp/ffmpeg.tar.xz && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/local/bin/ "ffmpeg" && \
    tar -xf /tmp/ffmpeg.tar.xz --strip-components=2 --no-anchored -C /usr/local/bin/ "ffprobe" && \
    # Cleanup
    apt-get clean && \
    rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# set build ENV
ENV MIX_ENV="prod"
ENV ERL_FLAGS="+JPperf true"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV && mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN yarn --cwd assets install && mix assets.deploy && mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

## -- Release Stage --

FROM ${RUNNER_IMAGE}

ARG PORT=8945

COPY --from=builder ./usr/local/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=builder ./usr/local/bin/ffprobe /usr/bin/ffprobe

RUN apt-get update -y && \
    # System packages
    apt-get install -y \
      libstdc++6 \
      openssl \
      libncurses5 \
      locales \
      ca-certificates \
      python3-mutagen \
      curl \
      openssh-client \
      nano \
      python3 \
      pipx \
      jq \
      procps && \
    # Apprise
    export PIPX_HOME=/opt/pipx && \
    export PIPX_BIN_DIR=/usr/local/bin && \
    pipx install apprise && \
    # yt-dlp
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
    chmod a+rx /usr/local/bin/yt-dlp && \
    yt-dlp -U && \
    # Set the locale
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# More locale setup
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

# Set up data volumes
RUN mkdir /config /downloads /etc/elixir_tzdata_data && chmod ugo+rw /etc/elixir_tzdata_data

# set runner ENV
ENV MIX_ENV="prod"
ENV PORT=${PORT}
ENV RUN_CONTEXT="selfhosted"
EXPOSE ${PORT}

# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/pinchflat ./

# NEVER do this if you're running in an environment where you don't trust the user
# (ie: most environments). This is only acceptable in a self-hosted environment.
# The user could just run the whole container as root and bypass this anyway so
# it's not a huge deal.
# This removes the root password to allow users to assume root if needed. This is
# preferrable to running the whole container as root so that the files/directories
# created by the app aren't owned by root and are therefore easier for other users
# and processes to interact with. If you want to just run the whole container as
# root, use --user 0:0 or something.
RUN passwd -d root

HEALTHCHECK --interval=120s --start-period=10s \
  CMD curl --fail http://localhost:${PORT}/healthcheck || exit 1

# Start the app
CMD ["/app/bin/docker_start"]
