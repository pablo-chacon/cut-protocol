import fs from "node:fs";
import path from "node:path";
import { AbiCoder, keccak256, toUtf8Bytes } from "ethers";

// Types
type Bytes32 = `0x${string}`;

interface RadioTrack {
  trackId: Bytes32;
  uri: string;
  licenseText?: string;
  licenseHash?: Bytes32;
  sceneTag?: string;
  artistRef?: string;
}

interface RadioManifest {
  version: "cut-radio-manifest-v0";
  tracks: RadioTrack[];
}

// Guards
function assertBytes32(value: string, label: string): asserts value is Bytes32 {
  if (!/^0x[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error(`${label} is not valid bytes32: ${value}`);
  }
}

function utf8Hash(input?: string): Bytes32 {
  if (!input) return ZERO_BYTES32;
  return keccak256(toUtf8Bytes(input)) as Bytes32;
}

// Constants
const ZERO_BYTES32 = "0x" + "00".repeat(32) as Bytes32;
const abi = AbiCoder.defaultAbiCoder();

// Leaf hashing
function hashRadioLeaf(track: RadioTrack): Bytes32 {
  assertBytes32(track.trackId, "trackId");

  const uriHash = utf8Hash(track.uri);

  const licenseHash =
    track.licenseHash ??
    (track.licenseText
      ? utf8Hash(track.licenseText)
      : (() => {
          throw new Error(`Track ${track.trackId} missing licenseText or licenseHash`);
        })());

  const sceneTagHash = utf8Hash(track.sceneTag);
  const artistRefHash = utf8Hash(track.artistRef);

  const encoded = abi.encode(
    ["bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [track.trackId, uriHash, licenseHash, sceneTagHash, artistRefHash]
  );

  return keccak256(encoded) as Bytes32;
}

// Merkle tree (sorted pairs)
function buildMerkleRoot(leaves: Bytes32[]): Bytes32 {
  if (leaves.length === 0) {
    throw new Error("Cannot build Merkle tree with zero leaves");
  }

  let level = leaves.slice();

  while (level.length > 1) {
    const next: Bytes32[] = [];

    for (let i = 0; i < level.length; i += 2) {
      if (i + 1 === level.length) {
        next.push(level[i]);
      } else {
        const a = level[i];
        const b = level[i + 1];
        const [left, right] = a < b ? [a, b] : [b, a];
        next.push(keccak256(left + right.slice(2)) as Bytes32);
      }
    }

    level = next;
  }

  return level[0];
}

// Main 
function main(): void {
  const inputPath = process.argv[2];
  if (!inputPath) {
    throw new Error("Usage: ts-node merkle-root.ts <radio-manifest.json>");
  }

  const manifest: RadioManifest = JSON.parse(
    fs.readFileSync(path.resolve(inputPath), "utf8")
  );

  if (manifest.version !== "cut-radio-manifest-v0") {
    throw new Error(`Unsupported manifest version: ${manifest.version}`);
  }

  if (!manifest.tracks.length) {
    throw new Error("Manifest must contain at least one track");
  }

  const leaves = manifest.tracks.map(hashRadioLeaf);
  const root = buildMerkleRoot(leaves);

  console.log("Tracks:", leaves.length);
  console.log("Radio Merkle Root:", root);
}

// Execute
main();
