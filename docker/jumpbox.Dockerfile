FROM rustlang/rust:nightly-bullseye-slim
ARG ZERO_BIN_BRANCH_OR_COMMIT
ARG GO_VERSION="1.22.5"
RUN apt-get update \
  && apt-get install --yes build-essential git libjemalloc-dev libjemalloc2 make libssl-dev pkg-config \
  && curl -L --output /tmp/go$GO_VERSION.tar.gz https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf /tmp/go$GO_VERSION.tar.gz \
  && git clone https://github.com/0xPolygonZero/zk_evm.git /opt/zk_evm \
  && cd /opt/zk_evm \
  && git checkout $ZERO_BIN_BRANCH_OR_COMMIT \
  && env RUSTFLAGS='-C target-cpu=native -Zlinker-features=-lld' cargo build --release \
  && cp \
    /opt/zk_evm/target/release/leader \
    /opt/zk_evm/target/release/rpc \
    /opt/zk_evm/target/release/verifier \
    /opt/zk_evm/target/release/worker \
    /usr/local/bin/

ENV PATH=$PATH:/usr/local/go/bin
