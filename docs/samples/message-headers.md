---
id: samples-message-headers
slug: /samples/message-headers
title: Message headers
sidebar_position: 4
---

For the working sample, please refer to the [repository](https://github.com/iggy-rs/iggy/tree/master/examples/src/message-headers). Some of the methods used in the sample are described in the [shared](/samples/shared) section.

In the example below, you can find the usage of the custom message header, which is responsible for passing the message type. To get up and running with building your own client and producer applications from the scratch, navigate to the [getting started](/introduction/getting-started) section.

## Producer

```rust title="producer.rs"
use anyhow::Result;
use bytes::Bytes;
use clap::Parser;
use iggy::client::MessageClient;
use iggy::client_provider;
use iggy::client_provider::ClientProviderConfig;
use iggy::clients::client::IggyClient;
use iggy::messages::send_messages::{Message, Partitioning};
use iggy::models::header::{HeaderKey, HeaderValue};
use iggy_examples::shared::args::Args;
use iggy_examples::shared::messages_generator::MessagesGenerator;
use iggy_examples::shared::system;
use std::collections::HashMap;
use std::error::Error;
use std::str::FromStr;
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let args = Args::parse();
    tracing_subscriber::fmt::init();
    info!(
        "Message headers producer has started, selected transport: {}",
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
            let message_type = serializable_message.get_message_type();
            let json = serializable_message.to_json();

            // The message type will be stored in the custom message header.
            let mut headers = HashMap::new();
            headers.insert(
                HeaderKey::new("message_type").unwrap(),
                HeaderValue::from_str(message_type).unwrap(),
            );

            let message = Message::new(None, Bytes::from(json), Some(headers));
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
use iggy::models::header::HeaderKey;
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
        "Message headers consumer has started, selected transport: {}",
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
    let payload = std::str::from_utf8(&message.payload)?;
    // The message type is stored in the custom message header.
    let header_key = HeaderKey::new("message_type").unwrap();
    let message_type = message
        .headers
        .as_ref()
        .unwrap()
        .get(&header_key)
        .unwrap()
        .as_str()?;
    info!(
        "Handling message type: {} at offset: {}...",
        message_type, message.offset
    );
    match message_type {
        ORDER_CREATED_TYPE => {
            let order_created = serde_json::from_str::<OrderCreated>(payload)?;
            info!("{:#?}", order_created);
        }
        ORDER_CONFIRMED_TYPE => {
            let order_confirmed = serde_json::from_str::<OrderConfirmed>(payload)?;
            info!("{:#?}", order_confirmed);
        }
        ORDER_REJECTED_TYPE => {
            let order_rejected = serde_json::from_str::<OrderRejected>(payload)?;
            info!("{:#?}", order_rejected);
        }
        _ => {
            warn!("Received unknown message type: {}", message_type);
        }
    }
    Ok(())
}
```