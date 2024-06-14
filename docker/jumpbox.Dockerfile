FROM rustlang/rust:nightly-bullseye-slim as builder
RUN apt-get update \
  && apt-get install --yes git libjemalloc2 libjemalloc-dev make libssl-dev pkg-config \
  && git clone --branch develop https://github.com/0xPolygonZero/zero-bin.git /opt/zero-bin \
  && cd /opt/zero-bin \
  && env RUSTFLAGS='-Z linker-features=-lld' cargo build --release

FROM debian:bullseye-slim
RUN apt-get update \
  && apt-get install --yes ca-certificates libjemalloc2
COPY --from=builder ./target/release/leader /usr/local/bin/leader
COPY --from=builder ./target/release/rpc /usr/local/bin/rpc
COPY --from=builder ./target/release/verifier /usr/local/bin/verifier
COPY --from=builder ./target/release/worker /usr/local/bin/worker
