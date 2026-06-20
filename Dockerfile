# ---- Stage 1: Build the Phoenix release ----
FROM hexpm/elixir:1.17.2-erlang-27.0.1-debian-bullseye-20240701-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (for asset pipeline)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy dependency files first (for caching)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy config (all environments — config.exs imports them dynamically)
COPY config ./config

# Compile deps
RUN MIX_ENV=prod mix deps.compile

# Copy application code
COPY lib ./lib
COPY priv ./priv
COPY assets ./assets

# Build assets (CSS + JS)
RUN cd assets && npm install && npm run deploy
RUN MIX_ENV=prod mix assets.deploy

# Compile the application
RUN MIX_ENV=prod mix compile

# Build the release
COPY rel ./rel
RUN MIX_ENV=prod mix release

# ---- Stage 2: Runtime image ----
# Use the same base as builder so Erlang DNS resolver works with Docker's embedded DNS
FROM hexpm/elixir:1.17.2-erlang-27.0.1-debian-bullseye-20240701-slim AS app

RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

# Copy the built release
COPY --from=builder /app/_build/prod/rel/paianjen ./

# Copy custom start script
COPY bin/start.sh ./bin/start.sh

# Create non-root user
RUN groupadd --system paianjen && \
    useradd --system --gid paianjen paianjen && \
    chown -R paianjen:paianjen /app
USER paianjen

EXPOSE 4000

CMD ["bin/start.sh"]
