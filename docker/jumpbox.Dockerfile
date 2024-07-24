FROM rustlang/rust:nightly-bullseye-slim
ARG ZERO_BIN_BRANCH_OR_COMMIT
RUN apt-get update \
  && apt-get install --yes build-essential curl git procps libjemalloc-dev libjemalloc2 make libssl-dev pkg-config \
  && curl --location --output /usr/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 \
  && chmod +x /usr/bin/jq \
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
