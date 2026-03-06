# inspect-tunnel-core

Rust tunnel-core scaffold for Inspect.

Current status:

- exports a stable C ABI for the packet-tunnel extension
- exposes a reusable Rust core API for host-side replay tools
- persists logs to the App Group log file
- stores tunnel fd + config
- can start a live background worker against the real tunnel fd
- infers packet direction from the configured tunnel addresses
- exposes packet-analysis replay output for macOS automation
- includes a first outbound TCP connector abstraction with host-side tests

Not implemented yet:

- fake DNS pool
- full TCP packet forwarding / response injection
- UDP outbound handling
- Swift callback bridge for outbound connect/data-plane ownership
- passive TLS observations flowing back into the app UI from Rust

Target architecture:

1. `NEPacketTunnelProvider` discovers the real `utun` fd.
2. Swift bridge passes fd + config JSON into this Rust core.
3. Rust core owns:
   - fake DNS and fake-IP mapping
   - TCP/UDP forwarding
   - passive TLS observation
   - stats and structured events
4. Swift UI reads logs/events through the shared App Group.

Local development:

```bash
cargo test --manifest-path Rust/inspect-tunnel-core/Cargo.toml
cargo build --manifest-path Rust/inspect-tunnel-core/Cargo.toml
cargo run --manifest-path Rust/inspect-tunnel-core/Cargo.toml --bin inspect-tunnel-replay -- fixtures/replay/sample_sni.json --pretty
cargo run --manifest-path Rust/inspect-tunnel-core/Cargo.toml --bin inspect-tunnel-replay -- fixtures/replay/sample_fragmented_handshake.json --pretty
```

Replay harness:

- scenario fixtures live in `fixtures/replay/`
- `tlsClientHello` packets are synthesized into IPv4/TCP/TLS packets on the host
- `tlsClientHelloFragments` split one ClientHello across multiple TCP packets
- `tlsServerCertificate` packets are synthesized into inbound TLS certificate records from DER files
- `tlsServerCertificateFragments` split one certificate handshake across multiple TCP packets
- `rawFile` packets let you replay captured hex slices from disk
- `pcapFile` imports classic pcap slices (`DLT_RAW`, `DLT_EN10MB`, `DLT_NULL/LOOP`)
- output is JSON with packet observations, captured certificate chains, and aggregate stats

Live worker coverage:

- `cargo test` now exercises a real background reader loop using a host pipe as the fake tunnel fd
- outbound TCP connect requests are emitted once per observed TCP flow
- the current host implementation uses a plain `TcpStream` connector; iOS still uses a no-op connector until the Swift bridge owns outbound connections

Example:

```json
{
  "tunFd": 5,
  "config": {
    "ipv4Address": "198.18.0.1",
    "ipv6Address": "fd00::1",
    "dnsAddress": "198.18.0.2",
    "fakeIpRange": "198.18.0.0/16",
    "mtu": 1500,
    "monitorEnabled": true
  },
  "packets": [
    {
      "kind": "tlsClientHello",
      "direction": "outbound",
      "serverName": "example.com",
      "remoteHost": "93.184.216.34",
      "remotePort": 443
    },
    {
      "kind": "tlsServerCertificate",
      "direction": "inbound",
      "remoteHost": "17.248.145.12",
      "remotePort": 443,
      "certificateFiles": [
        "../certs/mac_dev.cer"
      ]
    }
  ]
}
```
