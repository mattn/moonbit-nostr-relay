# Build stage: MoonBit toolchain + libpq headers
FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git build-essential libpq-dev nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
ENV PATH="/root/.moon/bin:${PATH}"

WORKDIR /app

# Fetch dependencies first so they cache independently of source changes
COPY moon.mod .
RUN moon update && moon install

COPY . .
RUN moon build --target native --release

# Runtime stage: only libpq
FROM ubuntu:24.04

LABEL org.opencontainers.image.source=https://github.com/mattn/moonbit-nostr-relay \
      org.opencontainers.image.description="A Nostr relay implemented in MoonBit" \
      org.opencontainers.image.licenses=Apache-2.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home relay

COPY --from=build /app/_build/native/release/build/cmd/native/native.exe /usr/local/bin/nostr-relay

USER relay
ENV HOST=0.0.0.0 \
    PORT=8080
EXPOSE 8080

# Set DATABASE_URL (postgres://user:pass@host:port/db) for PostgreSQL storage;
# without it the relay runs with the in-memory store.
CMD ["/usr/local/bin/nostr-relay"]
