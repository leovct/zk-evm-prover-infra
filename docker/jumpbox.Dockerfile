FROM ubuntu:latest
RUN apt-get update \
  && apt-get install --yes git libjemalloc2 libjemalloc-dev make libssl-dev pkg-config \
  && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh \
  && . $HOME/.cargo/env \
  && git clone --branch develop https://github.com/0xPolygonZero/zero-bin.git /opt/ \
  && pushd /opt/zero-bin \
  && env RUSTFLAGS='-C target-cpu=native -Z linker-features=-lld' cargo build --release --bin leader \
  && cp target/release/leader /usr/local/bin/leader \
  && cp target/release/rpc /usr/local/bin/rpc
