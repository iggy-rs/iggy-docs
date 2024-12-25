---
id: server-benchmarking
slug: /server/benchmarking
title: Benchmarking
sidebar_position: 5
---

Iggy comes with a built-in benchmarking tool that allows you to measure the performance of the server. It is written in Rust and uses the `tokio` runtime for asynchronous I/O operations mimicking the example client applications.  The tool is designed to be as close to real-world scenarios as possible, so you can use it to estimate the performance of the server in your environment. It is part of the [core repository](https://github.com/iggy-rs/iggy/tree/master/bench) and can be found in the `bench` directory.

To benchmark the project, first build the project in release mode or download the pre-built binary from the [releases page](https://hub.docker.com/r/iggyrs/iggy/tags).

```bash
cargo build --release
```

Next, start the server in the release mode (or use the pre-built binary) with the default configuration.

```bash
cargo run --bin iggy-server -r
```

Then, run the benchmarking app with the desired options. You can also use [just](https://github.com/casey/just) to simplify the process. The `justfile` in the root level of repository and one of its commands is `rb` that runs the benchmarking app with the default options.

The benchmarking app has several subcommands that allow you to test different scenarios. The most common subcommands are `send`, `poll`, `send-and-poll`, and `consumer-group-poll`. The `send` subcommand sends messages to the server, the `poll` subcommand reads messages from the server, the `send-and-poll` subcommand sends and reads messages in parallel, and the `consumer-group-poll` subcommand reads messages from the server using a consumer group.

You can also provide additional options to the subcommands to customize the benchmarking process like the message size, number of messages, number of producers and consumers, and other options.

### Polling (reading) benchmark

   ```bash
   cargo r --bin iggy-bench -r -- -c -v send tcp
   ```

### Sending (writing) benchmark

   ```bash
   cargo r --bin iggy-bench -r -- -c -v poll tcp
   ```

### Parallel sending and polling benchmark

   ```bash
   cargo r --bin iggy-bench -r -- -c -v send-and-poll tcp
   ```

### Polling with consumer group

   ```bash
   cargo r --bin iggy-bench -r -- -c -v send --streams 1 --partitions 10 --disable-parallel-producers tcp
   ```

   ```bash
   cargo r --bin iggy-bench -r -- -c -v consumer-group-poll tcp
   ```

### Send a total amount of 1mln messages 1KB each by 30 producers to 30 streams

```bash
cargo r --bin iggy-bench -r send --streams 30 --producers 30 --message-size 1000 --messages-per-batch 1000 --message-batches 1000 tcp
```

### Poll a total amount of 1mln messages 1KB each by 30 consumers from 30 streams

```bash
cargo r --bin iggy-bench -r poll --streams 30 --consumers 30 --messages-per-batch 1000 --message-batches 1000 tcp
```

These benchmarks would start the server with the default configuration, create a stream, topic and partition, and then send or poll the messages. The default configuration is optimized for the best performance, so you might want to tweak it for your needs. If you need more options, please refer to `iggy-bench` subcommands `help` and `examples`.
For example, to run the benchmark for the already started server, provide the additional argument `--server-address 0.0.0.0:8090`.

Depending on the hardware, transport protocol (`quic`, `tcp` or `http`), message size, amount of messages, number of producers and consumers, and other factors, the results may vary. You can also tune the server configuration to achieve better performance.
