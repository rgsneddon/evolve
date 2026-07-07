import {
  cloneTransferBlockForCanonicalTip,
  peerLedgerHeight,
} from './transfer_relay_ack.js';

const TREASURY_USERNAME = process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury';

export const TREASURY_PAYOUT_KINDS = new Set(['scenarioReward', 'stakingReward']);

function cloneBlock(block) {
  return typeof structuredClone === 'function'
    ? structuredClone(block)
    : JSON.parse(JSON.stringify(block));
}

function blockHasTreasuryPayout(block) {
  return (block?.transactions ?? []).some((tx) => TREASURY_PAYOUT_KINDS.has(tx?.kind));
}

export function collectTreasuryPayoutTxIds(ledger) {
  const ids = new Set();
  for (const block of ledger?.blocks ?? []) {
    for (const tx of block?.transactions ?? []) {
      if (TREASURY_PAYOUT_KINDS.has(tx?.kind) && tx.id) ids.add(tx.id);
    }
  }
  return ids;
}

function payoutRecipientsForIds(remote, payoutIds) {
  const recipients = new Set();
  const wanted = new Set(payoutIds);
  for (const block of remote?.blocks ?? []) {
    for (const tx of block?.transactions ?? []) {
      if (!wanted.has(tx?.id)) continue;
      if (!TREASURY_PAYOUT_KINDS.has(tx?.kind)) continue;
      const to = tx.toUsername ?? tx.to;
      if (to && to !== TREASURY_USERNAME) recipients.add(to);
    }
  }
  return recipients;
}

/**
 * Promote scenario/staking payout blocks from a peer onto the canonical seed ledger.
 */
export function mergeTreasuryPayoutBlocksFromPeer(canonical, remote) {
  if (!canonical || !remote || !Array.isArray(canonical.blocks)) {
    return { merged: 0, payoutIds: [] };
  }

  const known = collectTreasuryPayoutTxIds(canonical);
  const payoutIds = [];
  let merged = 0;

  for (const block of remote.blocks ?? []) {
    if (!blockHasTreasuryPayout(block)) continue;
    const ids = (block.transactions ?? [])
      .filter((tx) => TREASURY_PAYOUT_KINDS.has(tx?.kind))
      .map((tx) => tx.id)
      .filter(Boolean);
    if (ids.length === 0 || ids.every((id) => known.has(id))) continue;

    const canonicalIndex = peerLedgerHeight(canonical);
    canonical.blocks.push(cloneTransferBlockForCanonicalTip(block, canonicalIndex));
    for (const id of ids) known.add(id);
    payoutIds.push(...ids);
    merged += 1;
  }

  return { merged, payoutIds };
}

/**
 * Merge wallet accounts that received treasury-funded payouts on the peer ledger.
 */
export function mergePayoutRecipientAccountsFromPeer(canonical, remote, payoutIds) {
  if (!canonical || !remote || !payoutIds?.length) return 0;

  const recipients = payoutRecipientsForIds(remote, payoutIds);
  if (recipients.size === 0) return 0;

  canonical.accounts = canonical.accounts ?? {};
  let merged = 0;

  for (const username of recipients) {
    const remoteAcc = remote.accounts?.[username];
    if (!remoteAcc?.balance) continue;

    const local = canonical.accounts[username] ?? {
      username,
      passwordHash: remoteAcc.passwordHash ?? '',
      salt: remoteAcc.salt ?? '',
      address: remoteAcc.address ?? '',
      passwordSet: remoteAcc.passwordSet ?? false,
      balance: { microUnits: 0 },
      cumulativeStakingEarned: { microUnits: 0 },
      transactions: [],
    };

    canonical.accounts[username] = {
      ...local,
      ...remoteAcc,
      username,
      balance: cloneBlock(remoteAcc.balance),
      cumulativeStakingEarned: remoteAcc.cumulativeStakingEarned
        ? cloneBlock(remoteAcc.cumulativeStakingEarned)
        : local.cumulativeStakingEarned,
    };
    merged += 1;
  }

  return merged;
}

function isRemoteScenarioNewer(canonical, remote) {
  const remoteAt = remote?.lastScenarioAt;
  const localAt = canonical?.lastScenarioAt;
  if (!remoteAt) return false;
  if (!localAt) return true;
  return new Date(remoteAt).getTime() > new Date(localAt).getTime();
}

/**
 * Sync evolve_treasury balance and cumulative counters from a peer gossip ledger.
 */
export function mergeTreasuryAccountFromPeer(
  canonical,
  remote,
  treasuryUsername = TREASURY_USERNAME,
) {
  const remoteTreasury = remote?.accounts?.[treasuryUsername];
  if (!remoteTreasury?.balance) return false;

  canonical.accounts = canonical.accounts ?? {};
  const local = canonical.accounts[treasuryUsername] ?? {
    username: treasuryUsername,
    balance: { microUnits: 0 },
  };

  canonical.accounts[treasuryUsername] = {
    ...local,
    ...remoteTreasury,
    balance: cloneBlock(remoteTreasury.balance),
    cumulativeStakingEarned:
      remoteTreasury.cumulativeStakingEarned ?? local.cumulativeStakingEarned,
  };

  if (remote.cumulativeTreasuryMinted) {
    canonical.cumulativeTreasuryMinted = cloneBlock(remote.cumulativeTreasuryMinted);
  }
  if (remote.cumulativeBurnedPerc) {
    canonical.cumulativeBurnedPerc = cloneBlock(remote.cumulativeBurnedPerc);
  }
  if (remote.lastScenarioAt) {
    canonical.lastScenarioAt = remote.lastScenarioAt;
  }

  return true;
}

/**
 * Merge treasury payout blocks, recipient credits, and treasury account truth.
 */
export function mergeTreasuryStateFromPeer(canonical, remote) {
  const payout = mergeTreasuryPayoutBlocksFromPeer(canonical, remote);
  const recipientsMerged =
    payout.payoutIds.length > 0
      ? mergePayoutRecipientAccountsFromPeer(canonical, remote, payout.payoutIds)
      : 0;
  const shouldSyncTreasury =
    payout.merged > 0 || isRemoteScenarioNewer(canonical, remote);
  const accountSynced = shouldSyncTreasury
    ? mergeTreasuryAccountFromPeer(canonical, remote)
    : false;

  return {
    payoutBlocksMerged: payout.merged,
    payoutIds: payout.payoutIds,
    recipientsMerged,
    accountSynced,
    merged: payout.merged > 0 || accountSynced || recipientsMerged > 0,
  };
}