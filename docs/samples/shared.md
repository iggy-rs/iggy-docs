---
id: samples-shared
slug: /samples/shared
title: Shared
sidebar_position: 4
---

For the working sample, please refer to the [repository](https://github.com/iggy-rs/iggy/tree/master/examples/src/shared).

#### Initialization of the stream by the provider and validation by the consumer.

```rust title="system.rs"
use crate::shared::args::Args;
use iggy::client::Client;
use iggy::compression::compression_algorithm::CompressionAlgorithm;
use iggy::consumer::{Consumer, ConsumerKind};
use iggy::error::IggyError;
use iggy::identifier::Identifier;
use iggy::messages::poll_messages::PollingStrategy;
use iggy::models::messages::PolledMessage;
use iggy::users::defaults::*;
use iggy::utils::expiry::IggyExpiry;
use tracing::info;

type MessageHandler = dyn Fn(&PolledMessage) -> Result<(), Box<dyn std::error::Error>>;

pub async fn login_root(client: &dyn Client) {
    client
        .login_user(DEFAULT_ROOT_USERNAME, DEFAULT_ROOT_PASSWORD)
        .await
        .unwrap();
}

pub async fn init_by_consumer(args: &Args, client: &dyn Client) {
    let (stream_id, topic_id, partition_id) = (args.stream_id, args.topic_id, args.partition_id);
    let mut interval = tokio::time::interval(std::time::Duration::from_secs(1));
    loop {
        info!("Validating if stream: {} exists..", stream_id);
        let stream = client.get_stream(&args.stream_id.try_into().unwrap()).await;
        if stream.is_ok() {
            info!("Stream: {} was found.", stream_id);
            break;
        }
        interval.tick().await;
    }
    loop {
        info!("Validating if topic: {} exists..", topic_id);
        let topic = client
            .get_topic(
                &stream_id.try_into().unwrap(),
                &topic_id.try_into().unwrap(),
            )
            .await;
        if topic.is_err() {
            interval.tick().await;
            continue;
        }

        info!("Topic: {} was found.", topic_id);
        let topic = topic.unwrap();
        if topic.partitions_count >= partition_id {
            break;
        }

        panic!(
            "Topic: {} has only {} partition(s), but partition: {} was requested.",
            topic_id, topic.partitions_count, partition_id
        );
    }
}

pub async fn init_by_producer(args: &Args, client: &dyn Client) -> Result<(), IggyError> {
    let stream = client.get_stream(&args.stream_id.try_into()?).await;
    if stream.is_ok() {
        return Ok(());
    }

    info!("Stream does not exist, creating...");
    client.create_stream("sample", Some(args.stream_id)).await?;
    client
        .create_topic(
            &args.stream_id.try_into()?,
            "orders",
            args.partitions_count,
            CompressionAlgorithm::from_code(args.compression_algorithm)?,
            None,
            Some(args.topic_id),
            IggyExpiry::NeverExpire,
            None,
        )
        .await?;
    Ok(())
}

pub async fn consume_messages(
    args: &Args,
    client: &dyn Client,
    handle_message: &MessageHandler,
) -> Result<(), Box<dyn std::error::Error>> {
    info!("Messages will be polled by consumer: {} from stream: {}, topic: {}, partition: {} with interval {} ms.",
        args.consumer_id, args.stream_id, args.topic_id, args.partition_id, args.interval);

    let mut interval = tokio::time::interval(std::time::Duration::from_millis(args.interval));
    let mut consumed_batches = 0;
    let consumer = Consumer {
        kind: ConsumerKind::from_code(args.consumer_kind)?,
        id: Identifier::numeric(args.consumer_id).unwrap(),
    };
    loop {
        if args.message_batches_limit > 0 && consumed_batches == args.message_batches_limit {
            info!("Consumed {consumed_batches} batches of messages, exiting.");
            return Ok(());
        }

        let polled_messages = client
            .poll_messages(
                &args.stream_id.try_into()?,
                &args.topic_id.try_into()?,
                Some(args.partition_id),
                &consumer,
                &PollingStrategy::next(),
                args.messages_per_batch,
                true,
            )
            .await?;
        if polled_messages.messages.is_empty() {
            info!("No messages found.");
            interval.tick().await;
            continue;
        }
        consumed_batches += 1;
        for message in polled_messages.messages {
            handle_message(&message)?;
        }
        interval.tick().await;
    }
}
```

#### Sample message envelope with underlying message types using JSON serialization.

```rust title="messages.rs"
use serde::{Deserialize, Serialize};
use std::fmt::{self, Debug};

pub const ORDER_CREATED_TYPE: &str = "order_created";
pub const ORDER_CONFIRMED_TYPE: &str = "order_confirmed";
pub const ORDER_REJECTED_TYPE: &str = "order_rejected";

pub trait SerializableMessage: Debug {
    fn get_message_type(&self) -> &str;
    fn to_json(&self) -> String;
    fn to_json_envelope(&self) -> String;
}

// The message envelope can be used to send the different types of messages to the same topic.
#[derive(Debug, Deserialize, Serialize)]
pub struct Envelope {
    pub message_type: String,
    pub payload: String,
}

impl Envelope {
    pub fn new<T>(message_type: &str, payload: &T) -> Envelope
    where
        T: Serialize,
    {
        Envelope {
            message_type: message_type.to_string(),
            payload: serde_json::to_string(payload).unwrap(),
        }
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(&self).unwrap()
    }
}

#[derive(Deserialize, Serialize)]
pub struct OrderCreated {
    pub order_id: u64,
    pub currency_pair: String,
    pub price: f64,
    pub quantity: f64,
    pub side: String,
    pub timestamp: u64,
}

impl Debug for OrderCreated {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OrderCreated")
            .field("order_id", &self.order_id)
            .field("currency_pair", &self.currency_pair)
            .field("price", &format!("{:.2}", self.price))
            .field("quantity", &format!("{:.2}", self.quantity))
            .field("side", &self.side)
            .field("timestamp", &self.timestamp)
            .finish()
    }
}

#[derive(Deserialize, Serialize)]
pub struct OrderConfirmed {
    pub order_id: u64,
    pub price: f64,
    pub timestamp: u64,
}

impl Debug for OrderConfirmed {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OrderConfirmed")
            .field("order_id", &self.order_id)
            .field("price", &format!("{:.2}", self.price))
            .field("timestamp", &self.timestamp)
            .finish()
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct OrderRejected {
    pub order_id: u64,
    pub timestamp: u64,
    pub reason: String,
}

impl SerializableMessage for OrderCreated {
    fn get_message_type(&self) -> &str {
        ORDER_CREATED_TYPE
    }

    fn to_json(&self) -> String {
        serde_json::to_string(&self).unwrap()
    }

    fn to_json_envelope(&self) -> String {
        Envelope::new(ORDER_CREATED_TYPE, self).to_json()
    }
}

impl SerializableMessage for OrderConfirmed {
    fn get_message_type(&self) -> &str {
        ORDER_CONFIRMED_TYPE
    }

    fn to_json(&self) -> String {
        serde_json::to_string(&self).unwrap()
    }

    fn to_json_envelope(&self) -> String {
        Envelope::new(ORDER_CONFIRMED_TYPE, self).to_json()
    }
}

impl SerializableMessage for OrderRejected {
    fn get_message_type(&self) -> &str {
        ORDER_REJECTED_TYPE
    }

    fn to_json(&self) -> String {
        serde_json::to_string(&self).unwrap()
    }

    fn to_json_envelope(&self) -> String {
        Envelope::new(ORDER_REJECTED_TYPE, self).to_json()
    }
}
```

#### Basic messages generator to randomize the messages being sent to the stream.

```rust title="messages_generator.rs"
use crate::shared::messages::{OrderConfirmed, OrderCreated, OrderRejected, SerializableMessage};
use crate::shared::utils;
use rand::rngs::ThreadRng;
use rand::Rng;

const CURRENCY_PAIRS: &[&str] = &["EUR/USD", "EUR/GBP", "USD/GBP", "EUR/PLN", "USD/PLN"];

#[derive(Debug, Default)]
pub struct MessagesGenerator {
    order_id: u64,
    rng: ThreadRng,
}

impl MessagesGenerator {
    pub fn new() -> MessagesGenerator {
        MessagesGenerator {
            order_id: 0,
            rng: rand::thread_rng(),
        }
    }

    pub fn generate(&mut self) -> Box<dyn SerializableMessage> {
        match self.rng.gen_range(0..=2) {
            0 => self.generate_order_created(),
            1 => self.generate_order_confirmed(),
            2 => self.generate_order_rejected(),
            _ => panic!("Unexpected message type"),
        }
    }

    fn generate_order_created(&mut self) -> Box<dyn SerializableMessage> {
        self.order_id += 1;
        Box::new(OrderCreated {
            order_id: self.order_id,
            timestamp: utils::timestamp(),
            currency_pair: CURRENCY_PAIRS[self.rng.gen_range(0..CURRENCY_PAIRS.len())].to_string(),
            price: self.rng.gen_range(10.0..=1000.0),
            quantity: self.rng.gen_range(0.1..=1.0),
            side: match self.rng.gen_range(0..=1) {
                0 => "buy",
                _ => "sell",
            }
            .to_string(),
        })
    }

    fn generate_order_confirmed(&mut self) -> Box<dyn SerializableMessage> {
        Box::new(OrderConfirmed {
            order_id: self.order_id,
            timestamp: utils::timestamp(),
            price: self.rng.gen_range(10.0..=1000.0),
        })
    }

    fn generate_order_rejected(&mut self) -> Box<dyn SerializableMessage> {
        Box::new(OrderRejected {
            order_id: self.order_id,
            timestamp: utils::timestamp(),
            reason: match self.rng.gen_range(0..=1) {
                0 => "cancelled_by_user",
                _ => "other",
            }
            .to_string(),
        })
    }
}
```

#### Simple timestamp utility.

```rust title="utils.rs"
use std::time::{SystemTime, UNIX_EPOCH};

pub fn timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_micros() as u64
}
```

#### Command line arguments.

```rust title="args.rs"
use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
pub struct Args {
    #[arg(long, default_value = "0")]
    pub message_batches_limit: u64,

    #[arg(long, default_value = "iggy")]
    pub username: String,

    #[arg(long, default_value = "iggy")]
    pub password: String,

    #[arg(long, default_value = "1000")]
    pub interval: u64,

    #[arg(long, default_value = "9999")]
    pub stream_id: u32,

    #[arg(long, default_value = "1")]
    pub topic_id: u32,

    #[arg(long, default_value = "1")]
    pub partition_id: u32,

    #[arg(long, default_value = "1")]
    pub partitions_count: u32,

    #[arg(long, default_value = "1")]
    pub compression_algorithm: u8,

    #[arg(long, default_value = "1")]
    pub consumer_kind: u8,

    #[arg(long, default_value = "1")]
    pub consumer_id: u32,

    #[arg(long, default_value = "1")]
    pub messages_per_batch: u32,

    #[arg(long, default_value = "tcp")]
    pub transport: String,

    #[arg(long, default_value = "")]
    pub encryption_key: String,

    #[arg(long, default_value = "http://localhost:3000")]
    pub http_api_url: String,

    #[arg(long, default_value = "3")]
    pub http_retries: u32,

    #[arg(long, default_value = "3")]
    pub tcp_reconnection_retries: u32,

    #[arg(long, default_value = "1000")]
    pub tcp_reconnection_interval: u64,

    #[arg(long, default_value = "127.0.0.1:8090")]
    pub tcp_server_address: String,

    #[arg(long, default_value = "false")]
    pub tcp_tls_enabled: bool,

    #[arg(long, default_value = "localhost")]
    pub tcp_tls_domain: String,

    #[arg(long, default_value = "127.0.0.1:0")]
    pub quic_client_address: String,

    #[arg(long, default_value = "127.0.0.1:8080")]
    pub quic_server_address: String,

    #[arg(long, default_value = "localhost")]
    pub quic_server_name: String,

    #[arg(long, default_value = "3")]
    pub quic_reconnection_retries: u32,

    #[arg(long, default_value = "1000")]
    pub quic_reconnection_interval: u64,

    #[arg(long, default_value = "10000")]
    pub quic_max_concurrent_bidi_streams: u64,

    #[arg(long, default_value = "100000")]
    pub quic_datagram_send_buffer_size: u64,

    #[arg(long, default_value = "1200")]
    pub quic_initial_mtu: u16,

    #[arg(long, default_value = "100000")]
    pub quic_send_window: u64,

    #[arg(long, default_value = "100000")]
    pub quic_receive_window: u64,

    #[arg(long, default_value = "1048576")]
    pub quic_response_buffer_size: u64,

    #[arg(long, default_value = "5000")]
    pub quic_keep_alive_interval: u64,

    #[arg(long, default_value = "10000")]
    pub quic_max_idle_timeout: u64,

    #[arg(long, default_value = "false")]
    pub quic_validate_certificate: bool,
}

impl Args {
    pub fn to_sdk_args(&self) -> iggy::args::Args {
        iggy::args::Args {
            transport: self.transport.clone(),
            encryption_key: self.encryption_key.clone(),
            http_api_url: self.http_api_url.clone(),
            http_retries: self.http_retries,
            tcp_server_address: self.tcp_server_address.clone(),
            tcp_reconnection_retries: self.tcp_reconnection_retries,
            tcp_reconnection_interval: self.tcp_reconnection_interval,
            tcp_tls_enabled: self.tcp_tls_enabled,
            tcp_tls_domain: self.tcp_tls_domain.clone(),
            quic_client_address: self.quic_client_address.clone(),
            quic_server_address: self.quic_server_address.clone(),
            quic_server_name: self.quic_server_name.clone(),
            quic_reconnection_retries: self.quic_reconnection_retries,
            quic_reconnection_interval: self.quic_reconnection_interval,
            quic_max_concurrent_bidi_streams: self.quic_max_concurrent_bidi_streams,
            quic_datagram_send_buffer_size: self.quic_datagram_send_buffer_size,
            quic_initial_mtu: self.quic_initial_mtu,
            quic_send_window: self.quic_send_window,
            quic_receive_window: self.quic_receive_window,
            quic_response_buffer_size: self.quic_response_buffer_size,
            quic_keep_alive_interval: self.quic_keep_alive_interval,
            quic_max_idle_timeout: self.quic_max_idle_timeout,
            quic_validate_certificate: self.quic_validate_certificate,
        }
    }
}
```