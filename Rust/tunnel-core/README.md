# tunnel-core

Rust packet-tunnel core for Inspect.

## Current architecture

The working path is now:

1. `NEPacketTunnelProvider` in Swift configures the iOS tunnel.
2. Swift discovers the real `utun` file descriptor.
3. Swift starts this Rust core through the C ABI bridge.
4. Rust runs the forwarding plane on top of `tun2proxy`.
5. Passive TLS observations are drained back into the app and normalized as `TLSFlowObservation` / `TLSInspectionReport`.
6. Logs are written into the shared App Group container for the in-app Diagnostics view.

## What is working

- stable C ABI for the packet-tunnel extension
- shared Rust API for host-side replay and harness testing
- shared tunnel log output
- real iOS live worker against the packet-tunnel `utun` fd
- `tun2proxy`-backed forwarding engine
- direct upstream DNS on iOS (`1.1.1.1`, `8.8.8.8` configured by Swift)
- passive TLS ClientHello SNI extraction
- passive TLS certificate-chain extraction
- observation drain back into the Swift monitor pipeline
- host-side replay fixtures for:
  - synthetic ClientHello
  - fragmented ClientHello
  - synthetic certificate records from DER files
  - fragmented certificate records
  - raw packet hex files
  - classic pcap slices
- host-side `tun2proxy` harness tests for real forwarded TCP sessions
- critical-only shared logging by default, with optional verbose forwarding logs

## What is not finished

- UDP/QUIC observation and forwarding strategy beyond whatever `tun2proxy` already provides internally
- richer per-flow metadata and error reporting back to Swift
- a Swift-friendly generated bridge such as UniFFI
- macOS product integration that reuses the same Rust core directly

## Local development

```bash
cargo test --manifest-path Rust/tunnel-core/Cargo.toml
cargo build --manifest-path Rust/tunnel-core/Cargo.toml
cargo run --manifest-path Rust/tunnel-core/Cargo.toml --bin tunnel-core-replay -- fixtures/replay/sample_sni.json --pretty
cargo run --manifest-path Rust/tunnel-core/Cargo.toml --bin tunnel-core-replay -- fixtures/replay/sample_fragmented_handshake.json --pretty
cargo run --manifest-path Rust/tunnel-core/Cargo.toml --bin tunnel-core-replay -- fixtures/replay/sample_cert_chain.json --pretty
```

## Replay fixtures

Scenario fixtures live in `fixtures/replay/`.

Supported packet kinds:

- `tlsClientHello`
- `tlsClientHelloFragments`
- `tlsServerCertificate`
- `tlsServerCertificateFragments`
- `rawFile`
- `pcapFile`

Replay output includes:

- packet observations
- extracted SNI
- extracted certificate chains
- aggregate traffic stats

## Example fixture

```json
{
  "tunFd": 5,
  "config": {
    "ipv4Address": "198.18.0.1",
    "ipv6Address": "fd00::1",
    "dnsAddress": "1.1.1.1",
    "fakeIpRange": "198.19.0.0/16",
    "mtu": 1500,
    "monitorEnabled": true,
    "verboseLoggingEnabled": false
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
