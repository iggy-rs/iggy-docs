---
id: samples-basic
slug: /samples/basic
title: Basic
sidebar_position: 2
---

For the working sample, please refer to the [repository](https://github.com/iggy-rs/iggy/tree/master/examples/src/basic). Some of the methods used in the sample are described in the [shared](/samples/shared) section.

In the example below, you can find the simple approach using string as a message payload. To get up and running with building your own client and producer applications from the scratch, navigate to the [getting started](/introduction/getting-started) section.

## Producer

```rust
use clap::Parser;
use iggy::client::Client;
use iggy::client_provider;
use iggy::client_provider::ClientProviderConfig;
use iggy::messages::send_messages::{Message, Partitioning};
use iggy_examples::shared::args::Args;
use iggy_examples::shared::system;
use std::error::Error;
use std::str::FromStr;
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    tracing_subscriber::fmt::init();
    info!(
        "Basic producer has started, selected transport: {}",
        args.transport
    );
    let client_provider_config = Arc::new(ClientProviderConfig::from_args(args.to_sdk_args())?);
    let client = client_provider::get_raw_connected_client(client_provider_config).await?;
    let client = client.as_ref();
    system::login_root(client).await;
    system::init_by_producer(&args, client).await?;
    produce_messages(&args, client).await
}

async fn produce_messages(args: &Args, client: &dyn Client) -> Result<(), Box<dyn Error>> {
    info!(
        "Messages will be sent to stream: {}, topic: {}, partition: {} with interval {} ms.",
        args.stream_id, args.topic_id, args.partition_id, args.interval
    );
    let mut interval = tokio::time::interval(std::time::Duration::from_millis(args.interval));
    let mut current_id = 0u64;
    let partitioning = Partitioning::partition_id(args.partition_id);
    loop {
        let mut messages = Vec::new();
        let mut sent_messages = Vec::new();
        for _ in 0..args.messages_per_batch {
            current_id += 1;
            let payload = format!("message-{current_id}");
            let message = Message::from_str(&payload)?;
            messages.push(message);
            sent_messages.push(payload);
        }
        client
            .send_messages(
                &args.stream_id.try_into()?,
                &args.topic_id.try_into()?,
                &partitioning,
                &mut messages,
            )
            .await?;
        info!("Sent messages: {:#?}", sent_messages);
        interval.tick().await;
    }
}
```

## Consumer

```rust
use clap::Parser;
use iggy::client_provider;
use iggy::client_provider::ClientProviderConfig;
use iggy::models::messages::PolledMessage;
use iggy_examples::shared::args::Args;
use iggy_examples::shared::system;
use std::error::Error;
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    tracing_subscriber::fmt::init();
    info!(
        "Basic consumer has started, selected transport: {}",
        args.transport
    );
    let client_provider_config = Arc::new(ClientProviderConfig::from_args(args.to_sdk_args())?);
    let client = client_provider::get_raw_connected_client(client_provider_config).await?;
    let client = client.as_ref();
    system::login_root(client).await;
    system::init_by_consumer(&args, client).await;
    system::consume_messages(&args, client, &handle_message).await
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

