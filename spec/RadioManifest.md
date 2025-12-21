# CUT Radio Manifest Specification

This spec defines the canonical off-chain format for a CUT Album "radio field" and
the exact hashing rules used to produce the on-chain `radioRoot` Merkle commitment.

The intent is:
- bounded discovery (finite set)
- verifiable membership
- no on-chain storage of the entire list
- no ambiguity in hashing/encoding

## Manifest JSON Format

A RadioManifest is a JSON object:

```json
{
  "version": "cut-radio-manifest-v0",
  "albumIdHint": "string",
  "sceneIdHint": "string",
  "tracks": [
    {
      "trackId": "0x<32-byte hex>",
      "uri": "ipfs://<CID>/track.flac",
      "licenseText": "plain text license",
      "licenseHash": "0x<32-byte hex>",
      "sceneTag": "string tag",
      "artistRef": "string ref (DID/ENS/handle)"
    }
  ]
}
