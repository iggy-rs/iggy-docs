---
title: Message expiry
slug: message-expiry
authors:
  - name: Piotr Gankiewicz
    title: Iggy.rs founder
    url: https://github.com/spetz
    image_url: https://github.com/spetz.png
tags: [new-features, message-expiry]
hide_table_of_contents: false
---

The message expiration is a server-side feature, allowing to automatically delete the old data (expired segment as a whole) depending on the provided configuration. By specifying the custom retention policy, the server can clean up no longer needed messages, which can help with the disk space management.

<!--truncate-->

## Breaking changes

No breaking changes have been introduced with this feature. The only breaking changes are related to the updated `CreateTopic`, `CreateStream` commands and `Stream` + `Topic` responses, which have been introduced in the latest commit [#ea3bf9c](https://github.com/iggy-rs/iggy/commit/ea3bf9c16dd5f93e1c80c140e9e1d14cfa70f570). The available [iggy crate](https://crates.io/crates/iggy) supports these changes since version 0.0.50.

## Introduction

The expiration policy is defined per topic, and it's being set when creating the topic. The value can be either provided via server configuration file, or via `CreateTopic` command. If the expiration is set in the configuration, it will be used as a default value for all the topics, unless when explicitly set when creating the topic via available `message_expiry` field.

The expiration policy is defined as `u32` value, which is the number of seconds after which the message should be marked as expired. 

For example, the value of 604800 represents 1 week (60 \* 60 \* 24 \* 7) - after this time, the messages will be marked as expired, and the whole segment will be deleted, as long as all the messages in this segment are expired. 

If there are still some messages which are not expired, the segment will be kept on the disk. By default, the new segment is automatically created when the previous one is full - either, it has reached the maximum size (defined by `size_bytes` property) or the currently stored messages have been expired, based on the current server timestamp and configured expiry value.

Setting the `message_expiry` to 0 disables the message expiry feature, meaning that the data will be kept forever, unless deleted manually.

## Configuration

```toml
[message_cleaner]
enabled = true
interval = 60

[system.segment]
message_expiry = 0
```

### Message cleaner

The optional component, running in the background, responsible for validating and removing, the expired messages. The whole segment will be removed, when all the messages in this segment are expired. If the `enabled` is set to false, the message cleaner will be disabled, meaning that even if the `message_expiry` is set, the expired messages will not be removed.

### Segment

The `message_expiry` option in the `segment` section of the configuration file specifies the number of seconds after which the message will be marked as expired - this is the default value that will be applied to all the topics, unless overridden when creating the topic via API. If the `message_expiry` is set to 0, then the message expiry is disabled.


## Commands

```rust
pub struct CreateTopic {
    pub stream_id: Identifier,
    pub topic_id: u32,
    pub partitions_count: u32,
    pub message_expiry: Option<u32>,
    pub name: String
}
```

The `message_expiry` field has been added to the `CreateTopic` command, which allows overriding the default value set in the configuration file. If the `message_expiry` is set to None (serialized as 0 value on the binary level), then the message expiry is disabled.

```rust
fn as_bytes(&self) -> Vec<u8> {
    let stream_id_bytes = self.stream_id.as_bytes();
    let mut bytes = Vec::with_capacity(13 + stream_id_bytes.len() + self.name.len());
    bytes.extend(stream_id_bytes);
    bytes.put_u32_le(self.topic_id);
    bytes.put_u32_le(self.partitions_count);
    match self.message_expiry {
        Some(message_expiry) => bytes.put_u32_le(message_expiry),
        None => bytes.put_u32_le(0),
    }
    bytes.put_u8(self.name.len() as u8);
    bytes.extend(self.name.as_bytes());
    bytes
}
```


Additionally, the `name_length` field has been added to the binary serialization of the `CreateTopic` and `CreateStream` commands, which allows specifying the length of the name - it should be serialized as `u8` value, before the actual name, with a maximum length of 255 characters. 

The following **regex** is used to validate the topic and stream names: `^[\w\.\-\s]+$`. The name will always be lowercased, and the whitespace will be trimmed and then replaced with the `.` character. The following rule applies to all the resources that contain the name field.

Also, the `Topic` and `TopicDetails` returned when fetching the topic(s), have been extended with the `message_expiry` field, and the `name_length` has changed value from `u32 to `u8` (1 byte instead of 4 bytes). 

Serialization:

```
Topic ID (4 bytes) + Partitions count (4 bytes) + Message expiry (4 bytes) + Size (8 bytes) + Messages count (8 bytes) + Name length (1 byte) + Name (`Name length` bytes)
```

The same changes (`name_length`) apply to the `Stream` and `StreamDetails` structs.

```
Stream ID (4 bytes) + Topics count (4 bytes) + Size (8 bytes) + Messages count (8 bytes) + Name length (1 byte) + Name (`Name length` bytes)
```