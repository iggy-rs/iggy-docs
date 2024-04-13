---
id: samples-start
slug: /samples/start
title: Start
sidebar_position: 1
---

The [examples](https://github.com/iggy-rs/iggy/tree/master/examples) are currently available only in Rust, however, there's also dotnet SDK being developed in [C#](https://github.com/iggy-rs/iggy-dotnet-client), [Go](https://github.com/iggy-rs/iggy-go-client), [Node](https://github.com/iggy-rs/iggy-node-client), [Python](https://github.com/iggy-rs/iggy-python-client) and [Java](https://github.com/iggy-rs/iggy-java-client) Also, check out the [getting started](/introduction/getting-started) guide.

You can find the very first version of Iggy crate [here](https://crates.io/crates/iggy), but, at this time, please do not expect an immersive experience, as the SDK hasn't been documented yet :)

Currently, there's no downloadable package of the Iggy server yet, thus, you need to clone the [repository](http://github.com/iggy-rs/iggy) and start the server with `cargo r --bin iggy-server` (or `cargo r --bin iggy-server -r` for the release build, which of course results in the much higher performance). You can also build the Docker image available in the repository.

The official images can be found [here](https://hub.docker.com/r/iggyrs/iggy), simply type `docker pull iggyrs/iggy`.

### Quick start

Build the project (the longer compilation time is due to [LTO](https://doc.rust-lang.org/rustc/linker-plugin-lto.html) enabled in release [profile](https://github.com/iggy-rs/iggy/blob/master/Cargo.toml#L2)):

`cargo build`

Run the tests:

`cargo test`

Authenticate yourself with the default credentials:

`user.login|iggy|iggy`

Start the server:

`cargo r --bin iggy-server`

Start the CLI (transports: `quic`, `tcp`, `http`):

`cargo r --bin iggy-cli -- --transport tcp`

Create a stream named `dev` with ID 1:

`stream.create|1|dev`

List available streams:

`stream.list`

Get stream details (ID 1):

`stream.get|1`

Create a topic named `sample` with ID 1, 2 partitions (IDs 1 and 2) and disabled message expiry (0 seconds) for stream `dev` (ID 1):

`topic.create|1|1|2|0|sample`

List available topics for stream `dev` (ID 1):

`topic.list|1`

Get topic details (ID 1) for stream `dev` (ID 1):

`topic.get|1|1`

Send a message 'hello world' (ID 1) to the stream `dev` (ID 1) to topic `sample` (ID 1) and partition 1:

`message.send|1|1|p|1|1|hello world`

Send another message 'lorem ipsum' (ID 2) to the same stream, topic and partition:

`message.send|1|1|p|1|2|lorem ipsum`

Poll messages by a regular consumer `c` (`g` for consumer group) with ID 0 from the stream `dev` (ID 1) for topic `sample` (ID 1) and partition with ID 1, starting with offset (`o`) 0, messages count 2, without auto commit (`n`) (storing consumer offset on server) and using string format `s` to render messages payload:

`message.poll|c|0|1|1|1|o|0|2|n|s`

Finally, restart the server to see it is able to load the persisted data.

The HTTP API endpoints can be found in [server.http](https://github.com/iggy-rs/iggy/blob/master/server/server.http) file, which can be used with [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension for VS Code.

To see the detailed logs from the CLI/server, run it with `RUST_LOG=trace` environment variable.
