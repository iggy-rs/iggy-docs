---
title: Users and permissions
slug: users-and-permissions
authors:
  - name: Piotr Gankiewicz
    title: Iggy.rs founder
    url: https://github.com/spetz
    image_url: https://github.com/spetz.png
tags: [new-features, users, permissions]
hide_table_of_contents: false
---

In the most recent update, the Iggy server as well as the clients for all the available transport protocols have been extended with the support for **users and permissions**. From now on, you can additionally secure your data using the authentication and authorization by specifying the granular set of permissions for each user.

<!--truncate-->

## Breaking changes

In general, there are no breaking changes, except a new field added to the `ClientInfo` and `ClientInfoDetails` structs returned by `get_client()` and `get_clients()` methods.

```rust
pub struct ClientInfo {
    pub client_id: u32,
    pub user_id: Option<u32>, // New optional field
    pub address: String,
    pub transport: String,
    pub consumer_groups_count: u32,
}
```

The `user_id` field is optional, and it's only returned when the user is authenticated. Otherwise, it's set to `None` (0 value for binary transport) or `null` (HTTP transport).

Keep in mind that the `client` represents the application connected to the server - since it's possible that multiple applications would share the same user credentials, thus you can think of a `client` as a single connection from the application to the server (1 user -> N clients).

