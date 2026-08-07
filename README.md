# FreeSWITCH Workshop

This is a lab-style image for the FreeSWITCH workshop. It is built around Docker for ease of use.

The configuration folder is mounted to the Docker container for ease of access.

Current target: **FreeSWITCH 1.11.x** (Community packages) on **Debian 13 "trixie"**.

## Building

You need a SignalWire account to download the packages. It is free to sign up. Create a
Personal Access Token from your SignalWire Space under *Personal Access Tokens*, and note
that current tokens are prefixed `pat_`. See
[Installing FreeSWITCH](https://developer.signalwire.com/freeswitch/foundations/getting-started/)
for the upstream instructions.

Add that to your `.env` file.

## Starting FreeSWITCH

Install Docker (Compose v2 ships with it), copy `env.example` to `.env` and set a password
and your token.

Then run:

```
docker compose build
docker compose up -d
```

The token is passed to the build as a **build secret**, not a build argument, so it never
ends up in an image layer. Compose reads it from the `SIGNALWIRE_TOKEN` environment
variable, so either export it yourself or use the bundled wrapper, which sources `.env`
for you:

```
./docker-env build
./docker-env up -d
```

Wait for FreeSWITCH to spin up, then run `docker compose exec freeswitch bash` to access
the container shell. The familiar `fs_cli` command will be available from there.

### Networking

`docker-compose.yml` uses `network_mode: host`. For a SIP/RTP server on Linux this is the
only sane option: it avoids proxying the whole RTP range through userland and keeps the
addresses FreeSWITCH advertises in SDP correct.

On Docker Desktop for macOS or Windows, host networking joins the Linux VM's namespace
rather than your machine's, so it buys nothing. Which variant you want depends on the
direction your traffic flows.

**Outbound-initiated work — mod_signalwire, SIP trunks (macOS).** Use the overlay:

```
docker compose -f docker-compose.yml -f docker-compose-mac.yml up -d
```

This is enough for the SignalWire connector, because every flow starts from inside: the
TLS registration goes out to SignalWire, and inbound INVITEs ride back down that same
connection. No ports need publishing, and no public IP is required. Verified working on
Docker Desktop end to end - an inbound DID reaches the dialplan and echoes with two-way
audio, because SignalWire latches onto the outbound RTP stream.

Copy it to `docker-compose.override.yml` if you would rather it apply automatically;
that filename is gitignored precisely so it stays a per-machine choice.

**Accepting unsolicited inbound SIP (macOS).** If you need real SIP phones to register
from the host, you need published ports:

```
docker compose -f docker-compose-ports.yml up -d
```

Expect trouble here. NAT between the host and the VM rewrites the addresses FreeSWITCH
advertises in SDP, and one-way audio is the usual result. For that job, use Linux.

### Ports

| Port          | Purpose                        |
| ------------- | ------------------------------ |
| 5060          | internal SIP (TCP/UDP)         |
| 5061          | internal SIP TLS               |
| 5080          | external SIP (TCP/UDP)         |
| 5081          | external SIP TLS               |
| 7443          | mod_sofia WSS                  |
| 8021          | mod_event_socket / `fs_cli`    |
| 8081 / 8082   | mod_verto WS / WSS             |
| 16384-16584   | RTP (UDP)                      |

The RTP range is narrowed from the FreeSWITCH default of 16384-32768 in
`conf/autoload_configs/switch.conf.xml` so that it can be published through Docker without
a multi-minute startup. Raise both together if you need more than ~100 concurrent calls.

### TLS certificates

Self-signed certificates are generated into `conf/tls/` on first start by
`build/docker-entrypoint.sh`. They are gitignored — do not commit private keys. If you
mount real certificates at `/letsencrypt/certs/{fullchain,privkey}.pem`, the entrypoint
installs those instead.

### The WebRTC client

`client/index.html` is a standalone mod_verto demo. Open it directly in a browser and
point it at your FreeSWITCH host on port 8082 (WSS). It bundles
`@signalwire/js@1.5.1-rc.5`, the last SDK line that ships the `Verto` class — the current
4.x SDK is a rewrite and is **not** compatible with this demo.

### Building from source

`Dockerfile.source` builds FreeSWITCH from git instead of installing packages. It pins
`v1.11.1`; override with `--build-arg FS_VERSION=master`. It uses the same
`--prefix=/usr --sysconfdir=/etc` layout as the Debian packages, so the `./conf` bind mount
works identically. A token is still needed, but only to reach the `deb-src` repo for
`apt-get build-dep`.

Enabled modules are listed in `build/modules.conf`.

### Notes

The Docker images are meant to be used on a non-firewalled machine running Docker on Linux.

The authenticated FreeSWITCH apt repo is removed from the image after installation so the
token cannot leak. If you need to install more FreeSWITCH packages inside a running
container, re-add it with:

```
curl -sSL https://freeswitch.org/fsget | bash -s $SIGNALWIRE_TOKEN release
```
