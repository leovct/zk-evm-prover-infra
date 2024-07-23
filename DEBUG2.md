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

Fatal error when trying to prove txn `171` of block `b20362227` (second block).

```bash
2024-07-23T13:22:04.412079Z  INFO p_gen: zero_bin_common::prover_state: using monolithic circuit ProverStateManager { circuit_config: CircuitConfig { circuits: [16..25, 8..25, 12..27, 14..25, 9..20, 12..25, 17..28] }, persistence: Disk(Monolithic) } id="b20362227 - 171"
2024-07-23T13:22:06.431044Z  INFO p_gen: evm_arithmetization::generation::state: CPU halted after 514448 cycles     id="b20362227 - 171"
2024-07-23T13:22:06.435273Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 524288 cycles     id="b20362227 - 171"
2024-07-23T13:22:06.436028Z  INFO p_gen: evm_arithmetization::generation: Trace lengths (before padding): TraceCheckpoint { arithmetic_len: 86735, byte_packing_len: 7438, cpu_len: 524288, keccak_len: 41688, keccak_sponge_len: 1737, logic_len: 17277, memory_len: 1581343 }     id="b20362227 - 171"
2024-07-23T13:22:54.550658Z  INFO p_gen: ops: txn proof (31a05521e8f8e3045b1626becf5c72307cf0f85222d379dc578b0b345aa7642a) took 50.138580461s id="b20362227 - 171"
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
2024-07-23T13:23:15.685726Z ERROR paladin::runtime: execution error: Fatal { err: operation BlockProof panicked

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
  10: clone, strategy: Terminate } routing_key=0dc17348b5ae4424a48c6e17b162fecb
```

It was working well...

```bash
2024-07-23T13:20:14.533963Z  INFO p_gen: zero_bin_common::prover_state: using monolithic circuit ProverStateManager { circuit_config: CircuitConfig { circuits: [16..25, 8..25, 12..27, 14..25, 9..20, 12..25, 17..28] }, persistence: Disk(Monolithic) } id="b20362227 - 160"
2024-07-23T13:20:16.659788Z  INFO p_gen: evm_arithmetization::generation::state: CPU halted after 529429 cycles     id="b20362227 - 160"
2024-07-23T13:20:16.835035Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 1048576 cycles     id="b20362227 - 160"
2024-07-23T13:20:16.835766Z  INFO p_gen: evm_arithmetization::generation: Trace lengths (before padding): TraceCheckpoint { arithmetic_len: 89999, byte_packing_len: 8441, cpu_len: 1048576, keccak_len: 53136, keccak_sponge_len: 2214, logic_len: 25051, memory_len: 1664964 }     id="b20362227 - 160"
2024-07-23T13:21:09.522932Z  INFO p_gen: ops: txn proof (0f7ed7c37d220a6a3ce8e5aa8731713037263ea4e7f02beec2e772478f5fd785) took 54.988971816s id="b20362227 - 160"
2024-07-23T13:21:09.527545Z  INFO p_gen: zero_bin_common::prover_state: using monolithic circuit ProverStateManager { circuit_config: CircuitConfig { circuits: [16..25, 8..25, 12..27, 14..25, 9..20, 12..25, 17..28] }, persistence: Disk(Monolithic) } id="b20362227 - 166"
2024-07-23T13:21:11.469074Z  INFO p_gen: evm_arithmetization::generation::state: CPU halted after 531016 cycles     id="b20362227 - 166"
2024-07-23T13:21:11.641539Z  INFO p_gen: evm_arithmetization::generation: CPU trace padded to 1048576 cycles     id="b20362227 - 166"
2024-07-23T13:21:11.642081Z  INFO p_gen: evm_arithmetization::generation: Trace lengths (before padding): TraceCheckpoint { arithmetic_len: 87799, byte_packing_len: 7666, cpu_len: 1048576, keccak_len: 53376, keccak_sponge_len: 2224, logic_len: 22861, memory_len: 1640860 }     id="b20362227 - 166"
2024-07-23T13:22:04.407550Z  INFO p_gen: ops: txn proof (25f42b640ac9f9e36c47e0ec95cf8c5c52578b519a2189e5267ed5eabd0f26b6) took 54.880005554s id="b20362227 - 166"
```

Let's investigate!

```bash
$ cast block --json --rpc-url https://eth.llamarpc.com 20362227 | jq '.transactions[171]'
0x31a05521e8f8e3045b1626becf5c72307cf0f85222d379dc578b0b345aa7642a
```

The worker failed to prove this [transaction](https://etherscan.io/tx/0x31a05521e8f8e3045b1626becf5c72307cf0f85222d379dc578b0b345aa7642a) in which the [Taikobeat Proposer](https://etherscan.io/address/0x000000633b68f5d8d3a86593ebb815b4663bcbe0) calls the `proposeBlock(bytes _params,bytes _txList)` function of this [smart contract](https://etherscan.io/address/0x68d30f47f19c07bccef4ac7fae2dc12fca3e0dc9). The transaction only uses 150,000 GAS which is not that much and there was no spike in CPU or memory usage. Everything looks good for me...

I'm attempting to prove this specific block one more time. If the issue is reproducible, we should adopt a better testing strategy. Currently, proving a range of blocks often gets stuck due to an unprovable block. Instead, we should test standalone witnesses to ensure the prover can handle all mainnet blocks without failing.