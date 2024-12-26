---
id: server-docker
slug: /server/docker
title: Docker
sidebar_position: 3
---

You can easily run the Iggy server with Docker - the official images can be found [here](https://hub.docker.com/r/iggyrs/iggy), simply type `docker pull iggyrs/iggy`.

Below is an example of the `docker-compose.yml` file which additionally overrides the default configuration (described in the section below) with the environment variables. If you prefer using the configuration file, you can mount it as a volume and provide the path to it with the `IGGY_CONFIG_PATH` environment variable.

```yaml
iggy:
  image: iggyrs/iggy:latest
  container_name: iggy
  restart: unless-stopped
  environment:
    - IGGY_ROOT_USERNAME=iggy
    - IGGY_ROOT_PASSWORD=Secret123!
    - IGGY_HTTP_ENABLED=true
    - IGGY_HTTP_ADDRESS=0.0.0.0:80
    - IGGY_TCP_ENABLED=true
    - IGGY_TCP_ADDRESS=0.0.0.0:3000
    - IGGY_QUIC_ENABLED=false
    - IGGY_HEARTBEAT_ENABLED=true
    - IGGY_HEARTBEAT_INTERVAL=5s
  ports:
    - "3010:80"
    - "5100:3000"
  networks:
    - iggy
  volumes:
    - iggy:/iggy/local_data

networks:
  iggy:

volumes:
  iggy:
```
