# DEBUG2

Download the new witness archive (`witnesses/cancun/witnesses-20362226-to-20362237.tar`) created by John.

```bash
git clone https://github.com/leovct/zero-prover-infra.git /tmp/zero-prover-infra
mkdir /tmp/witnesses2
tar --extract --file=/tmp/zero-prover-infra/witnesses/cancun/witnesses-20362226-to-20362237.tar.xz --directory=/tmp/witnesses2 --strip-components=1
```

Quick analysis of the number of witnesses.

```bash
$ ./tmp/zero-prover-infra/tools/analyze-witnesses.sh /tmp/witnesses2 20362226 20362237
/tmp/witnesses/20362226.witness.json 166 txs
/tmp/witnesses/20362227.witness.json 174 txs
/tmp/witnesses/20362228.witness.json 120 txs
/tmp/witnesses/20362229.witness.json 279 txs
/tmp/witnesses/20362230.witness.json 177 txs
/tmp/witnesses/20362231.witness.json 164 txs
/tmp/witnesses/20362232.witness.json 167 txs
/tmp/witnesses/20362233.witness.json 238 txs
/tmp/witnesses/20362234.witness.json 216 txs
/tmp/witnesses/20362235.witness.json 200 txs
/tmp/witnesses/20362236.witness.json 92 txs
/tmp/witnesses/20362237.witness.json 188 txs
Total transactions: 2181
```

Attempt to prove the first witness.

```bash
folder="/tmp/witnesses2"
witness_id=20362226
witness_file="$folder/$witness_id.witness.json"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio < "$witness_file" | tee "$witness_file.leader.out"
```

Check the leader output.

```bash
2024-07-22T13:40:06.933510Z  INFO prover: Proving block 20362226
2024-07-22T14:57:35.314259Z  INFO prover: Successfully proved block 20362226
2024-07-22T14:57:35.319041Z  INFO leader::stdio: All proofs have been generated successfully.
// proof content
```

Format the proof content.

```bash
tail -n +4 "$witness_file.leader.out" | jq empty
tail -n +4 "$witness_file.leader.out" | jq '.[0]' > "$witness_file.proof"
```

Attempt to prove the second witness using the first witness proof.

```bash
folder="/tmp/witnesses2"
witness_id=20362227
witness_file="$folder/$witness_id.witness.json"
previous_proof="$folder/$(( witness_id - 1 )).witness.json.proof"
env RUST_BACKTRACE=full \
  RUST_LOG=info \
  leader \
  --runtime=amqp \
  --amqp-uri=amqp://guest:guest@test-rabbitmq-cluster.zero.svc.cluster.local:5672 \
  stdio \
  --previous-proof "$previous_proof" < "$witness_file" | tee "$witness_file.leader.out"
```

We confirmed the setup works manually! Now, let's use a script to automate the proving of a range of witnesses.

```bash
./tmp/zero-prover-infra/tools/prove-witnesses.sh /tmp/witnesses2 20362226 20362237
```

Note that for the purpose of the test, we used a `c3d-highmem-180` instance (180 vCPU / 1.44TB of memory) and we deployed 3 workers on the node.

We manage to prove approximately 100 transactions every 20 minutes, equating to a speed of 300 transactions per hour. Given that there are around 2200 transactions to prove, it would take roughly 7 hours and 20 minutes to prove the range of 10 blocks with the given setup.

The experiment demonstrates that a single worker can process approximately 100 transactions per hour. Adding a fourth worker to our current three-worker setup could potentially reduce the total proving time from about 7 hours and 20 minutes to approximately 5 hours and 30 minutes, saving around 1 hour and 50 minutes.

However, it's crucial to consider that workers may require substantial memory depending on the complexity of transactions being proved, which could lead to out-of-memory (OOM) errors... Given the cluster metrics, the first block never requires more than 50GB to prove a transaction. It is safe to deploy two additional workers for now.

![cluster-metrics](./debug2-cluster-metrics.png)

## Errors

Fatal error when trying to prove the second block `b20362227`.

```bash
2024-07-23T13:27:21.356183Z  INFO prover: Proving block 20362227
Error: Fatal operation error: operation BlockProof panicked

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

The workers were proving transactions.

```bash
2024-07-23T13:46:48.463216Z  INFO p_gen: zero_bin_common::prover_state: using monolithic circuit ProverStateManager { circuit_config: CircuitConfig { circuits: [16..25, 8..25, 12..27, 14..25, 9..20, 12..25, 17..28] }, persistence: Disk(Monolithic) } id="b20362227 - 163"
2024-07-23T13:46:51.646014Z  INFO p_gen: evm_arithmetization::generation::state: CPU halted after 552085 cycles     id="b20362227 - 163"
2024-07-23T13:46:51.806809Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 1048576 cycles     id="b20362227 - 163"
2024-07-23T13:46:51.807365Z  INFO p_gen: evm_arithmetization::generation: Trace lengths (before padding): TraceCheckpoint { arithmetic_len: 90724, byte_packing_len: 7690, cpu_len: 1048576, keccak_len: 66144, keccak_sponge_len: 2756, logic_len: 24783, memory_len: 1782198 }     id="b20362227 - 163"
2024-07-23T13:47:54.636231Z  INFO p_gen: ops: txn proof (c18823511a1a1c63e6b709be1d5f6550285836311c9bcb662246f8677ce2413a) took 66.173016908s id="b20362227 - 163"
2024-07-23T13:47:54.640000Z  INFO p_gen: zero_bin_common::prover_state: using monolithic circuit ProverStateManager { circuit_config: CircuitConfig { circuits: [16..25, 8..25, 12..27, 14..25, 9..20, 12..25, 17..28] }, persistence: Disk(Monolithic) } id="b20362227 - 170"
2024-07-23T13:47:56.061052Z  INFO p_gen: evm_arithmetization::generation::state: CPU halted after 244150 cycles     id="b20362227 - 170"
2024-07-23T13:47:56.067805Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 262144 cycles     id="b20362227 - 170"
2024-07-23T13:47:56.068066Z  INFO p_gen: evm_arithmetization::generation: Trace lengths (before padding): TraceCheckpoint { arithmetic_len: 41206, byte_packing_len: 3156, cpu_len: 262144, keccak_len: 25848, keccak_sponge_len: 1077, logic_len: 7410, memory_len: 783284 }     id="b20362227 - 170"
2024-07-23T13:48:19.785067Z  INFO p_gen: ops: txn proof (f400b61f7a6626e99ed528d2a527f50f825d6681c01c4b901cad569767d1fb7f) took 25.145069252s id="b20362227 - 170"
```

Suddenly, one of the workers stops because of a panic error.

```bash
thread 'tokio-runtime-worker' panicked at /usr/local/cargo/registry/src/index.crates.io-6f17d22bba15001f/plonky2-0.2.2/src/iop/witness.rs:324:13:
assertion `left == right` failed: Partition containing VirtualTarget { index: 22763 } was set twice with different values: 9324335365483090500 != 9324335365483090000
  left: 9324335365483090000
 right: 9324335365483090500
