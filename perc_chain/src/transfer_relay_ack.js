/**
 * Canonical relay acknowledgment: promote sender transfer blocks by stable tx.id,
 * preserving original block index, blockIndex, timestamps, and fingerprints.
 */

export function peerGenesisRevision(ledger) {
  return ledger?.networkGenesisRevision ?? 1;
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
 * @param {object} canonical — mutable seed or wallet ledger
 * @param {object} relay — peer relay ledger (often shorter)
 * @returns {{ acknowledged: number, ok: boolean, transferIds: string[] }}
 */
export function acknowledgeRelayTransfers(canonical, relay) {
  if (!canonical || !relay || !Array.isArray(canonical.blocks)) {
    return { acknowledged: 0, ok: false, transferIds: [] };
  }
  if (peerGenesisRevision(canonical) !== peerGenesisRevision(relay)) {
    return { acknowledged: 0, ok: false, transferIds: [] };
  }

  const known = collectTransferTxIds(canonical);
  const promoted = [];
  let acknowledged = 0;

  for (const block of relay.blocks ?? []) {
    if (!blockHasTransfer(block)) continue;
    const transferIds = (block.transactions ?? [])
      .filter((tx) => tx?.kind === 'transfer')
      .map((tx) => tx.id)
      .filter(Boolean);
    if (transferIds.length === 0) continue;
    if (transferIds.every((id) => known.has(id))) continue;

    canonical.blocks.push(clonePreservedBlock(block));
    for (const id of transferIds) {
      known.add(id);
      promoted.push(id);
    }
    acknowledged += 1;
  }

  return { acknowledged, ok: acknowledged > 0, transferIds: promoted };
}

/** @deprecated Use acknowledgeRelayTransfers */
export function mergeTransferBlocksFromPeer(local, remote) {
  const result = acknowledgeRelayTransfers(local, remote);
  return { appended: result.acknowledged, merged: result.ok };
}