# iSponsorBlockTV

To perform initial setup:

```
podman run -it -v "$( podman volume inspect systemd-isponsorblocktv | jq -r '.[0].Mountpoint' ):/app/data" ghcr.io/dmunozv04/isponsorblocktv --setup-cli
```

The service must have been started at least once for the volume to be created.
