# Security Policy

## Scope

This document describes the security model, threat assumptions, and disclosure
process for the CUT protocol and its reference tooling.

CUT is a minimal, open-source protocol.
It does not operate a service, platform, or application.

---

## In-Scope Components

### cut-protocol

The following components are considered in scope for security review:

- Smart contracts in the `cut-protocol` repository
- On-chain logic related to:
  - album minting
  - scene registry
  - protocol fee enforcement
  - Merkle root storage

Security issues affecting:
- loss of funds
- unintended fee behavior
- incorrect access control
- incorrect state transitions

are considered valid security concerns.

---

### cut-tooling

The following are in scope for **best-effort review only**:

- Reference TypeScript tooling
- Merkle root and proof generation logic
- Verification helpers

Tooling is provided as reference code.
It is not production infrastructure and carries no security guarantees.

---

## Out-of-Scope Components

The following are explicitly out of scope:

- Off-chain payout logic
- Radio artist compensation
- Storage node compensation
- Discovery algorithms
- Indexers, UIs, APIs, or marketplaces
- Third-party tooling or integrations
- IPFS availability or content persistence
- Identity, licensing, or copyright enforcement
- Legal compliance of deployers or users

CUT does not verify or enforce off-chain behavior.

---

## Threat Model

CUT is designed under the following assumptions:

- The blockchain execution environment is adversarial
- Off-chain tooling may be untrusted or modified
- Users are responsible for verifying off-chain data
- No trusted operator or coordinator exists
- No governance or upgrade authority exists

CUT explicitly does not attempt to prevent:

- dishonest off-chain accounting
- incorrect or malicious tooling
- misuse of the protocol for unintended purposes
- social or economic manipulation off-chain

The protocol only guarantees what is enforced on-chain.

---

## Known Non-Goals

CUT does not aim to provide protection against:

- Rug pulls performed off-chain
- Misleading metadata or manifests
- Incorrect Merkle tree construction by third parties
- Disputes over royalties, authorship, or ownership claims
- Copyright infringement or license violations

Users and integrators are expected to perform independent verification.

---

## Responsible Disclosure

If you discover a security vulnerability in `cut-protocol`:

1. **Do not** open a public issue
2. Email the details to:

   **pablo-chacon-ai@proton.me**

Please include:
- a clear description of the issue
- affected contract or file
- steps to reproduce
- potential impact

Reasonable time will be given to assess and respond before any public disclosure.

---

## Bug Bounties

There is currently **no formal bug bounty program**.

Security reports are appreciated but do not imply compensation.

---

## Disclaimer

The CUT protocol and tooling are provided **as-is**, without warranty of any kind.

The authors and contributors:

- do not operate a service
- do not custody funds
- do not guarantee correctness of third-party tooling
- are not responsible for deployments or integrations

Use at your own risk.

---

## Final Note

CUT’s security model is intentionally minimal.

If something is not enforced on-chain, it is not guaranteed by the protocol.
