FROM rustlang/rust:nightly-bullseye-slim as builder
RUN apt-get update \
  && apt-get install --yes git libjemalloc2 libjemalloc-dev make libssl-dev pkg-config \
  && git clone --branch develop https://github.com/0xPolygonZero/zero-bin.git /opt/zero-bin \
  && cd /opt/zero-bin \
  && env RUSTFLAGS='-Z linker-features=-lld' cargo build --release

FROM debian:bullseye-slim
RUN apt-get update \
  && apt-get install --yes ca-certificates libjemalloc2
COPY --from=builder \
  /opt/zero-bin/target/release/leader \
  /opt/zero-bin/target/release/rpc \
  /opt/zero-bin/target/release/verifier \
  /opt/zero-bin/target/release/worker \
  /usr/local/bin/
