# Inspect

[![CI](https://github.com/hewigovens/inspect/actions/workflows/ci.yml/badge.svg)](https://github.com/hewigovens/inspect/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-BSL--1.1-green.svg)](#license)
[![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hewigovens/inspect)

A TLS certificate inspector for iPhone, iPad, and macOS.

- Inspect a host name or HTTPS URL directly in the app
- Open Inspect Certificate from Safari on iPhone, iPad, and macOS
- Capture the presented trust chain from a live TLS handshake
- Decode X.509 fields including SANs, EKUs, key usage, AIA, SKI/AKI, policies, fingerprints, and public key details
- Surface security findings for trust failures, hostname mismatch, expired certificates, weak crypto, suspicious CA usage, and common interception products
- Export DER certificates from the chain
- Passive live monitoring through the packet tunnel flow

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

BSL 1.1 — free to use, modify, and redistribute; paid app store distribution requires permission. Converts to Apache-2.0 on 2030-03-23. See [LICENSE](LICENSE).
