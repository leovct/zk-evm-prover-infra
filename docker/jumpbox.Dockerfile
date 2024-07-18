FROM rustlang/rust:nightly-bullseye-slim
ARG ZERO_BIN_BRANCH_OR_COMMIT
RUN apt-get update \
  && apt-get install --yes build-essential git libjemalloc-dev libjemalloc2 make libssl-dev pkg-config \
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
