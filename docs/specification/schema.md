---
id: specification-schema
slug: /specification/schema
title: Schema
sidebar_position: 1
---

Since the Iggy server supports a variety of transport protocols, it is important to have a common schema for all of them, that will represent the data in a unified way. Commands (requests), responses, data models, status codes, must be the same for all transports.

Currently, there are 2 ways of data representation: JSON (text) and binary. The binary format is more compact and efficient, but it is not human-readable - it's being used by TCP and QUIC transports. The JSON format is used by HTTP transport.

Below you will find all the available data models - to find out more about their specific fields, (de)serialization etc. please refer to the [binary](/specification/binary) or [JSON](/specification/json) transport sections.