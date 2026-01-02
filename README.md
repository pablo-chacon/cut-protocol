
# CUT Protocol

CUT is a **minimal Ethereum protocol** for music ownership and bounded discovery.

The protocol enforces a fixed **0.5% immutable protocol fee** on **primary album copy mints**.
All other coordination, economics, and behavior (radio discovery, storage participation,
payout distribution) are handled **off-chain** and are **out of scope** for this protocol.

CUT is a protocol, not a platform.

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts implementing the CUT protocol.

The authors and contributors:

- do not operate a music service, marketplace, platform, or application
- do not curate, rank, promote, or distribute content
- do not verify or supervise artists, scenes, storage nodes, or users
- do not enforce or guarantee royalties, payouts, or off-chain economics
- do not provide legal, financial, or tax advice
- are not responsible for deployments, integrations, or real-world usage

All deployments of the CUT protocol contracts are performed **at the risk of the deployer**.

No warranty of any kind is provided.  
The smart contracts are offered strictly **as-is**, without guarantees of correctness, fitness for any purpose, availability, or security.

The authors and contributors are not liable for any damages, losses, claims, or issues arising from the use, misuse, or failure of the CUT protocol contracts or any derivative work.

By deploying or interacting with these contracts, you acknowledge and agree that all responsibility for legal compliance, operation, and outcomes lies solely with you.

---

## Protocol Finality & Immutability

**CUT Protocol is finished infrastructure.**

The core smart contracts are intentionally minimal, deterministic, and **will not be modified, upgraded, or extended**. There is no upgrade path, governance mechanism, or maintainer intervention.

CUT is provided as neutral, general-purpose settlement infrastructure. Its behavior is fully defined by the deployed code and does not depend on any individual, organization, or ongoing development.

All future innovation is expected to happen **off-chain or on top of the protocol**, without requiring changes to the protocol itself.

---

## Scope and Guarantees

The CUT protocol guarantees:

* On-chain **album creation** with fixed supply
* On-chain **ownership of album copies** (ERC-721)
* A fixed, immutable **0.5% protocol fee**
* Cryptographic commitment to off-chain radio data via a Merkle root

The CUT protocol explicitly does **not**:

* Operate a marketplace
* Custody user funds (beyond atomic settlement at mint)
* Enforce royalties beyond the protocol fee
* Enforce radio payouts or storage payouts
* Rank, curate, or promote content
* Provide identity, KYC, or discovery services
* Govern scenes, artists, or tooling behavior

---

## Repositories

- **cut-protocol**  
  This repository. Immutable on-chain contracts:
  - album minting
  - scene registry
  - protocol fee enforcement

- **[cut-tooling](https://github.com/pablo-chacon/cut-tooling)**  
  Off-chain specifications and reference tools:
  - Radio Manifest format
  - Merkle root + proof generation
  - TypeScript minting helpers
  - Verification utilities

[cut-tooling](https://github.com/pablo-chacon/cut-tooling) is optional and replaceable.  
Alternative tooling implementations are valid.

---

## CUT Economics

Primary sale economics (reference model):

* **96%** Artist / seller proceeds (off-chain convention)
* **0.5%** Protocol fee (**enforced on-chain, immutable**)
* **2%** Scene radio artists (equal split, off-chain)
* **1%** Storage nodes (equal split, off-chain)

The CUT protocol enforces **only** the 0.5% protocol fee.

All other percentages are:

* informational
* tooling-defined
* non-binding at the protocol level

---

## Prerequisites

### Solidity / Foundry

- Foundry (`forge`, `cast`)
- RPC URL for the target chain
- Deployer private key
- Treasury address (recommended: a Safe multisig)

---

## Deployment

### Environment variables

Set the following before deployment:

```bash
export PRIVATE_KEY=...
export CUT_TREASURY=0xYourSafeAddress
export RPC_URL=https://...
```

Optional:

```bash
export ALBUM_NAME="CUT Album"
export ALBUM_SYMBOL="CUT"
```

---

### Deploy contracts

From the `cut-protocol/` directory:

```bash
forge script script/DeployCUT.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

The deployment script outputs:

* `CUTSceneRegistry` address
* `CUTAlbum` address
* Configured `CUT_TREASURY`

These addresses constitute the canonical protocol deployment.

---

## Scenes

A **scene** is identified by a `bytes32 sceneId`.

Recommended derivation (off-chain tooling convention):

```
sceneId = keccak256(utf8("<scene-name>"))
```

Examples:

```
keccak256("dark-minimal-techno")
keccak256("industrial-techno")
keccak256("dub-techno")
```

### Scene existence

Before minting an album:

* the referenced `sceneId` **must exist** in `CUTSceneRegistry`

How scenes are created depends on the registry contract’s API.
Typical patterns include:

* permissionless `createScene(sceneId, metadataHash)`
* or administrative `registerScene(sceneId, ...)`

The protocol does **not**:

* define scene governance
* enforce scene membership rules
* interpret scene metadata

Scenes are namespaces only.

---

## Albums

An **album** is defined **once**, with immutable parameters and a fixed maximum supply.
Each purchase mints a **unique ERC-721 copy** referencing that album.

Album identity and ownership of copies are intentionally separated.

Album **creation** in CUT is a **two-step process**:

### 1. Album creation

An album definition includes:

* `sceneId`: namespace reference
* `radioRoot`:  Merkle root commitment to the album’s radio set
* `contentRoot`: optional commitment to off-chain album bundle metadata
* `maxSupply`: maximum number of copies that can ever be minted

This step defines the album but **does not mint any tokens**.


### 2. Album copy minting

Each purchase:

* mints a **unique ERC-721 token**
* references an existing album
* performs atomic ETH settlement
* enforces the immutable protocol fee
* increments the album’s minted supply

Once `maxSupply` is reached, no further copies can be minted.

---

## What the protocol does **not** interpret

The protocol treats all album metadata as opaque.

It does **not** interpret or enforce:

* radio manifests or track lists
* licenses or copyright terms
* artist identity
* content hosting or availability

All such semantics are handled **off-chain**.

---

## Legal and Operational Notes

* Deployers are responsible for:

  * selecting treasury addresses
  * complying with local laws
  * operating or integrating any off-chain tooling
* The protocol authors do not operate a service, marketplace, or platform.

Using CUT does not create any agency, partnership, or fiduciary relationship.

---

## Versioning and Stability

* The protocol surface is intentionally small.
* Contract behavior is designed to be stable.
* Future work is expected to happen in **tooling**, not protocol upgrades.

---

## CUT-Tooling Repository

Repository: [cut-tooling](https://github.com/pablo-chacon/cut-tooling)

---

## Author

Pablo-Chacon

Contact: [pablo-chacon-ai@proton.me](mailto:pablo-chacon-ai@proton.me)

---