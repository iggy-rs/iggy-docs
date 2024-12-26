---
id: server-introduction
slug: /server/introduction
title: Introduction
sidebar_position: 1
---

## Introduction

Iggy server is the most important part of the system as it's responsible for handling all the incoming connections, managing the data and providing the API for the clients. The server is written in Rust and can be run on any platform that supports it.

The releases are published to GitHub and can be found [here](https://github.com/iggy-rs/iggy/tags). The official Docker images can be found [here](https://hub.docker.com/r/iggyrs/iggy), simply type `docker pull iggyrs/iggy`.

Keep in mind, that if you were to compile the source code in release mode, the longer compilation time is due to [LTO](https://doc.rust-lang.org/rustc/linker-plugin-lto.html) enabled in [profile](https://github.com/iggy-rs/iggy/blob/master/Cargo.toml#L2).

The HTTP API endpoints can be found in [server.http](https://github.com/iggy-rs/iggy/blob/master/server/server.http) file, which can be used with [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension for VS Code.

In order to see the detailed logs from the server, run it with `RUST_LOG=trace` environment variable.

And finally, to seed the example data, simply execute `cargo r --bin data-seeder-tool` from the root of the repository while running your Iggy server.

All the requests to the server except of sending a ping, fetching the stats or logging in, require the session to be authenticated. The session is created by logging in with the user's credentials or personal access token and is valid for the duration of the session or until the user logs out or the connection is lost. In case of HTTP API, the authentication is done by providing the `Authorization` header with the `Bearer` token.
