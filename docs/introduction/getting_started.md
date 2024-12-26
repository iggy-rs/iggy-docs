---
id: introduction-getting-started
slug: /introduction/getting-started
title: Getting started
sidebar_position: 3
---

## What we will build

Once you're familiar with the [architecture](/introduction/architecture), it's high time to build the first application, or actually the set of applications - so-called **producer** (the one that will be publishing the messages to the stream) and **consumer** (yes, you got that right - it will handle the incoming messages stream).

In the typical scenario, e.g. when working with the microservices architecture or any other kind of the distributed system, each application can be both at the same time (producer and consumer), as the particular service might publish its own messages (typically in a form of the events - facts, that have already happened) while at the same time be interested in the notifications coming from the other service(s).

The completed sample can be found in [repository](https://github.com/iggy-rs/iggy/tree/master/examples/src/getting-started), however, we will go through the implementation step by step, so that you can get a better understanding of how to build the applications from scratch.

Also, please do keep in mind that we'll be using the default implementation of `IggyClient` which provides a wrapper on top of the low-level, transport-specific `Client` trait (which you can always use, if you want to have more control over the communication with the server).

On the other hand, if you're looking for a **more developer-friendly client builder API** providing additional features and extensions, please check the next article under [High-level SDK](/introduction/high-level-sdk) section (this is typically how you'd use Iggy SDK in the real-world applications).

Nevertheless, let's start with the basic scenario, and build the producer and consumer applications using the default `IggyClient` implementation, so you can get a better understanding of how to work with the streaming server.

## Starting the Iggy server

For our purpose, we will focus on the basic scenario in order to keep things simple. Before we begin implementing the consumer and producer apps, we need to start the Iggy streaming server first - since there's no official package to be downloaded yet, the only way to get things up and running is by cloning the [repository](https://github.com/iggy-rs/iggy) and then starting the server by running the following command: `cargo r --bin iggy-server` or by building & running the Docker image via `docker compose up`. The official images can be found [here](https://hub.docker.com/r/iggyrs/iggy), simply type `docker pull iggyrs/iggy`. All the data used by the server, will be persisted under `local_data` directory, unless specified differently in the configuration.

As long as the Iggy server is running, we're good to go. If you'd like to play with the configuration (e.g. change the addresses, ports, caching or so) you will find the `server.toml` under `configs` directory in the root of the repository.

## Setting up the project

Let's start by creating a new project - simply type `cargo new iggy-sample` and open your newly created project with the favorite code editor.

At the very beginning, we will organize the files a little bit differently - create a new `consumer` directory under `src` and move the `main.rs` file here. You should have the following project structure:

```
├── Cargo.lock
├── Cargo.toml
├── src
    └── consumer
        └── main.rs
```

Then, open `Cargo.toml` and add the following code before the `[dependencies]`

```
[[bin]]
name = "consumer"
path = "src/consumer/main.rs"
```

Just to make sure that everything is set correctly, try to run the app with `cargo r --bin consumer`.

Now, let's do the same for the `producer` part. Create a new `producer` directory, copy & paste the existing `main.rs`, and update the `Cargo.toml` with the following code:

```
[[bin]]
name = "producer"
path = "src/producer/main.rs"
```

You should have the project structure as shown below:

```
├── Cargo.lock
├── Cargo.toml
├── src
    ├── consumer
    │   └── main.rs
    └── producer
        └── main.rs
```

From that point on, we will focus on implementing the message streaming between our applications, starting with the producer.

## Building the producer

