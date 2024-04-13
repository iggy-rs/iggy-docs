---
id: server-configuration
slug: /server/configuration
title: Configuration
sidebar_position: 1
---

## Introduction

Iggy server is the most important part of the system. It is responsible for managing streams, connections etc., and for serving the data to the consumers.

Currently, there's no downloadable package of the Iggy server yet, thus, you need to clone the [repository](http://github.com/iggy-rs/iggy) and start the server with `cargo r --bin iggy-server` (or `cargo r --bin iggy-server --r` for the release build, which of course results in the much higher performance). You can also build the Docker image available in the repository or use the official images available [here](https://hub.docker.com/r/iggyrs/iggy).

Keep in mind, that when you compile the source code in release mode, the longer compilation time is due to [LTO](https://doc.rust-lang.org/rustc/linker-plugin-lto.html) enabled in [profile](https://github.com/iggy-rs/iggy/blob/master/Cargo.toml#L2).

## Configuration

The configuration can be found in `server.toml` (the default one) or `server.json` file in `configs` directory. The config file is loaded from the current working directory, but you can specify the path to the configuration file by setting `IGGY_CONFIG_PATH` environment variable, for example `export IGGY_CONFIG_PATH=configs/server.json` (or other command depending on OS).

Let's take a look at the configuration file, and discuss the available options.

```toml
[http]
enabled = true
address = "0.0.0.0:3000"

[http.cors]
enabled = true
allowed_methods = [ "GET", "POST", "PUT", "DELETE" ]
allowed_origins = [ "*" ]
allowed_headers = [ "content-type" ]
exposed_headers = [ ]
allow_credentials = false
allow_private_network = false

[http.jwt]
secret = "top_secret$iggy.rs$_jwt_HS256_key#!"
expiry = 3600

[http.tls]
enabled = false
cert_file = "certs/iggy_cert.pem"
key_file = "certs/iggy_key.pem"

[tcp]
enabled = true
address = "0.0.0.0:8090"

[tcp.tls]
enabled = false
certificate = "certs/iggy.pfx"
password = "iggy123"

[quic]
enabled = true
address = "0.0.0.0:8080"
max_concurrent_bidi_streams = 10_000
datagram_send_buffer_size = 100_000
initial_mtu = 8_000
send_window = 100_000
receive_window = 100_000
keep_alive_interval = 5_000
max_idle_timeout = 10_000

[quic.certificate]
self_signed = true
cert_file = "certs/iggy_cert.pem"
key_file = "certs/iggy_key.pem"

[message_cleaner]
enabled = true
interval = 60

[message_saver]
enabled = true
enforce_fsync = true
interval = 30

[system]
path = "local_data"

[system.database]
path = "database"

[system.logging]
path = "logs"
level = "info"
max_size_megabytes = 512
retention_days = 7

[system.encryption]
enabled = false
key = ""

[system.stream]
path = "streams"

[system.topic]
path = "topics"

[system.partition]
path = "partitions"
deduplicate_messages = false
enforce_fsync = false
validate_checksum = false
messages_required_to_save = 10_000
messages_buffer = 1_048_576

[system.segment]
message_expiry = 0
size_bytes = 1_000_000_000
cache_indexes = true
cache_time_indexes = true
```

### HTTP

An optional transport layer, which can be used to connect to the server with any tool or application that supports HTTP. It is enabled by default, but you can disable it by setting `enabled` to `false`. The `address` option specifies the address and port to listen on. The `cors` section allows you to configure the CORS policy, which internally uses [Tower middleware](https://docs.rs/tower-http/latest/tower_http/cors/index.html).

HTTP API is built on top of [Axum](https://github.com/tokio-rs/axum) and you can find all the available endpoints in [server.http](https://github.com/iggy-rs/iggy/blob/master/server/server.http) file, which can be used with [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) extension for VS Code.

To consume the HTTP API from Iggy SDK, you need to make use of the available `HttpClient` component.

HTTP API is highly performant, however, it's not as performant as TCP, and, since it's a stateless protocol, there's no such thing as the ongoing connection between client and server, thus some of the features such as consumer groups are not available.

### TCP

An optional transport layer, which can be used to connect to the server with any tool or application that supports TCP. It is enabled by default, but you can disable it by setting `enabled` to `false`. The `address` option specifies the address and port to listen on.

TCP provides the highest performance and throughput as it works directly with the binary data without an additional overhead of e.g. HTTP spec along with the JSON serialization.

To consume the TCP API from Iggy SDK, you need to make use of the available `TcpClient` component.

### QUIC

An optional transport layer, which can be used to connect to the server with any tool or application that supports QUIC. It is enabled by default, but you can disable it by setting `enabled` to `false`. The `address` option specifies the address and port to listen on.

Similar to TCP it's a stateful protocol, however, it's not as performant as TCP. QUIC support is built on top of [Quinn](https://github.com/quinn-rs/quinn) library, and all the remaining options are essentially the direct mapping of the options available in Quinn. QUIC and TCP use the same custom binary protocol specification.

To consume the QUIC API from Iggy SDK, you need to make use of the available `QuicClient` component.

### Message cleaner

The optional component, running in the background, is responsible for deleting the expired messages. The whole segment will be removed, when all the messages in this segment are expired. By default, the expired messages are removed every 60 seconds, but you can change this by setting the `interval` option to the desired value. The `message_expiry` option in the `partition` section of the configuration file specifies the number of seconds after which the message will be marked as expired. If the `message_expiry` is set to 0, then the message expiry is disabled and the data will be kept forever.

### Message saver

The optional component, running in the background, is responsible for saving the buffered data to the disk every X seconds based on the provided `interval`. By default, the data will be written onto disk whenever the amount of `messages_required_to_save` is reached (see the `partition` options below) or in case of the graceful shutdown.

Message saver is enabled by default, but you can disable it by setting `enabled` to `false`. The `enforce_fsync` option specifies whether the data should be saved synchronously (enforce `fsync`) or asynchronously (let the OS decide when to actually flush the data onto disk).

By using this component, you can easily control when the messages are being saved, for example every 1000 records and/or every 30 seconds.

### System

The most comprehensive part of the configuration, which is responsible for configuring the system paths, and the default settings for the streams, topics, partitions and segments. Let's discuss them one by one.

#### Root

- `path` - the path to the directory where the data will be stored. It's relative to the current working directory.

### Database

- `path` - the path to the directory where the database will be stored. It's relative to the `system.path` option.


### Logging

- `path`: The path to the directory where the log files will be stored. By default, it is set to "logs". This path is relative to system.path.

- `level`: Specifies the level of logs to be saved. Valid options are "debug", "info", "warn", "error", and "fatal". The default level is "info".

- `max_size_megabytes`: The maximum size of a log folder in megabytes. When this size is reached, logs will rotate, deleting oldest entries. The default size is set to 512 megabytes.

- `retention_days`: The number of days for which log files should be retained. After this period, old log files will be automatically deleted. The default is set to 7 days.


#### Encryption

- `enabled` - toggle for the optional server-side data encryption using AES-256-GCM. When enabled, you need to provide the `key` option.
- `key` - the encryption key of 32 bytes length, provided as a base64 encoded string.


#### Stream

- `path` - the path to the directory where the streams will be stored. It's relative to the `system.path` option.


#### Topic

- `path` - the path to the directory where the topics will be stored. It's relative to the `stream.path` option.

#### Partition

- `path` - the path to the directory where the partitions will be stored. It's relative to the `topic.path` option.

- `deduplicate_messages` - whether the messages with same ID should be ignored. When sending the messages, you can optionally provide their unique ID - if the same ID is set more than once, then the message will be ignored. Deduplication is unique per partition.

- `enforce_fsync` - whether the data should be saved synchronously (enforce `fsync`) or asynchronously (let the OS decide when to actually flush the data onto disk).

- `validate_checksum` - whether the message checksum (CRC) should be validated when loading the data from the disk. This can provide an additional layer of protection against the data corruption.

- `messages_required_to_save` - the number of messages that will be buffered before saving them to the disk. This option along with the `enforce_fsync` allow you to control the trade-off between the performance and the strong consistency guarantees in terms of durability of the data.

- `messages_buffer` - the number of the messages that will be kept in cache, in order to greatly speed up reading the records. While it's much faster to read the data from the memory than from disk, it's worth considering how much memory you want to allocate for this purpose. When the value is set to 0, the cache is disabled. Internally, it does use the ring buffer structure and the value must be power of 2.


#### Segment

- `message_expiry` - the number of seconds after which the message will be marked as expired. The expired messages will be removed from the disk when the segment is full (all the messages in the segment are expired). When set to 0, the message expiry is disabled.

- `size_bytes` - the maximum size of the segment in bytes. When the size is reached, a new segment is automatically created. If the `message_expiry` is greater than 0, then the new segment will be created either after the size is reached or when all the messages are expired.

- `cache_indexes` - whether the indexes required to read the messages by the specific offset should be cached in memory. Otherwise, the indexes will be read directly from the disk.

- `cache_time_indexes` - whether the time indexes required to read the messages by the specific timestamp should be cached in memory. Otherwise, the  time indexes will be read directly from the disk.