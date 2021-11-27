# Home Lab

## Environment

The `TZ` variable is expected to be set in the environment running
`docker-compose`.

Sensitive values are stored in the `.env` file, which is explicitly ignored by
Git. Values that are expected in this file are,

```
VOLUME_ROOT=<path to docker volumes>
PIHOLE_WEBPASSWORD=
PIHOLE_ServerIP=
PIHOLE_ADMIN_EMAIL=
PIHOLE_PIHOLE_DNS_=
SOLAREDGE_API_KEY=
OPENWEATHER_CITY=
OPENWEATHER_APIKEY=
```

## Networking

As I add services to my home lab, the liklihood of multiple services choosing
to use the same port increases. Even if I configure the exposed ports to be
different (although reverse proxying will fix that in the future), there will
be conflict on the internal Docker networks.

To solve this problem, different groups of services can be run on different
Docker networks. I currently have three networks set up. Primarily, this
allows me to run the zwavejs2mqtt service, which defaults to the same port as
Grafana (3000), and allow Home Assistant to communicate with its websocket
port.

For the logging configuration, the logs are now forwarded to the Loki port
exposed on the Docker host, instead of using the internal networking.

The configuration isn't complete yet and the ports are still sloppy, but it
works for the moment.

Eventually, I will probably set up a reverse proxy to make each service easier
to access from a single UI.

- front-end
  - homer
  - home-assistant
  - pihole
  - grafana
  - mealie
- automation
  - home-assistant
  - zwavejs2mqtt
- logging
  - grafana
  - loki
  - prometheus
  - prometheus-solaredge-exporter
  - prometheus-openweather-exporter
