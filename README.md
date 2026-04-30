
---

# CUT Protocol

CUT is a **minimal Ethereum protocol** for **digital media ownership** and **bounded discovery**.

CUT supports **any medium** (music, books, film, games, datasets, IPTV, future formats) through a single, neutral ownership primitive.

The protocol enforces a fixed **0.5% immutable protocol fee** on **primary copy mints**.
All other coordination, economics, discovery logic, storage participation, and payouts are handled **off-chain** and are **out of scope** for the protocol.

CUT is a protocol, not a platform.

---

## Settlement Model

On every paid `mintReleaseCopy` call:

| Recipient | Amount |
|---|---|
| Protocol treasury | 0.5% of `priceWei` |
| `msg.sender` (caller) | 99.5% of `priceWei` |

**Proceeds go to `msg.sender` — the caller of `mintReleaseCopy` — not to the release creator address stored at creation time.**

This is intentional. CUT is a permissionless settlement primitive. Any address may call `mintReleaseCopy` on any release and receive the seller proceeds. Platforms, distributors, and tooling are responsible for:

* controlling who may initiate mints (e.g. via their own access-gated frontend or contract wrapper)
* splitting proceeds between creators, labels, and platforms (off-chain or via wrapper contracts)
* enforcing any creator payout conventions

The split between platforms, labels, and creators is **off-chain convention**, not enforced by the protocol.

Reference economic model (informational only, non-binding):

| Recipient | Amount |
|---|---|
| Protocol treasury | 0.5% (on-chain, immutable) |
| Creator / seller proceeds | ~96% (off-chain convention) |
| Scene discovery contributors | ~2% equal split (off-chain convention) |
| Storage / streaming nodes | ~1.5% equal split (off-chain convention) |

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

## Ethereum Mainnet Deployment

Official CUT protocol contract addresses:
  
- CUTSceneRegistry: 0x53526f214419b40127Da06f37D4206078fb49424
- CUTMedia1155:     0x0Aed9B8CfEC1F19a0f92F0f0a62CD49E3e16D69f
- CUT_TREASURY:     0x10EE295B53bB7c6f7Ea0A7c127718750317EA3AA

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

| Field | Description | Required |
|---|---|---|
| `sceneId` | Namespace reference | Yes — must be registered |
| `mediumType` | `bytes32` medium identifier (e.g. `keccak256("music")`) | Yes — non-zero |
| `contentRoot` | Merkle root committing to the paid content inventory | Yes — non-zero |
| `radioRoot` | Merkle root committing to discovery/preview content | No — may be zero |
| `artworkHash` | On-chain commitment to release artwork | No — may be zero |
| `artworkURI` | Optional pointer (IPFS/Arweave) | No |
| `metadataURI` | ERC-1155 metadata URI | Yes — non-empty |
| `maxSupply` | Maximum copies that can ever be minted | Yes — non-zero |

`contentRoot` is required to be non-zero. It is the canonical on-chain commitment to what buyers are purchasing. A release without a content commitment has no verifiable basis for sale.

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
* Treasury address (**strongly recommended: Safe multisig**)
* Etherscan API key (for contract verification)

### Environment variables

```bash
export PRIVATE_KEY=...
export CUT_TREASURY=0xYourSafeAddress
export RPC_URL=https://...
export ETHERSCAN_API_KEY=...
```

### Deploy and verify (mainnet)

```bash
FOUNDRY_PROFILE=mainnet forge script script/DeployCUT.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY"
```

The `mainnet` profile uses `optimizer_runs = 1_000_000`, appropriate for contracts expected to be called frequently over a long time horizon.

### Deploy without verification (testnet / local)

```bash
forge script script/DeployCUT.s.sol \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```

### Deployment output

```
=== CUT Protocol Deployment ===
CUTSceneRegistry: 0x...
CUTMedia1155:     0x...
CUT_TREASURY:     0x...
================================
Record these addresses. They are immutable.
```

Record both contract addresses and the treasury address in a permanent deployment manifest. There is no upgrade path, these addresses are canonical.

### Dependency pin

The protocol is pinned to **OpenZeppelin Contracts v5.2.0**. Install with:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0
```

Do not upgrade the dependency without re-auditing the contracts. Changing the OZ version changes the deployed bytecode.

---

## Versioning and Stability

* The protocol surface is intentionally small
* Contract behavior is deterministic and stable
* Future evolution happens in **tooling**, not protocol upgrades
* The `foundry.toml` dependency pin ensures reproducible bytecode across environments

---

## Author

Pablo-Chacon

Contact: [pablo-chacon-ai@proton.me](mailto:pablo-chacon-ai@proton.me)

---

