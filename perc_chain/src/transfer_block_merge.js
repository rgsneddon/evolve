/**
 * Gossip transfer main-chain blocks from a peer relay ledger into a taller local
 * ledger without replacing the chain tip (seed acknowledgment path).
 */

export function peerLedgerHeight(ledger) {
  return ledger?.blocks?.length ?? 0;
}

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

function cloneBlockForMerge(block, newIndex) {
  const cloned =
    typeof structuredClone === 'function'
      ? structuredClone(block)
      : JSON.parse(JSON.stringify(block));
  cloned.index = newIndex;
  for (const tx of cloned.transactions ?? []) {
    if (tx && typeof tx === 'object') {
      tx.blockIndex = newIndex;
    }
  }
  return cloned;
}

/**
 * @param {object} local — mutable ledger object (seed or wallet)
 * @param {object} remote — peer relay ledger (may be shorter)
 * @returns {{ appended: number, merged: boolean }}
 */
export function mergeTransferBlocksFromPeer(local, remote) {
  if (!local || !remote || !Array.isArray(local.blocks)) {
    return { appended: 0, merged: false };
  }
  if (peerGenesisRevision(local) !== peerGenesisRevision(remote)) {
    return { appended: 0, merged: false };
  }

  const known = collectTransferTxIds(local);
  let appended = 0;

  for (const block of remote.blocks ?? []) {
    if (!blockHasTransfer(block)) continue;
    const transferIds = (block.transactions ?? [])
      .filter((tx) => tx?.kind === 'transfer')
      .map((tx) => tx.id)
      .filter(Boolean);
    if (transferIds.length === 0) continue;
    if (transferIds.every((id) => known.has(id))) continue;

    const newIndex = peerLedgerHeight(local);
    local.blocks.push(cloneBlockForMerge(block, newIndex));
    for (const id of transferIds) known.add(id);
    appended += 1;
  }

  return { appended, merged: appended > 0 };
}