FROM elixir:1.18.4-alpine

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy dependency files
COPY mix.exs mix.lock* ./

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY lib ./lib
COPY assets ./assets

# Build the release
RUN mix release demo

EXPOSE 3000

# Start the release
CMD ["_build/prod/rel/demo/bin/demo", "start"]