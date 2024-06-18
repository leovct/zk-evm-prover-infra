FROM rustlang/rust:nightly-bullseye-slim
ARG ZERO_BIN_BRANCH_OR_COMMIT
RUN apt-get update \
  && apt-get install --yes git curl jq vim parallel libjemalloc2 libjemalloc-dev make libssl-dev pkg-config \
  && git clone https://github.com/0xPolygonZero/zero-bin.git /opt/zero-bin \
  && cd /opt/zero-bin \
  && git checkout $ZERO_BIN_BRANCH_OR_COMMIT \
  && cargo build --release \
  && cp \
    /opt/zero-bin/target/release/leader \
    /opt/zero-bin/target/release/rpc \
    /opt/zero-bin/target/release/verifier \
    /opt/zero-bin/target/release/worker \
    /usr/local/bin/
