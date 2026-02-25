
---

# CUT Protocol

CUT is a **minimal Ethereum protocol** for **digital media ownership** and **bounded discovery**.

CUT supports **any medium** (music, books, film, games, datasets, IPTV, future formats) through a single, neutral ownership primitive.

The protocol enforces a fixed **0.5% immutable protocol fee** on **primary copy mints**.
All other coordination, economics, discovery logic, storage participation, and payouts are handled **off-chain** and are **out of scope** for the protocol.

CUT is a protocol, not a platform.

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts implementing the CUT protocol.

The authors and contributors:

* do not operate a media service, marketplace, platform, or application
* do not curate, rank, promote, or distribute content
* do not verify or supervise creators, scenes, storage nodes, or users
* do not enforce or guarantee royalties, payouts, or off-chain economics
* do not provide legal, financial, or tax advice
* are not responsible for deployments, integrations, or real-world usage

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

* On-chain **release creation** with fixed supply
* On-chain **ownership of copies** (ERC-1155)
* A fixed, immutable **0.5% protocol fee**
* Cryptographic commitment to:

  * paid content inventory (`contentRoot`)
  * optional discovery inventory (`radioRoot`)
  * release artwork (`artworkHash`)

The CUT protocol explicitly does **not**:

* Operate a marketplace
* Custody user funds (beyond atomic settlement at mint)
* Enforce royalties beyond the protocol fee
* Enforce discovery payouts or storage payouts
* Rank, curate, or promote content
* Provide identity, KYC, or discovery services
* Govern scenes, creators, or tooling behavior
* Interpret media formats or licenses

---

## Repositories

* **cut-protocol**
  This repository. Immutable on-chain contracts:

  * release creation
  * copy minting
  * scene registry
  * protocol fee enforcement

* **[cut-tooling](https://github.com/pablo-chacon/cut-tooling)**
  Optional off-chain specifications and reference tools:

  * discovery (radio) manifest format
  * Merkle root + proof generation
  * TypeScript minting helpers
  * verification utilities

`cut-tooling` is optional and replaceable.
Alternative tooling implementations are valid.

---

## CUT Economics

Primary sale economics (reference model):

* **96%** Creator / seller proceeds (off-chain convention)
* **0.5%** Protocol fee (**enforced on-chain, immutable**)
* **2%** Scene discovery contributors (equal split, **off-chain**)
* **1.5%** Storage / streaming nodes (equal split, **off-chain**)

The CUT protocol enforces **only** the 0.5% protocol fee.

All other percentages are:

* informational
* tooling-defined
* non-binding at the protocol level

---

## Core Concepts

### Scenes

A **scene** is a neutral namespace identified by a `bytes32 sceneId`.

Recommended derivation (off-chain convention):

```
sceneId = keccak256(utf8("<scene-name>"))
```

Examples:

```
keccak256("dark-minimal-techno")
keccak256("independent-documentary")
keccak256("sci-fi-novels")
```

The protocol does **not**:

* define scene governance
* enforce membership rules
* interpret scene metadata

Scenes are namespaces only.

---

### Releases (Any Medium)

A **release** represents a publishable unit of **any digital medium**.

Examples:

* a music album
* a book or ebook
* a film or series season
* a game release
* a dataset
* an IPTV package

Each release is defined **once**, with immutable parameters and a fixed maximum supply.

A release includes:

* `sceneId`: namespace reference
* `mediumType`: bytes32 identifier of the medium (e.g. `keccak256("music")`)
* `contentRoot`: commitment to the paid content inventory
* `radioRoot`: optional commitment to discovery content (may be zero)
* `artworkHash`: on-chain commitment to release artwork
* `artworkURI`: optional pointer (IPFS/Arweave)
* `metadataURI`: ERC-1155 metadata URI
* `maxSupply`: maximum number of copies that can ever be minted

Release creation **does not mint any copies**.

---

### Copies (Ownership)

Each purchase mints **copies** of a release using **ERC-1155**.

* One token ID per release
* Each copy increments the minted supply
* Ownership is proven by `balanceOf(owner, releaseId) > 0`

This mirrors traditional media ownership:

> buying a CD, DVD, Blu-ray, book, or licensed digital copy

Once `maxSupply` is reached, no further copies can be minted.

---

### Artwork Commitment

Release artwork is **committed on-chain** via `artworkHash`.

This ensures:

* the artwork is part of the protocol state
* future platforms can verify authenticity
* artwork cannot be silently swapped without detection

The protocol does **not** store raw image data on-chain.

---

### Discovery (Radio)

For music-like media, releases may include a `radioRoot`:

* Merkle root commitment to a discovery or preview set
* used to prove inclusion of tracks or excerpts
* verified on-chain via Merkle proofs

Discovery semantics are **off-chain** and optional.

---

## What the Protocol Does **Not** Interpret

The protocol treats all metadata as opaque.

It does **not** interpret or enforce:

* media formats
* manifests or track lists
* licenses or copyright terms
* creator identity
* hosting or availability guarantees

All such semantics are handled **off-chain**.

---

## Deployment

### Prerequisites

* Foundry (`forge`, `cast`)
* RPC URL for target chain
* Deployer private key
* Treasury address (recommended: Safe multisig)

### Environment variables

```bash
export PRIVATE_KEY=...
export CUT_TREASURY=0xYourSafeAddress
export RPC_URL=https://...
```

### Deploy contracts

```bash
forge script script/DeployCUT.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

The deployment outputs:

* `CUTSceneRegistry` address
* `CUTMedia1155` address
* configured `CUT_TREASURY`

These addresses constitute the canonical protocol deployment.

---

## Versioning and Stability

* The protocol surface is intentionally small
* Contract behavior is deterministic and stable
* Future evolution happens in **tooling**, not protocol upgrades

---

## Author

Pablo-Chacon

Contact: [pablo-chacon-ai@proton.me](mailto:pablo-chacon-ai@proton.me)

---

