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