This breaking change has been introduced with the commit [#23b3309](https://github.com/iggy-rs/iggy/commit/23b330928aa38463ef907c95a9f672fa7b728881). The available [iggy crate](https://crates.io/crates/iggy) supports these changes since version 0.0.80.

## Configuration

Currently, the authentication and authorization can be enabled in the `server.toml` configuration via `[system.user]` section:

```toml
[system.user]
authentication_enabled = true
authorization_enabled = true
```

This might change in the future releases (e.g. authentication and authorization will always be enabled), but in order to avoid the breaking changes to the existing clients SDKs, these options are configurable for now.

The additional settings for HTTP API which uses JWT (JSON Web Token), can be found in the `[http.jwt]` section:

```toml
[http.jwt]
algorithm = "HS256"
audience = "iggy.rs"
expiry = 3600
encoding_secret = "top_secret$iggy.rs$_jwt_HS256_key#!"
decoding_secret = "top_secret$iggy.rs$_jwt_HS256_key#!"
use_base64_secret = false
```

## Authentication and authorization

The overall implementation of the users authentication and authorization is rather typical. All the server methods except `ping` and `login` require the user to be authenticated. The `login` method is used to authenticate the user, and it returns the optional `token` which is then used to authenticate the user in the subsequent requests. For now, the `token` is only used by HTTP API based on JWT, for the binary transport there's no token - since, it's a stateful protocol, the server keeps track of the authenticated connections.

The authorization is based on the permissions, which are defined for each user. All the server methods have the specific authorization policies applied. For example, you can allow the user to read all the streams, or manage all the topics, while on the other hand, you could also specify only the set of particular streams or topics to which the user can send and/or poll the message to/from.

Take a look at the following JSON example to get the overall idea:

```json
{
  "permissions": {
    "global": {
      "manage_servers": false,
      "read_servers": true,
      "manage_users": true,
      "read_users": true,
      "manage_streams": false,
      "read_streams": true,
      "manage_topics": false,
      "read_topics": true,
      "poll_messages": true,
      "send_messages": true
    },
    "streams": {
      "1": {
        "manage_stream": false,
        "read_stream": true,
        "manage_topics": false,
        "read_topics": true,
        "poll_messages": true,
        "send_messages": true,
        "topics": {
          "1": {
            "manage_topic": false,
            "read_topic": true,
            "poll_messages": true,
            "send_messages": true
          }
        }
      }
    }
  }
}
```

Each user might have the global permissions which do apply to all the available streams and topics, as well as the granular permissions for each stream and its topics (this is a simple hashmap using the stream or topic ID as its key).

For example, the `root user`, which has the default username and password `iggy` and cannot be updated or deleted, can do everything, simply by having the following permissions:

```json
{
  "permissions": {
    "global": {
      "manage_servers": true,
      "read_servers": true,
      "manage_users": true,
      "read_users": true,
      "manage_streams": true,
      "read_streams": true,
      "manage_topics": true,
      "read_topics": true,
      "poll_messages": true,
      "send_messages": true
    },
    "streams": null
  }
}
```

## SDK

The new `UserClient` trait has been added in order to support the users and permissions feature. It is implemented for all the available transport protocols.

```rust
pub trait UserClient {
    async fn get_user(&self, command: &GetUser) -> Result<UserInfoDetails, Error>;
    async fn get_users(&self, command: &GetUsers) -> Result<Vec<UserInfo>, Error>;
    async fn create_user(&self, command: &CreateUser) -> Result<(), Error>;
    async fn delete_user(&self, command: &DeleteUser) -> Result<(), Error>;
    async fn update_user(&self, command: &UpdateUser) -> Result<(), Error>;
    async fn update_permissions(&self, command: &UpdatePermissions) -> Result<(), Error>;
    async fn change_password(&self, command: &ChangePassword) -> Result<(), Error>;
    async fn login_user(&self, command: &LoginUser) -> Result<IdentityInfo, Error>;
    async fn logout_user(&self, command: &LogoutUser) -> Result<(), Error>;
}
```

## Commands and models

The following commands and response models have been added:

```rust
pub struct IdentityInfo {
    pub user_id: u32,
    pub token: Option<String>,
}
```

```rust
pub struct UserInfo {
    pub id: u32,
    pub created_at: u64,
    pub status: UserStatus,
    pub username: String,
}

pub struct UserInfoDetails {
    pub id: u32,
    pub created_at: u64,
    pub status: UserStatus,
    pub username: String,
    pub permissions: Option<Permissions>,
}
```

```rust
pub struct Permissions {
    pub global: GlobalPermissions,
    pub streams: Option<HashMap<u32, StreamPermissions>>,
}

pub struct GlobalPermissions {
    pub manage_servers: bool,
    pub read_servers: bool,
    pub manage_users: bool,
    pub read_users: bool,
    pub manage_streams: bool,
    pub read_streams: bool,
    pub manage_topics: bool,
    pub read_topics: bool,
    pub poll_messages: bool,
    pub send_messages: bool,
}

pub struct StreamPermissions {
    pub manage_stream: bool,
    pub read_stream: bool,
    pub manage_topics: bool,
    pub read_topics: bool,
    pub poll_messages: bool,
    pub send_messages: bool,
    pub topics: Option<HashMap<u32, TopicPermissions>>,
}

pub struct TopicPermissions {
    pub manage_topic: bool,
    pub read_topic: bool,
    pub poll_messages: bool,
    pub send_messages: bool,
}
```

```rust
pub struct GetUser {
    pub user_id: Identifier,
}
```

```rust
pub struct GetUsers {}
```

```rust
pub struct CreateUser {
    pub username: String,
    pub password: String,
    pub status: UserStatus,
    pub permissions: Option<Permissions>,
}
```

```rust
pub struct DeleteUser {
    pub user_id: Identifier,
}
```

```rust
pub struct UpdateUser {
    pub user_id: Identifier,
    pub username: Option<String>,
    pub status: Option<UserStatus>,
}
```

```rust
pub struct UpdatePermissions {
    pub user_id: Identifier,
    pub permissions: Option<Permissions>,
}
```

```rust
pub struct ChangePassword {
    pub user_id: Identifier,
    pub current_password: String,
    pub new_password: String,
}
```

```rust
pub struct LoginUser {
    pub username: String,
    pub password: String,
}
```

```rust
pub struct LogoutUser {}
```

Similar to the stream and topic ID, the user will always have the unique numeric ID and the username. The username must be within the range of 3–50 chars and will always be lowercased, using the same regex as the stream and topic name `^[\w\.\-\s]+$`. The password must be within the range of 3–100 chars and will be hashed using the bcrypt algorithm.

## HTTP API

The following endpoints have been added, and as always, you can find them in the `server.http` file in the main repository.

```
POST {{url}}/users/login
Content-Type: application/json

{
  "username": "iggy",
  "password": "iggy"
}

POST {{url}}/users/logout
Authorization: Bearer {{token}}
Content-Type: application/json

{
}

POST {{url}}/users
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "username": "user1",
  "password": "secret",
  "status": "active",
  "permissions": null
}

GET {{url}}/users
Authorization: Bearer {{token}}

GET {{url}}/users/user1
Authorization: Bearer {{token}}

PUT {{url}}/users/user1
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "username": "user1,
  "status": "active",
  "permissions": null
}

PUT {{url}}/users/user1/password
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "current_password": "secret",
  "new_password": "secret1"
}

PUT {{url}}/users/user1permissions
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "permissions": {
    "global": {
      "manage_servers": false,
      "read_servers": true,
      "manage_users": true,
      "read_users": true,
      "manage_streams": false,
      "read_streams": true,
      "manage_topics": false,
      "read_topics": true,
      "poll_messages": true,
      "send_messages": true
    },
    "streams": {
      "1": {
        "manage_stream": false,
        "read_stream": true,
        "manage_topics": false,
        "read_topics": true,
        "poll_messages": true,
        "send_messages": true,
        "topics": {
          "1": {
            "manage_topic": false,
            "read_topic": true,
            "poll_messages": true,
            "send_messages": true
          }
        }
      }
    }
  }
}

DELETE {{url}}/users/user1
Authorization: Bearer {{token}}
```