We will begin with installing the Iggy client crate - execute `cargo add iggy` in your terminal. Next, install [tokio.rs](https://tokio.rs) dependency with `cargo add tokio` as we will use the asynchronous runtime. Eventually, modify your `main.rs`, so it looks like this:

```rust
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    Ok(())
}
```

Let's instantiate a new connection to the server. As the description states, Iggy does support different transport protocols such as TCP, QUIC and HTTP, which is entirely true. Yet remember, we want to keep things as simple as possible here, thus, we will make use of the default implementation of `IggyClient` struct, which wraps the underlying raw client for one of the selected transports (in our scenario, this will be `TcpClient`).

```rust
let client = IggyClient::default();
client.connect().await?;
```

The default server address being `127.0.0.1:8090` is configured on the server side, and can be easily adjusted by updating the `server.toml` (the default configuration) or `server.json` file in `configs` directory.

We could make use of more advanced components such as [`ClientProvider`](https://github.com/iggy-rs/iggy/blob/master/sdk/src/client_provider.rs), pass the custom configuration built via console args to choose between the different protocols as all the available clients implement the same [Client](https://github.com/iggy-rs/iggy/blob/master/sdk/src/client.rs) trait and so on.

If you're eager to find out how to build more advanced (and configurable) applications, check the Rust [examples](/sdk/rust/examples). Nevertheless, let's focus on implementing our producer side :)

Next, we need to authenticate the user, as all the available actions (except the `ping` and `login`) require the user to be authenticated and have the appropriate permissions e.g. you might be able to send or poll the messages, but you won't be able to create the stream or topic. For the sake of simplicity, we will use the default credentials for the root user (username: `iggy`, password: `iggy`), that can do anything and cannot be deleted. You can easily create more users and assign the specific permissions to them, however, this is out of scope for this tutorial.

```rust
client
    .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
    .await?;
```

When you start the application now, by running `cargo r --bin producer` it will execute immediately, however, you should be able to see the logs on Iggy server - connection should be accepted, user logged in, and then connection should be closed right away, meaning that we've just established our very first communication with the streaming server.

Before we will move on with the code, let's include some logging in our apps as well (Iggy client already has some logging in place on different levels). Let's make use of the [tracing.rs](https://tracing.rs) crates: `cargo add tracing tracing_subscriber`.

To make use of logging, simply invoke `tracing_subscriber::fmt::init()` at the beginning of `main()` method:

```rust
use std::error::Error;
use iggy::client::{Client, UserClient};
use iggy::clients::client::IggyClient;
use iggy::users::defaults::{DEFAULT_ROOT_PASSWORD, DEFAULT_ROOT_USERNAME};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    tracing_subscriber::fmt::init();
    let client = IggyClient::default();
    client.connect().await?;
    client
        .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
        .await?;
    Ok(())
}
```

From that point on, when starting the application, you should be able to see at least the basic logs, for example regarding the connection status. Keep in mind, that you can change the default log level by setting `RUST_LOG` environment variable, e.g. `export RUST_LOG=trace` (or other command depending on OS).

So far, so good, however, before we will be able to publish any messages to our streaming server, at first, we need to create the stream, topic and partition(s) - if you're unfamiliar with these concepts, please refer to [architecture](/introduction/architecture) where all these concepts are described in-depth.

Since our `IggyClient` implements the common [Client](https://github.com/iggy-rs/iggy/blob/master/sdk/src/client.rs) trait, you can find lots of the different methods to interact with the server, also from the administrative point of view, e.g. creating the streams, topics etc.

One thing worth mentioning is that, these methods are not idempotent - for example, if you were to try creating the stream with the same ID which already exists on the server, you would receive the specific error. In such a case, you can simply check for an error and move on. Let's do this then :)

```rust
use iggy::client::{Client, StreamClient, TopicClient, UserClient};
use iggy::clients::client::IggyClient;
use iggy::identifier::Identifier;
use iggy::streams::create_stream::CreateStream;
use iggy::topics::create_topic::CreateTopic;
use std::error::Error;
use tracing::{info, warn};
use iggy::compression::compression_algorithm::CompressionAlgorithm;
use iggy::users::defaults::{DEFAULT_ROOT_PASSWORD, DEFAULT_ROOT_USERNAME};
use iggy::utils::expiry::IggyExpiry;
use iggy::utils::topic_size::MaxTopicSize;

const STREAM_ID: u32 = 1;
const TOPIC_ID: u32 = 1;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    tracing_subscriber::fmt::init();
    let client = IggyClient::default();
    client.connect().await?;
    client
        .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
        .await?;
    init_system(&client).await;
    Ok(())
}

async fn init_system(client: &IggyClient) {
    match client.create_stream("sample-stream", Some(STREAM_ID)).await {
        Ok(_) => info!("Stream was created."),
        Err(_) => warn!("Stream already exists and will not be created again."),
    }

    match client
        .create_topic(
            &STREAM_ID.try_into().unwrap(),
            "sample-topic",
            1,
            CompressionAlgorithm::default(),
            None,
            Some(TOPIC_ID),
            IggyExpiry::NeverExpire,
            MaxTopicSize::ServerDefault,
        )
        .await
    {
        Ok(_) => info!("Topic was created."),
        Err(_) => warn!("Topic already exists and will not be created again."),
    }
}
```

Finally, let's send some messages into our stream. We will implement the basic loop with an interval between each iteration to simulate publishing the batch of messages. Since the streaming server works directly with the binary data, and couldn't care less about the (de)serialization format for the message payload, it's really up to you, how to efficiently stream the messages for your use case.

In our example, we will simply use the string payload, and pass it via `from_str` trait to construct the [Message](https://github.com/iggy-rs/iggy/blob/master/sdk/src/messages/send_messages.rs#L423).

```rust
let payload = "hello world";
let message = Message::from_str(&payload)?;
```

Next, we need to call the appropriate method to send the messages to the server:

```rust
let payload = "hello world";
let message = Message::from_str(&payload)?;
let messages = vec![message];
let partitioning = Partitioning::partition_id(PARTITION_ID);

client
    .send_messages(
        &STREAM_ID.try_into().unwrap(),
        &TOPIC_ID.try_into().unwrap(),
        &partitioning,
        &mut messages,
    )
    .await?;
```

As you might've already noticed, there are quite a few fields to be assigned. While some of them should be rather self-descriptive, let's discuss the `identifier` (created implicitly by using `TryFrom` on top of `STREAM_ID` and `TOPIC_ID`) and the `partitioning` which might be a little bit confusing at first, starting with the former.

```rust
pub struct Identifier {
    pub kind: IdKind,
    pub length: u8,
    pub value: Vec<u8>,
}
```

Whenever we interact with the streaming server in terms of e.g. sending or polling the messages, managing the streams, topics etc. we need to provide the unique identifier of the stream and the topic that we want to use. Since each stream and topic have a unique numeric ID, as well as a unique name, we can use either of them. Here, we use the numeric ID by calling `Identifier::numeric()`, however, you can also use the string identifier by invoking the `Identifier::named()` method instead. It's up to your preference if you'd rather work with the identifier being a number or string when building your applications.

Next, let's move onto the `partitioning` field:


```rust
pub struct Partitioning {
    pub kind: PartitioningKind,
    pub length: u8,
    pub value: Vec<u8>,
}
```

In our scenario, we simply make use of `PartitioningKind::PartitionId` (by invoking the helper method `partition_id()`) meaning that we want to send the messages to the specified partition ID - in that case, the length will be 4 bytes (as the partition ID is of type `u32`), and the value will be the actual partition ID encoded as the bytes array.

However, once your system grows, you might want to parallelize the messages across the independent consumers, in order to achieve the horizontal scaling, higher resiliency etc. In that case, you might consider using either `PartitioningKind::Balanced` (this will automatically calculate the next partition ID using the simple round-robin algorithm approach e.g. 1->2->3->1->2->3 etc.) or `PartitioningKind::MessagesKey` instead (e.g. by invoking one of the helper methods `messages_key()`), where the value wouldn't be a partition ID anymore (this would be calculated on the server side using murmur3 hash of the received value), but, as the name states, some kind of identifier, which is unique for all the messages that should have guaranteed ordering.

For example, given that you process the set of messages related to the specific order ID (e.g. created, confirmed, paid, delivered etc.), you could use that as a key value to ensure that all the messages which are part of the specific workflow, will always be put onto the same partition. The value of the key can be anything (e.g. string, number) with the maximum length of 255 bytes.

Anyway, let's get back to our scenario, and consider the following code responsible for publishing the messages:

```rust
async fn produce_messages(client: &IggyClient) -> Result<(), Box<dyn Error>> {
    let interval = Duration::from_millis(500);
    info!(
        "Messages will be sent to stream: {}, topic: {}, partition: {} with interval {} ms.",
        STREAM_ID,
        TOPIC_ID,
        PARTITION_ID,
        interval.as_millis()
    );

    let mut current_id = 0;
    let messages_per_batch = 10;
    let partitioning = Partitioning::partition_id(PARTITION_ID);
    loop {
        let mut messages = Vec::new();
        for _ in 0..messages_per_batch {
            current_id += 1;
            let payload = format!("message-{current_id}");
            let message = Message::from_str(&payload)?;
            messages.push(message);
        }
        client
            .send_messages(
                &STREAM_ID.try_into().unwrap(),
                &TOPIC_ID.try_into().unwrap(),
                &partitioning,
                &mut messages,
            )
            .await?;
        info!("Sent {messages_per_batch} message(s).");
        sleep(interval).await;
    }
}
```

The reason behind passing a mutable reference is that the underlying client (especially when using the `IggyClient` wrapper on top of the low-level client) might want to modify the command before sending it to the server. For example, the client might want to encrypt the payload, include the default headers, or provide a custom `Partitioner` implementation etc. thus by using `&mut` we can avoid copying the command each time.

Finally, let's complete the implementation of the producer - once you start the application after the latest changes, you shall see the messages being sent to the newly created stream.

```rust
use iggy::client::{Client, MessageClient, StreamClient, TopicClient, UserClient};
use iggy::clients::client::IggyClient;
use iggy::messages::send_messages::{Message, Partitioning};
use std::error::Error;
use std::str::FromStr;
use std::time::Duration;
use tokio::time::sleep;
use tracing::{info, warn};
use iggy::compression::compression_algorithm::CompressionAlgorithm;
use iggy::users::defaults::{DEFAULT_ROOT_PASSWORD, DEFAULT_ROOT_USERNAME};
use iggy::utils::expiry::IggyExpiry;
use iggy::utils::topic_size::MaxTopicSize;

const STREAM_ID: u32 = 1;
const TOPIC_ID: u32 = 1;
const PARTITION_ID: u32 = 1;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    tracing_subscriber::fmt::init();
    let client = IggyClient::default();
    client.connect().await?;
    client
        .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
        .await?;
    init_system(&client).await;
    produce_messages(&client).await?;
    Ok(())
}

async fn init_system(client: &IggyClient) {
    match client.create_stream("sample-stream", Some(STREAM_ID)).await {
        Ok(_) => info!("Stream was created."),
        Err(_) => warn!("Stream already exists and will not be created again."),
    }

    match client
        .create_topic(
            &STREAM_ID.try_into().unwrap(),
            "sample-topic",
            1,
            CompressionAlgorithm::default(),
            None,
            Some(TOPIC_ID),
            IggyExpiry::NeverExpire,
            MaxTopicSize::ServerDefault,
        )
        .await
    {
        Ok(_) => info!("Topic was created."),
        Err(_) => warn!("Topic already exists and will not be created again."),
    }
}

async fn produce_messages(client: &IggyClient) -> Result<(), Box<dyn Error>> {
    let interval = Duration::from_millis(500);
    info!(
        "Messages will be sent to stream: {}, topic: {}, partition: {} with interval {} ms.",
        STREAM_ID,
        TOPIC_ID,
        PARTITION_ID,
        interval.as_millis()
    );

    let mut current_id = 0;
    let messages_per_batch = 10;
    let partitioning = Partitioning::partition_id(PARTITION_ID);
    loop {
        let mut messages = Vec::new();
        for _ in 0..messages_per_batch {
            current_id += 1;
            let payload = format!("message-{current_id}");
            let message = Message::from_str(&payload)?;
            messages.push(message);
        }
        client
            .send_messages(
                &STREAM_ID.try_into().unwrap(),
                &TOPIC_ID.try_into().unwrap(),
                &partitioning,
                &mut messages,
            )
            .await?;
        info!("Sent {messages_per_batch} message(s).");
        sleep(interval).await;
    }
}
```

## Building the consumer

The consumer part will be rather easy to implement. Just like on the producer side, we want to make use of the asynchronous runtime, logging and last but not least, the same `Client` trait. Let's find out, how we can make use of the `poll_messages` method, to fetch the messages from the stream. Consider the following code:

```rust
let polled_messages = client
    .poll_messages(
        &STREAM_ID.try_into()?,
        &TOPIC_ID.try_into()?,
        Some(PARTITION_ID),
        &Consumer::default(),
        &PollingStrategy::offset(offset),
        messages_per_batch,
        false,
    )
    .await?;
```

At the first glance, it might look a bit more complicated than `send_messages` function, so let's discuss the fields one by one:

- `stream_id` - the ID of the stream (numeric or string) from which we want to poll the messages.

- `topic_id` - the ID of the topic (numeric or string) from which we want to poll the messages.

- `partition_id` - the ID of the partition from which we want to poll the messages. The partition has to be specified for the regular `Consumer`, while for the `ConsumerGroup` it's ignored (`None` value), as the server will automatically assign the partition to the consumer from the group.

- `consumer` - the type of the consumer (kind + ID), either the default `Consumer` means the standalone client which does the message polling on its own, independently of the other consumers (unless they would use the same ID), or the `ConsumerGroup` which might be used to create the group of consumers sharing the common identifier - this is especially useful in the case of the horizontal scaling, where we want to ensure, that the same (and only one) consumer, will poll the messages from the specific partition, and there will be no overlap with the other consumers from the same group. For example, when scaling out (by adding more instances) the group of payment processing microservices, we probably don't want the multiple instances to process the same payment.

- `strategy` - the way in which we want to poll the messages. The default one being `Offset` (underlying `PollingKind` enum) means that we will start polling the messages from the particular offset provided in the `value` field - it's on the client, to keep track of the most recent offset. On the other hand, we could also use the different kind, for example `Next`, which means, that the next messages will be returned to the client, depending on the so-called `consumer offset` value stored on the server side. The client may not need to track the offset on its own anymore, but instead, call `store_offset()` to save it on the server (e.g. after each processed message or the whole batch), or make use of  `auto_commit: true`, to automatically commit the offset on the server side, once the messages are fetched (this one results in the so called at-most-once delivery mode).

- `count` - amount of the messages that the consumer would like to receive in the single response from the server.

- `auto_commit` - whether the consumer offset should be automatically committed on the server side, once the messages are fetched.

Next, let's take a look at the following method responsible for polling the messages based on the specified interval.

```rust
async fn consume_messages(client: &IggyClient) -> Result<(), Box<dyn Error>> {
    let interval = Duration::from_millis(500);
    let mut offset = 0;
    let messages_per_batch = 10;
    let consumer = Consumer::default();
    let mut strategy = PollingStrategy::offset(offset);
    loop {
        let polled_messages = client
            .poll_messages(
                &STREAM_ID.try_into()?,
                &TOPIC_ID.try_into()?,
                Some(PARTITION_ID),
                &consumer,
                &PollingStrategy::offset(offset),
                messages_per_batch,
                false,
            )
            .await?;

        if polled_messages.messages.is_empty() {
            info!("No messages found.");
            sleep(interval).await;
            continue;
        }

        offset += polled_messages.messages.len() as u64;
        strategy.set_value(offset);
        for message in polled_messages.messages {
            handle_message(&message)?;
        }
        sleep(interval).await;
    }
}
```

And here's the final code for our consumer application:

```rust
use iggy::client::{Client, MessageClient, UserClient};
use iggy::clients::client::IggyClient;
use iggy::consumer::Consumer;
use iggy::messages::poll_messages::PollingStrategy;
use iggy::models::messages::PolledMessage;
use std::error::Error;
use std::time::Duration;
use tokio::time::sleep;
use tracing::info;
use iggy::users::defaults::{DEFAULT_ROOT_PASSWORD, DEFAULT_ROOT_USERNAME};

const STREAM_ID: u32 = 1;
const TOPIC_ID: u32 = 1;
const PARTITION_ID: u32 = 1;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    tracing_subscriber::fmt::init();
    let client = IggyClient::default();
    client.connect().await?;
    client
        .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
        .await?;
    consume_messages(&client).await
}

async fn consume_messages(client: &IggyClient) -> Result<(), Box<dyn Error>> {
    let interval = Duration::from_millis(500);
    info!(
        "Messages will be consumed from stream: {}, topic: {}, partition: {} with interval {} ms.",
        STREAM_ID,
        TOPIC_ID,
        PARTITION_ID,
        interval.as_millis()
    );

    let mut offset = 0;
    let messages_per_batch = 10;
    let consumer = Consumer::default();
    let mut strategy = PollingStrategy::offset(offset);
    loop {
        let polled_messages = client
            .poll_messages(
                &STREAM_ID.try_into()?,
                &TOPIC_ID.try_into()?,
                Some(PARTITION_ID),
                &consumer,
                &PollingStrategy::offset(offset),
                messages_per_batch,
                false,
            )
            .await?;

        if polled_messages.messages.is_empty() {
            info!("No messages found.");
            sleep(interval).await;
            continue;
        }

        offset += polled_messages.messages.len() as u64;
        strategy.set_value(offset);
        for message in polled_messages.messages {
            handle_message(&message)?;
        }
        sleep(interval).await;
    }
}

fn handle_message(message: &PolledMessage) -> Result<(), Box<dyn Error>> {
    // The payload can be of any type as it is a raw byte array. In this case it's a simple string.
    let payload = std::str::from_utf8(&message.payload)?;
    info!(
        "Handling message at offset: {}, payload: {}...",
        message.offset, payload
    );
    Ok(())
}
```

Start the Iggy server, and then producer and consumer applications respectively - you should observe your messages being streamed flawlessly :)


## Summary

What we've just achieved is merely the tip of an iceberg, however, it should give you a good understanding of what Iggy is all about, and hopefully, it wasn't too difficult to follow and get things up and running for the first time. Feel free to take a look at the more advanced [examples](https://github.com/iggy-rs/iggy/tree/master/examples), how to make use of `IggyClient` wrapper on top of the existing implementations of the `Client` trait, what happens when you start multiple producers and consumers and so on. Happy tweaking! :)
