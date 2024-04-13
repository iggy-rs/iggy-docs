---
id: samples-message-envelope
slug: /samples/message-envelope
title: Message envelope
sidebar_position: 3
---

For the working sample, please refer to the [repository](https://github.com/iggy-rs/iggy/tree/master/examples/src/message-envelope). Some of the methods used in the sample are described in the [shared](/samples/shared) section.

In the example below, you can find the message envelope implementation, which could be one of the possible ways of publishing and then consuming different types of messages on the same topic. To get up and running with building your own client and producer applications from the scratch, navigate to the [getting started](/introduction/getting-started) section.

## Producer

```rust title="producer.rs"
use anyhow::Result;
use clap::Parser;
use iggy::client::MessageClient;
use iggy::client_provider;
use iggy::client_provider::ClientProviderConfig;
use iggy::clients::client::IggyClient;
use iggy::messages::send_messages::{Message, Partitioning};
use iggy_examples::shared::args::Args;
use iggy_examples::shared::messages_generator::MessagesGenerator;
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
        "Message envelope producer has started, selected transport: {}",
        args.transport
    );
    let client_provider_config = Arc::new(ClientProviderConfig::from_args(args.to_sdk_args())?);
    let client = client_provider::get_raw_connected_client(client_provider_config).await?;
    let client = IggyClient::builder().with_client(client).build()?;
    system::login_root(&client).await;
    system::init_by_producer(&args, &client).await?;
    produce_messages(&args, &client).await
}

async fn produce_messages(args: &Args, client: &IggyClient) -> Result<(), Box<dyn Error>> {
    info!(
        "Messages will be sent to stream: {}, topic: {}, partition: {} with interval {} ms.",
        args.stream_id, args.topic_id, args.partition_id, args.interval
    );
    let mut interval = tokio::time::interval(std::time::Duration::from_millis(args.interval));
    let mut message_generator = MessagesGenerator::new();
    let partitioning = Partitioning::partition_id(args.partition_id);
    loop {
        let mut messages = Vec::new();
        let mut serializable_messages = Vec::new();
        for _ in 0..args.messages_per_batch {
            let serializable_message = message_generator.generate();
            // You can send the different message types to the same partition, or stick to the single type.
            let json_envelope = serializable_message.to_json_envelope();
            let message = Message::from_str(&json_envelope)?;
            messages.push(message);
            // This is used for the logging purposes only.
            serializable_messages.push(serializable_message);
        }
        client
            .send_messages(
                &args.stream_id.try_into()?,
                &args.topic_id.try_into()?,
                &partitioning,
                &mut messages,
            )
            .await?;
        info!("Sent messages: {:#?}", serializable_messages);
        interval.tick().await;
    }
}

```

## Consumer

```rust title="consumer.rs"
use anyhow::Result;
use clap::Parser;
use iggy::client_provider;
use iggy::client_provider::ClientProviderConfig;
use iggy::clients::client::{
    IggyClient, IggyClientBackgroundConfig, PollMessagesConfig, StoreOffsetKind,
};
use iggy::models::messages::PolledMessage;
use iggy_examples::shared::args::Args;
use iggy_examples::shared::messages::*;
use iggy_examples::shared::system;
use std::error::Error;
use std::sync::Arc;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    tracing_subscriber::fmt::init();
    info!(
        "Message envelope consumer has started, selected transport: {}",
        args.transport
    );
    let client_provider_config = Arc::new(ClientProviderConfig::from_args(args.to_sdk_args())?);
    let client = client_provider::get_raw_connected_client(client_provider_config).await?;
    let client = IggyClient::builder().with_client(client).build()?;
    system::login_root(&client).await;
    system::init_by_consumer(&args, &client).await;
    system::consume_messages(&args, &client, &handle_message).await
}

fn handle_message(message: &PolledMessage) -> Result<(), Box<dyn Error>> {
    // The payload can be of any type as it is a raw byte array. In this case it's a JSON string.
    let json = std::str::from_utf8(&message.payload)?;
    // The message envelope can be used to send the different types of messages to the same topic.
    let envelope = serde_json::from_str::<Envelope>(json)?;
    info!(
        "Handling message type: {} at offset: {}...",
        envelope.message_type, message.offset
    );
    match envelope.message_type.as_str() {
        ORDER_CREATED_TYPE => {
            let order_created = serde_json::from_str::<OrderCreated>(&envelope.payload)?;
            info!("{:#?}", order_created);
        }
        ORDER_CONFIRMED_TYPE => {
            let order_confirmed = serde_json::from_str::<OrderConfirmed>(&envelope.payload)?;
            info!("{:#?}", order_confirmed);
        }
        ORDER_REJECTED_TYPE => {
            let order_rejected = serde_json::from_str::<OrderRejected>(&envelope.payload)?;
            info!("{:#?}", order_rejected);
        }
        _ => {
            warn!("Received unknown message type: {}", envelope.message_type);
        }
    }
    Ok(())
}
```