stack backtrace:
   0:     0x555f05d7f345 - <std::sys::backtrace::BacktraceLock::print::DisplayBacktrace as core::fmt::Display>::fmt::hbb39a5b22c5522ea
   1:     0x555f05da669b - core::fmt::write::hd52b97735497fa0a
   2:     0x555f05d7bf2f - std::io::Write::write_fmt::h4e190402461d4df2
   3:     0x555f05d804b1 - std::panicking::default_hook::{{closure}}::h6dc84da0b6ee219c
   4:     0x555f05d8018c - std::panicking::default_hook::hc5fc06a36ec72601
   5:     0x555f05d80b11 - std::panicking::rust_panic_with_hook::h55343650ed08bd9c
   6:     0x555f05d80977 - std::panicking::begin_panic_handler::{{closure}}::h6f0034c5e2b583e0
   7:     0x555f05d7f809 - std::sys::backtrace::__rust_end_short_backtrace::h33aff4a62310ac31
   8:     0x555f05d80604 - rust_begin_unwind
   9:     0x555f0522f313 - core::panicking::panic_fmt::h673c803ef6df3393
  10:     0x555f0522f76f - core::panicking::assert_failed_inner::h17027ecc569a798d
  11:     0x555f0520880f - core::panicking::assert_failed::hb416d0c4fb76e6bf
  12:     0x555f056beaeb - plonky2::iop::witness::PartitionWitness<F>::set_target_returning_rep::h80e20c7ee15788ec
  13:     0x555f056f9e3a - plonky2::iop::generator::generate_partial_witness::hfe374fac17208777
  14:     0x555f05727ea6 - plonky2::plonk::prover::prove::he1c5c0373b10e196
  15:     0x555f056fb16a - plonky2::plonk::circuit_data::CircuitData<F,C,_>::prove::hecb40155da2f708f
  16:     0x555f056c0de1 - proof_gen::proof_gen::generate_block_proof::h33bb1e693adf9a21
  17:     0x555f053a201a - <ops::BlockProof as paladin::operation::Operation>::execute::hac198b5c2578046e
  18:     0x555f053dcb3d - <tokio::runtime::blocking::task::BlockingTask<T> as core::future::future::Future>::poll::h3f46808c5690ccac
  19:     0x555f053b4e24 - tokio::runtime::task::core::Core<T,S>::poll::h744a9da4f31ee835
  20:     0x555f053e062d - tokio::runtime::task::harness::Harness<T,S>::poll::h1dce7c3196e066a7
  21:     0x555f05b77eb2 - tokio::runtime::blocking::pool::Inner::run::h855c3017462ba7aa
  22:     0x555f05b6a62f - std::sys::backtrace::__rust_begin_short_backtrace::h1e70da333f1aada0
  23:     0x555f05b6ae42 - core::ops::function::FnOnce::call_once{{vtable.shim}}::h86e7b514db4f553d
  24:     0x555f05d83b2b - std::sys::pal::unix::thread::Thread::new::thread_start::h459c1fae425fed2d
  25:     0x7f9df644dea7 - start_thread
  26:     0x7f9df6223a6f - clone
  27:                0x0 - <unknown>
2024-07-23T13:49:09.380725Z ERROR paladin::runtime: execution error: Fatal { err: operation BlockProof panicked

Stack backtrace:
   0: anyhow::error::<impl anyhow::Error>::msg
   1: paladin::operation::error::FatalError::from_str
   2: <tokio::runtime::blocking::task::BlockingTask<T> as core::future::future::Future>::poll
   3: tokio::runtime::task::core::Core<T,S>::poll
   4: tokio::runtime::task::harness::Harness<T,S>::poll
   5: tokio::runtime::blocking::pool::Inner::run
   6: std::sys::backtrace::__rust_begin_short_backtrace
   7: core::ops::function::FnOnce::call_once{{vtable.shim}}
   8: std::sys::pal::unix::thread::Thread::new::thread_start
   9: start_thread
  10: clone, strategy: Terminate } routing_key=be16a8f22a2747c5b3c6bfabb384f1ee
```

I tried to prove the second block one more time and it failed once again... I think we should adopt a better testing strategy. Currently, proving a range of blocks often gets stuck due to an unprovable block. Instead, we should test standalone witnesses to ensure the prover can handle all mainnet blocks without failing.
