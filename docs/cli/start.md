---
id: cli-iggy-cli
slug: /cli/iggy-cli
title: Iggy CLI
sidebar_position: 1
---

The Iggy CLI is a command-line interface that allows you to interact with the Iggy server. You can use the CLI to manage the streams, topics, partitions, messages, users and more. It is part of the core repository under `cli` directory and is written in Rust.

## Installation

Currently, the only way to install the Iggy CLI is by using the Cargo package manager. You can install it by running the following command:

```bash
cargo install iggy-cli
```

Then, you can simply invoke the `iggy` command to see the available options and subcommands.

![CLI](/img/iggy_cli.png)

For example, you can use the following commands to list all the available streams given the server is running on the default address:

```bash
iggy --username iggy --password iggy stream list
```

or with the short syntax:

```bash
iggy -u iggy -p iggy stream list
```

To create a new stream with the specific TCP transport and server address, you can use the following command:

```bash
iggy --transport tcp --tcp-server-address localhost:8090 -u iggy -p secret stream create my-stream
```

To create a new topic within the stream with the specific partition count and retention policy, you can use the following command:

```bash
iggy -u iggy -p secret topic create my-stream my-topic 1 none 7d
```

To send a raw string message to the specific partition of the topic, you can use the following command:

```bash
iggy -u iggy -p iggy message send --partition-id 1 my-stream my-topic "hello world"
```

To fetch the messages from the specific partition of the topic, you can use the following command:

```bash
iggy -u iggy -p iggy message poll --offset 0 --message-count 10 my-stream my-topic 1
```

You could also login with the specific user and password for the given duration and invoke the subsequent requests.
**Please keep in mind that this mode is only supported on Linux systems.**

```bash
iggy -u iggy -p secret login 1h
```

```bash
iggy stream list
```
