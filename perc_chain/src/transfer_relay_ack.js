/**
 * Canonical relay acknowledgment: promote sender transfer blocks by stable tx.id.
 * Re-indexes to the canonical chain tip so explorers, list order, and 100M
 * microblock marker angles stay monotonic on taller seed/receiver ledgers.
 */

export function peerGenesisRevision(ledger) {
  return ledger?.networkGenesisRevision ?? 1;
}

export function peerLedgerHeight(ledger) {
  return ledger?.blocks?.length ?? 0;
}

export function collectTransferTxIds(ledger) {
  const ids = new Set();
  for (const block of ledger?.blocks ?? []) {
    for (const tx of block?.transactions ?? []) {
      if (tx?.kind === 'transfer' && tx.id) ids.add(tx.id);
    }
  }
  return ids;
}

export function blockHasTransfer(block) {
  return (block?.transactions ?? []).some((tx) => tx?.kind === 'transfer');
}

function clonePreservedBlock(block) {
  return typeof structuredClone === 'function'
    ? structuredClone(block)
    : JSON.parse(JSON.stringify(block));
}

/**
 * Clone relay transfer block onto canonical tip, preserving tx.id and payload.
 * @param {object} block
 * @param {number} canonicalIndex
 */
export function cloneTransferBlockForCanonicalTip(block, canonicalIndex) {
  const cloned = clonePreservedBlock(block);
  cloned.relaySourceBlockIndex = block.index;
  cloned.index = canonicalIndex;
  for (const tx of cloned.transactions ?? []) {
    if (tx && typeof tx === 'object') {
      tx.blockIndex = canonicalIndex;
    }
  }
  return cloned;
}

/**
 * @param {object} canonical — mutable seed or wallet ledger
 * @param {object} relay — peer relay ledger (often shorter)
 * @returns {{ acknowledged: number, ok: boolean, transferIds: string[], canonicalIndices: number[] }}
 */
export function acknowledgeRelayTransfers(canonical, relay) {
  if (!canonical || !relay || !Array.isArray(canonical.blocks)) {
    return { acknowledged: 0, ok: false, transferIds: [], canonicalIndices: [] };
  }
  if (peerGenesisRevision(canonical) !== peerGenesisRevision(relay)) {
    return { acknowledged: 0, ok: false, transferIds: [], canonicalIndices: [] };
  }

  const known = collectTransferTxIds(canonical);
  const promoted = [];
  const canonicalIndices = [];
  let acknowledged = 0;

  for (const block of relay.blocks ?? []) {
    if (!blockHasTransfer(block)) continue;
    const transferIds = (block.transactions ?? [])
      .filter((tx) => tx?.kind === 'transfer')
      .map((tx) => tx.id)
      .filter(Boolean);
    if (transferIds.length === 0) continue;
    if (transferIds.some((id) => known.has(id))) continue;

    const canonicalIndex = peerLedgerHeight(canonical);
    canonical.blocks.push(cloneTransferBlockForCanonicalTip(block, canonicalIndex));
    for (const id of transferIds) {
      known.add(id);
      promoted.push(id);
    }
    canonicalIndices.push(canonicalIndex);
    acknowledged += 1;
  }

  return {
    acknowledged,
    ok: acknowledged > 0,
    transferIds: promoted,
    canonicalIndices,
  };
}

/** @deprecated Use acknowledgeRelayTransfers */
export function mergeTransferBlocksFromPeer(local, remote) {
  const result = acknowledgeRelayTransfers(local, remote);
  return { appended: result.acknowledged, merged: result.ok };
}