# DEBUG

The goal of this experiment is to be able to prove a thousand [Cancun](https://ethereum.org/en/roadmap/dencun/) blocks using the [GKE setup](https://github.com/leovct/zero-prover-infra).

John created an [archive](https://cf-ipfs.com/ipfs/QmTk9TyuFwA7rjPh1u89oEp8shpFUtcdXuKRRySZBfH1Pu) of witnesses for this purpose.

We built new docker images of [zk_evm](https://github.com/0xPolygonZero/zk_evm) and of the [zero-jumpbox](https://github.com/leovct/zero-prover-infra/blob/main/docker/jumpbox.Dockerfile) using this [procedure](https://github.com/leovct/zero-prover-infra/tree/main?tab=readme-ov-file#docker-images):

- [leovct/zk_evm:v0.5.0](https://hub.docker.com/layers/leovct/zk_evm/v0.5.0/images/sha256-09fbcbc36d48f5773f55e2219f7427a5d19a4802a0b22ac29b0f3a1841b064df?context=repo)
- [leovct/zero-jumpbox:v0.5.0](https://hub.docker.com/layers/leovct/zero-jumpbox/v0.5.0/images/sha256-b519eca11a3e0bbef5949f2dca2d918dac88bdd56c23e19d81b0d63e734a39a1?context=repo)
- [leovct/zk_evm:v0.6.0](https://hub.docker.com/layers/leovct/zk_evm/v0.6.0/images/sha256-90a32b947aa295c9f0bfe5dbc17549ca3d26346ac1c77039a396362d6a35520a?context=repo)
- [leovct/zero-jumpbox:v0.6.0](https://hub.docker.com/layers/leovct/zero-jumpbox/v0.6.0/images/sha256-f4c1ec5c960ccb5c04a48f315cc2019a8250996a7b0a1a5a3f256831c9722b59?context=repo)

We then attempted to prove some of these witnesses, especially the smallest ones to confirm the prover was working properly. However, it looks like both the [v0.5.0](https://github.com/0xPolygonZero/zk_evm/releases/tag/v0.5.0) and the [v0.6.0](https://github.com/0xPolygonZero/zk_evm/releases/tag/v0.6.0) versions fail to prove any of those witnesses...

## t2d-standard-32

Clone the [zero-prover-infra](https://github.com/leovct/zero-prover-infra) repository.

Make a few modifications to the config:

- Modify the [highmem_pool_machine_type](https://github.com/leovct/zero-prover-infra/blob/main/terraform/variables.tf#L73) to `t2d-standard-32`.
- Modify the [worker pod limits](https://github.com/leovct/zero-prover-infra/blob/main/helm/values.yaml#L29) to `2T`.

Deploy the GKE cluster and the zkevm Prover infrastructure on top of it.

```bash
kubectl get pods --namespace zero -o wide
```

``` bash
NAME                                  READY   STATUS    RESTARTS   AGE     IP            NODE                                                  NOMINATED NODE   READINESS GATES
test-jumpbox-7464fb577c-5z9lk         1/1     Running   0          2m36s   10.236.3.27   gke-leovct-test-03-g-default-node-poo-2888ce3f-7jcp   <none>           <none>
test-rabbitmq-cluster-server-0        1/1     Running   0          32m     10.236.3.26   gke-leovct-test-03-g-default-node-poo-2888ce3f-7jcp   <none>           <none>
test-zk-evm-worker-86d5b5f46b-vwswr   1/1     Running   0          2m36s   10.236.4.4    gke-leovct-test-03-g-highmem-node-poo-cdb1d5d3-16g1   <none>           <none>
```

Connect to the jumpbox.

```bash
jumpbox_pod_name="$(kubectl get pods --namespace zero -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep jumpbox)"
kubectl exec --namespace zero --stdin --tty "$jumpbox_pod_name" -- /bin/bash
```

Get access to a shell.

```bash
root@test-jumpbox-7464fb577c-5z9lk:/#
```

Download the archive of Cancun witnesses.

```bash
curl -L --output /tmp/witnesses.xz https://cf-ipfs.com/ipfs/QmTk9TyuFwA7rjPh1u89oEp8shpFUtcdXuKRRySZBfH1Pu
mkdir -p /tmp/witnesses
tar --extract --file=/tmp/witnesses.xz --directory=/tmp/witnesses --strip-components=1 --checkpoint=10000 --checkpoint-action=dot
```

Sort the Cancun witnesses by size.

```bash
$ ls -lS /tmp/witnesses/*.witness.json | sort -k5,5n | head -n 5
-rw-r--r-- 1 root root    54082 Jul  5 16:04 /tmp/witnesses/20241377.witness.json
-rw-r--r-- 1 root root   551686 Jul  5 15:31 /tmp/witnesses/20241214.witness.json
-rw-r--r-- 1 root root   838553 Jul  5 17:25 /tmp/witnesses/20241781.witness.json
-rw-r--r-- 1 root root  1214437 Jul  5 16:33 /tmp/witnesses/20241522.witness.json
-rw-r--r-- 1 root root  1363052 Jul  5 18:10 /tmp/witnesses/20242010.witness.json
```

Also download a few Shanghai witnesses, just for the sake of testing.

```bash
mkdir /tmp/zero-prover-infra
git clone https://github.com/leovct/zero-prover-infra.git /tmp/zero-prover-infra
```

Sort the Shanghai witnesses by size.

```bash
$ ls -lS /tmp/zero-prover-infra/witnesses/shanghai/*.witness.json | sort -k5,5n | head -n 5
-rw-r--r-- 1 root root  981937 Jul 18 16:18 /tmp/zero-prover-infra/witnesses/shanghai/19240705.witness.json
-rw-r--r-- 1 root root 4767334 Jul 18 16:18 /tmp/zero-prover-infra/witnesses/shanghai/19240718.witness.json
-rw-r--r-- 1 root root 5673475 Jul 18 16:18 /tmp/zero-prover-infra/witnesses/shanghai/19240663.witness.json
```

### v0.5.0

For these experiments, we use `zk_evm:v0.5.0`.

Modify the [zk_evm_image](https://github.com/leovct/zero-prover-infra/blob/main/helm/values.yaml#L2) parameter in the configuration to `leovct:v0.5.0` and re-apply the Helm chart.

```bash
helm upgrade test --namespace zero --create-namespace ./helm
```

You should have the following.

```bash
kubectl get pods --namespace zero --output json | jq --raw-output '.items[].spec.containers[0].image'
```

```bash
leovct/zero-jumpbox:v0.5.0
rabbitmq:3.13.3
leovct/zk_evm:v0.5.0
```

Attempt to prove the smallest witness of the archive, `20241377.witness.json`.

```bash
witness_file="/tmp/witnesses/20241377.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

The worker fails to generate the proof.

```bash
2024-07-18T15:51:29.306305Z DEBUG lapin::channels: create channel id=0
2024-07-18T15:51:29.325880Z DEBUG lapin::channels: create channel
2024-07-18T15:51:29.325965Z DEBUG lapin::channels: create channel id=1
2024-07-18T15:51:29.333641Z  INFO prover: Proving block 20241377
Error: Fatal operation error: Attempting to load circuit: BytePacking at size: 8

Stack backtrace:
   0: anyhow::kind::Adhoc::new
   1: paladin::task::AnyTaskResult::into_task_result
   2: <paladin::channel::coordinated_channel::coordinated_stream::CoordinatedStream<S> as futures_core::stream::Stream>::poll_next
   3: <futures_util::stream::stream::map::Map<St,F> as futures_core::stream::Stream>::poll_next
   4: <futures_util::stream::stream::then::Then<St,Fut,F> as futures_core::stream::Stream>::poll_next
   5: <futures_util::stream::select_with_strategy::SelectWithStrategy<St1,St2,Clos,State> as futures_core::stream::Stream>::poll_next
   6: <futures_util::stream::select::Select<St1,St2> as futures_core::stream::Stream>::poll_next
   7: <futures_util::stream::try_stream::try_for_each_concurrent::TryForEachConcurrent<St,Fut,F> as core::future::future::Future>::poll
   8: <futures_util::future::future::map::Map<Fut,F> as core::future::future::Future>::poll
   9: <futures_util::future::try_future::try_flatten::TryFlatten<Fut,<Fut as futures_core::future::TryFuture>::Ok> as core::future::future::Future>::poll
  10: <tokio::future::poll_fn::PollFn<F> as core::future::future::Future>::poll
  11: paladin::directive::indexed_stream::foldable::<impl paladin::directive::Foldable<B> for paladin::directive::indexed_stream::IndexedStream<A>>::f_fold::{{closure}}
  12: <paladin::directive::Fold<M,D> as paladin::directive::Directive>::run::{{closure}}
  13: <futures_util::future::future::map::Map<Fut,F> as core::future::future::Future>::poll
  14: <futures_util::future::future::Then<Fut1,Fut2,F> as core::future::future::Future>::poll
  15: <futures_util::stream::futures_unordered::FuturesUnordered<Fut> as futures_core::stream::Stream>::poll_next
  16: <futures_util::stream::try_stream::try_collect::TryCollect<St,C> as core::future::future::Future>::poll
  17: prover::ProverInput::prove::{{closure}}
  18: leader::main::{{closure}}
  19: tokio::runtime::park::CachedParkThread::block_on
  20: leader::main
  21: std::sys::backtrace::__rust_begin_short_backtrace
  22: std::rt::lang_start::{{closure}}
  23: std::rt::lang_start_internal
  24: main
  25: __libc_start_main
  26: _start
```

Another attempt to prove the second smallest witness, `20241214.witness.json`.

```bash
witness_file="/tmp/witnesses/20241214.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Another failure of the worker.

```bash
2024-07-18T15:52:00.307491Z DEBUG lapin::channels: create channel id=0
2024-07-18T15:52:00.326322Z DEBUG lapin::channels: create channel
2024-07-18T15:52:00.326336Z DEBUG lapin::channels: create channel id=1
2024-07-18T15:52:00.338744Z  INFO prover: Proving block 20241214
2024-07-18T15:52:30.327161Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:52:30.373234Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:53:17.940181Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:53:56.506093Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:54:00.329951Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:54:43.903780Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:55:21.347532Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:55:30.333051Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:56:08.402436Z DEBUG lapin::channels: send heartbeat
Error: Fatal operation error: "Inconsistent pre-state for first block 0x2f8d9fa5035f2d1c65e7f6708c544c4aaef659483d1b7d7a36223ae00a87754b with checkpoint state 0xb309d5fa1c73db03b77ba559f81c2fc94f9461da5dd9cf8241f383d7a2ac96e9."

Stack backtrace:
   0: anyhow::kind::Adhoc::new
   1: paladin::task::AnyTaskResult::into_task_result
   2: <paladin::channel::coordinated_channel::coordinated_stream::CoordinatedStream<S> as futures_core::stream::Stream>::poll_next
   3: <futures_util::stream::stream::map::Map<St,F> as futures_core::stream::Stream>::poll_next
   4: paladin::directive::literal::functor::<impl paladin::directive::Functor<B> for paladin::directive::literal::Literal<A>>::f_map::{{closure}}
   5: <paladin::directive::Map<Op,D> as paladin::directive::Directive>::run::{{closure}}
   6: <futures_util::future::future::map::Map<Fut,F> as core::future::future::Future>::poll
   7: <futures_util::future::future::Then<Fut1,Fut2,F> as core::future::future::Future>::poll
   8: <futures_util::stream::futures_unordered::FuturesUnordered<Fut> as futures_core::stream::Stream>::poll_next
   9: <futures_util::stream::try_stream::try_collect::TryCollect<St,C> as core::future::future::Future>::poll
  10: prover::ProverInput::prove::{{closure}}
  11: leader::main::{{closure}}
  12: tokio::runtime::park::CachedParkThread::block_on
  13: leader::main
  14: std::sys::backtrace::__rust_begin_short_backtrace
  15: std::rt::lang_start::{{closure}}
  16: std::rt::lang_start_internal
  17: main
  18: __libc_start_main
  19: _start
```

A last attempt with a small Shanghai witness, `19240705.witness.json`.

```bash
witness_file="/tmp/zero-prover-infra/witnesses/shanghai/19240705.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

The worker fails immediatly without starting to work on the proof.

```bash
2024-07-18T16:20:31.513659Z DEBUG lapin::channels: create channel id=0
2024-07-18T16:20:31.532957Z DEBUG lapin::channels: create channel
2024-07-18T16:20:31.532971Z DEBUG lapin::channels: create channel id=1
2024-07-18T16:20:31.541737Z ERROR lapin::io_loop: error doing IO error=IOError(Custom { kind: Other, error: "A Tokio 1.x context was found, but it is being shutdown." })
2024-07-18T16:20:31.541774Z ERROR lapin::channels: Connection error error=IO error: A Tokio 1.x context was found, but it is being shutdown.
Error: invalid type: map, expected a sequence at line 1 column 0

Stack backtrace:
   0: anyhow::error::<impl core::convert::From<E> for anyhow::Error>::from
   1: leader::main::{{closure}}
   2: tokio::runtime::park::CachedParkThread::block_on
   3: leader::main
   4: std::sys::backtrace::__rust_begin_short_backtrace
   5: std::rt::lang_start::{{closure}}
   6: std::rt::lang_start_internal
   7: main
   8: __libc_start_main
   9: _start
```

A very last attempt with another Shanghai witness, `19240718.witness.json`.

```bash
witness_file="//tmp/zero-prover-infra/witnesses/shanghai/19240718.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Same error.

```bash
2024-07-18T16:21:59.760895Z DEBUG lapin::channels: create channel id=0
2024-07-18T16:21:59.779171Z DEBUG lapin::channels: create channel
2024-07-18T16:21:59.779186Z DEBUG lapin::channels: create channel id=1
2024-07-18T16:21:59.792198Z ERROR lapin::io_loop: error doing IO error=IOError(Custom { kind: Other, error: "A Tokio 1.x context was found, but it is being shutdown." })
2024-07-18T16:21:59.792221Z ERROR lapin::channels: Connection error error=IO error: A Tokio 1.x context was found, but it is being shutdown.
Error: invalid type: map, expected a sequence at line 1 column 0

Stack backtrace:
   0: anyhow::error::<impl core::convert::From<E> for anyhow::Error>::from
   1: leader::main::{{closure}}
   2: tokio::runtime::park::CachedParkThread::block_on
   3: leader::main
   4: std::sys::backtrace::__rust_begin_short_backtrace
   5: std::rt::lang_start::{{closure}}
   6: std::rt::lang_start_internal
   7: main
   8: __libc_start_main
   9: _start
```

Other attempts with other witnesses.

```bash
witness_file="tmp/zero-prover-infra/witnesses/432.erc721.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO

```bash
witness_file="tmp/zero-prover-infra/witnesses/512.eoa.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO

```bash
witness_file="tmp/zero-prover-infra/witnesses/512.erc20.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO

### v0.6.0

For these experiments, we use `zk_evm:v0.6.0`.

Modify the [zk_evm_image](https://github.com/leovct/zero-prover-infra/blob/main/helm/values.yaml#L2) parameter in the configuration to `leovct:v0.6.0` and re-apply the Helm chart.

```bash
helm upgrade test --namespace zero --create-namespace ./helm
```

You should have the following.

```bash
kubectl get pods --namespace zero --output json | jq --raw-output '.items[].spec.containers[0].image'
```

```bash
leovct/zero-jumpbox:v0.6.0
rabbitmq:3.13.3
leovct/zk_evm:v0.6.0
```

Attempt to prove the smallest witness of the archive, `20241377.witness.json`.

```bash
witness_file="/tmp/witnesses/20241377.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

The worker fails to generate the proof.

```bash
2024-07-18T15:23:11.020883Z DEBUG lapin::channels: create channel id=0
2024-07-18T15:23:11.041078Z DEBUG lapin::channels: create channel
2024-07-18T15:23:11.041092Z DEBUG lapin::channels: create channel id=1
2024-07-18T15:23:11.049219Z  INFO prover: Proving block 20241377
Error: Fatal operation error: "Inconsistent pre-state for first block 0x758dc25679497ce8853a3b722abbe7dff2b8841b5bac27938f0b6722edda5a21 with checkpoint state 0xb309d5fa1c73db03b77ba559f81c2fc94f9461da5dd9cf8241f383d7a2ac96e9."

Stack backtrace:
   0: anyhow::kind::Adhoc::new
   1: paladin::task::AnyTaskResult::into_task_result
   2: <paladin::channel::coordinated_channel::coordinated_stream::CoordinatedStream<S> as futures_core::stream::Stream>::poll_next
   3: <futures_util::stream::stream::map::Map<St,F> as futures_core::stream::Stream>::poll_next
   4: paladin::directive::literal::functor::<impl paladin::directive::Functor<B> for paladin::directive::literal::Literal<A>>::f_map::{{closure}}
   5: <paladin::directive::Map<Op,D> as paladin::directive::Directive>::run::{{closure}}
   6: <futures_util::future::future::map::Map<Fut,F> as core::future::future::Future>::poll
   7: <futures_util::future::future::flatten::Flatten<Fut,<Fut as core::future::future::Future>::Output> as core::future::future::Future>::poll
   8: <futures_util::future::future::Then<Fut1,Fut2,F> as core::future::future::Future>::poll
   9: <futures_util::stream::futures_unordered::FuturesUnordered<Fut> as futures_core::stream::Stream>::poll_next
  10: <futures_util::stream::try_stream::try_collect::TryCollect<St,C> as core::future::future::Future>::poll
  11: prover::ProverInput::prove::{{closure}}
  12: leader::main::{{closure}}
  13: tokio::runtime::park::CachedParkThread::block_on
  14: leader::main
  15: std::sys::backtrace::__rust_begin_short_backtrace
  16: std::rt::lang_start::{{closure}}
  17: std::rt::lang_start_internal
  18: main
  19: __libc_start_main
  20: _start
```

Another attempt to prove the second smallest witness, `20241214.witness.json`.

```bash
witness_file="/tmp/witnesses/20241214.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Another failure of the worker.

```bash
2024-07-18T15:25:12.121306Z DEBUG lapin::channels: create channel id=0
2024-07-18T15:25:12.142529Z DEBUG lapin::channels: create channel
2024-07-18T15:25:12.142543Z DEBUG lapin::channels: create channel id=1
2024-07-18T15:25:12.155002Z  INFO prover: Proving block 20241214
2024-07-18T15:25:42.143004Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:25:42.189075Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:26:30.279172Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:27:08.870111Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:27:12.146104Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:27:56.287478Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:28:33.447209Z DEBUG lapin::channels: send heartbeat
2024-07-18T15:28:42.148999Z DEBUG lapin::channels: received heartbeat from server
2024-07-18T15:29:20.633057Z DEBUG lapin::channels: send heartbeat
Error: Fatal operation error: "Inconsistent pre-state for first block 0x2f8d9fa5035f2d1c65e7f6708c544c4aaef659483d1b7d7a36223ae00a87754b with checkpoint state 0xb309d5fa1c73db03b77ba559f81c2fc94f9461da5dd9cf8241f383d7a2ac96e9."

Stack backtrace:
   0: anyhow::kind::Adhoc::new
   1: paladin::task::AnyTaskResult::into_task_result
   2: <paladin::channel::coordinated_channel::coordinated_stream::CoordinatedStream<S> as futures_core::stream::Stream>::poll_next
   3: <futures_util::stream::stream::map::Map<St,F> as futures_core::stream::Stream>::poll_next
   4: paladin::directive::literal::functor::<impl paladin::directive::Functor<B> for paladin::directive::literal::Literal<A>>::f_map::{{closure}}
   5: <paladin::directive::Map<Op,D> as paladin::directive::Directive>::run::{{closure}}
   6: <futures_util::future::future::map::Map<Fut,F> as core::future::future::Future>::poll
   7: <futures_util::future::future::flatten::Flatten<Fut,<Fut as core::future::future::Future>::Output> as core::future::future::Future>::poll
   8: <futures_util::future::future::Then<Fut1,Fut2,F> as core::future::future::Future>::poll
   9: <futures_util::stream::futures_unordered::FuturesUnordered<Fut> as futures_core::stream::Stream>::poll_next
  10: <futures_util::stream::try_stream::try_collect::TryCollect<St,C> as core::future::future::Future>::poll
  11: prover::ProverInput::prove::{{closure}}
  12: leader::main::{{closure}}
  13: tokio::runtime::park::CachedParkThread::block_on
  14: leader::main
  15: std::sys::backtrace::__rust_begin_short_backtrace
  16: std::rt::lang_start::{{closure}}
  17: std::rt::lang_start_internal
  18: main
  19: __libc_start_main
  20: _start
```

A last attempt with a small Shanghai witness, `19240705.witness.json`.

```bash
witness_file="/tmp/zero-prover-infra/witnesses/shanghai/19240705.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

The worker fails immediatly without starting to work on the proof.

```bash
witness_file="/tmp/zero-prover-infra/witnesses/shanghai/19240705.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

A very last attempt with another Shanghai witness, `19240718.witness.json`.

```bash
witness_file="/tmp/zero-prover-infra/witnesses/shanghai/19240718.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Same error.

```bash
2024-07-18T16:25:13.891970Z DEBUG lapin::channels: create channel id=0
2024-07-18T16:25:13.911392Z DEBUG lapin::channels: create channel
2024-07-18T16:25:13.911406Z DEBUG lapin::channels: create channel id=1
2024-07-18T16:25:13.924580Z ERROR lapin::io_loop: error doing IO error=IOError(Custom { kind: Other, error: "A Tokio 1.x context was found, but it is being shutdown." })
2024-07-18T16:25:13.924601Z ERROR lapin::channels: Connection error error=IO error: A Tokio 1.x context was found, but it is being shutdown.
Error: invalid type: map, expected a sequence at line 1 column 0

Stack backtrace:
   0: anyhow::error::<impl core::convert::From<E> for anyhow::Error>::from
   1: leader::main::{{closure}}
   2: tokio::runtime::park::CachedParkThread::block_on
   3: leader::main
   4: std::sys::backtrace::__rust_begin_short_backtrace
   5: std::rt::lang_start::{{closure}}
   6: std::rt::lang_start_internal
   7: main
   8: __libc_start_main
   9: _start
```

Other attempts with other witnesses.

```bash
witness_file="tmp/zero-prover-infra/witnesses/432.erc721.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO

```bash
witness_file="tmp/zero-prover-infra/witnesses/512.eoa.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO

```bash
witness_file="tmp/zero-prover-infra/witnesses/512.erc20.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=debug \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

TODO
