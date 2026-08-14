import crypto from 'crypto';
import {
  cloneTransferBlockForCanonicalTip,
  peerLedgerHeight,
} from './transfer_relay_ack.js';

const TREASURY_USERNAME = process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury';

export const TREASURY_PAYOUT_KINDS = new Set([
  'scenarioReward',
  'minerReward',
  'stakingReward',
]);

const POOL_MINER_USERNAME =
  process.env.PERC_POOL_MINER_USERNAME ??
  'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
const SEED_USERNAME = process.env.PERC_SEED_USERNAME ?? 'evolve_seed_node';

function cloneBlock(block) {
  return typeof structuredClone === 'function'
    ? structuredClone(block)
    : JSON.parse(JSON.stringify(block));
}

function microUnits(amount) {
  return amount?.microUnits ?? 0;
}

function addMicro(balance, delta) {
  return { microUnits: microUnits(balance) + delta };
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

function findPayoutTx(remote, payoutId, canonical) {
  for (const ledger of [remote, canonical]) {
    for (const block of ledger?.blocks ?? []) {
      for (const tx of block?.transactions ?? []) {
        if (tx?.id === payoutId && TREASURY_PAYOUT_KINDS.has(tx?.kind)) return tx;
      }
    }
  }
  return null;
}

function resolveIdentity(canonical, identity) {
  if (!identity) return identity;
  if (canonical?.accounts?.[identity]) return identity;
  for (const [name, acc] of Object.entries(canonical?.accounts ?? {})) {
    if (acc?.address === identity) return name;
  }
  return identity;
}

function isPayableAccount(name, acc) {
  if (!acc || name === TREASURY_USERNAME || name === SEED_USERNAME) return false;
  if (acc.passwordSet) return true;
  if (acc.lastFaucetDrawAt) return true;
  if (microUnits(acc.balance) > 0) return true;
  if (microUnits(acc.cumulativeStakingEarned) > 0) return true;
  if ((acc.transactions ?? []).length > 0) return true;
  return false;
}

function scenarioMirrorNames(canonical, initiator) {
  const names = new Set();
  for (const [name, acc] of Object.entries(canonical?.accounts ?? {})) {
    if (isPayableAccount(name, acc)) names.add(name);
  }
  if (initiator && initiator !== TREASURY_USERNAME && initiator !== SEED_USERNAME) {
    names.add(initiator);
  }
  if (POOL_MINER_USERNAME && POOL_MINER_USERNAME !== TREASURY_USERNAME) {
    names.add(resolveIdentity(canonical, POOL_MINER_USERNAME));
  }
  return names;
}

/** Same xx/100 for other registered users + pool miner if the peer only paid the initiator. */
function expandMirroredPayouts(canonical, block, payoutIds) {
  const extraIds = [];
  const scenarioTxs = (block.transactions ?? []).filter(
    (tx) => tx?.kind === 'scenarioReward' && microUnits(tx.amount) > 0,
  );
  const seenDraws = new Set();
  for (const src of scenarioTxs) {
    const unit = microUnits(src.amount);
    const drawKey = `${unit}:${src.percentChance ?? ''}:${src.scenarioLabel ?? ''}`;
    if (seenDraws.has(drawKey)) continue;
    seenDraws.add(drawKey);
    const paid = new Set(
      (block.transactions ?? [])
        .filter((tx) => TREASURY_PAYOUT_KINDS.has(tx?.kind) && microUnits(tx.amount) === unit)
        .map((tx) => tx.toUsername ?? tx.to)
        .filter(Boolean),
    );
    const initiator = src.toUsername ?? src.to;
    const minerName = resolveIdentity(canonical, POOL_MINER_USERNAME);
    for (const name of scenarioMirrorNames(canonical, initiator)) {
      if (paid.has(name) || paid.has(resolveIdentity(canonical, name))) continue;
      const id = `mirror-${crypto.randomBytes(8).toString('hex')}`;
      const minerPay = name === minerName || name === POOL_MINER_USERNAME;
      const tx = {
        id,
        kind: minerPay ? 'minerReward' : 'scenarioReward',
        amount: { microUnits: unit },
        fromUsername: TREASURY_USERNAME,
        toUsername: name,
        percentChance: src.percentChance,
        scenarioLabel: src.scenarioLabel,
        timestamp: src.timestamp ?? new Date().toISOString(),
      };
      block.transactions = block.transactions ?? [];
      block.transactions.push(tx);
      payoutIds.push(id);
      extraIds.push(id);
      paid.add(name);
    }
  }
  return extraIds;
}

function ensureTreasuryAccount(canonical, remote, treasuryUsername = TREASURY_USERNAME) {
  canonical.accounts = canonical.accounts ?? {};
  if (canonical.accounts[treasuryUsername]) return;

  const remoteTreasury = remote?.accounts?.[treasuryUsername];
  canonical.accounts[treasuryUsername] = remoteTreasury
    ? {
        ...remoteTreasury,
        balance: cloneBlock(remoteTreasury.balance ?? { microUnits: 0 }),
        cumulativeStakingEarned: cloneBlock(
          remoteTreasury.cumulativeStakingEarned ?? { microUnits: 0 },
        ),
      }
    : {
        username: treasuryUsername,
        balance: { microUnits: 0 },
        cumulativeStakingEarned: { microUnits: 0 },
        transactions: [],
      };
}

function stubRecipientFromRemote(remoteAcc, username) {
  if (remoteAcc) {
    return {
      username,
      passwordHash: remoteAcc.passwordHash ?? '',
      salt: remoteAcc.salt ?? '',
      address: remoteAcc.address ?? '',
      passwordSet: remoteAcc.passwordSet ?? false,
      balance: { microUnits: 0 },
      cumulativeStakingEarned: { microUnits: 0 },
      transactions: [],
    };
  }
  return {
    username,
    passwordHash: '',
    salt: '',
    address: '',
    passwordSet: false,
    balance: { microUnits: 0 },
    cumulativeStakingEarned: { microUnits: 0 },
    transactions: [],
  };
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
    const cloned = cloneTransferBlockForCanonicalTip(block, canonicalIndex);
    expandMirroredPayouts(canonical, cloned, ids);
    canonical.blocks.push(cloned);
    for (const id of ids) known.add(id);
    payoutIds.push(...ids);
    merged += 1;
  }

  return { merged, payoutIds };
}

/**
 * Apply treasury debits and recipient credits from newly merged payout txs only.
 * Preserves canonical pre-merge balances — never wholesale-replaces peer totals.
 */
export function applyTreasuryPayoutDeltasFromPeer(
  canonical,
  remote,
  payoutIds,
  treasuryUsername = TREASURY_USERNAME,
) {
  if (!canonical || !remote || !payoutIds?.length) {
    return { treasuryDebited: 0, recipientsCredited: 0, totalDebitedMicro: 0 };
  }

  ensureTreasuryAccount(canonical, remote, treasuryUsername);
  canonical.accounts = canonical.accounts ?? {};

  let treasuryDebited = 0;
  let recipientsCredited = 0;
  let totalDebitedMicro = 0;

  for (const payoutId of payoutIds) {
    const tx = findPayoutTx(remote, payoutId, canonical);
    if (!tx) continue;

    const amountMicro = microUnits(tx.amount);
    if (amountMicro <= 0) continue;

    const to = tx.toUsername ?? tx.to;
    if (!to || to === treasuryUsername) continue;

    const treasury = canonical.accounts[treasuryUsername];
    treasury.balance = addMicro(treasury.balance, -amountMicro);
    treasuryDebited += 1;
    totalDebitedMicro += amountMicro;

    const remoteAcc = remote.accounts?.[to];
    const local =
      canonical.accounts[to] ?? stubRecipientFromRemote(remoteAcc, to);
    local.balance = addMicro(local.balance, amountMicro);
    if (tx.kind === 'stakingReward') {
      local.cumulativeStakingEarned = addMicro(
        local.cumulativeStakingEarned,
        amountMicro,
      );
    }
    if (remoteAcc?.address && !local.address) local.address = remoteAcc.address;
    if (remoteAcc?.passwordSet && !local.passwordSet) {
      local.passwordSet = remoteAcc.passwordSet;
    }
    canonical.accounts[to] = local;
    recipientsCredited += 1;
  }

  return { treasuryDebited, recipientsCredited, totalDebitedMicro };
}

/** Sum tracked wallet balances on a ledger (treasury + all other accounts). */
export function sumAccountBalancesMicro(ledger, treasuryUsername = TREASURY_USERNAME) {
  let total = 0;
  for (const [name, acc] of Object.entries(ledger?.accounts ?? {})) {
    if (!acc) continue;
    total += microUnits(acc.balance);
  }
  return total;
}

/**
 * Merge treasury payout blocks and apply conserved deltas on canonical accounts.
 */
export function mergeTreasuryStateFromPeer(canonical, remote) {
  const payout = mergeTreasuryPayoutBlocksFromPeer(canonical, remote);
  const deltas =
    payout.payoutIds.length > 0
      ? applyTreasuryPayoutDeltasFromPeer(canonical, remote, payout.payoutIds)
      : { treasuryDebited: 0, recipientsCredited: 0, totalDebitedMicro: 0 };

  if (payout.merged > 0 && remote?.lastScenarioAt) {
    canonical.lastScenarioAt = remote.lastScenarioAt;
  }

  return {
    payoutBlocksMerged: payout.merged,
    payoutIds: payout.payoutIds,
    recipientsCredited: deltas.recipientsCredited,
    treasuryDebitedMicro: deltas.totalDebitedMicro,
    accountSynced: deltas.treasuryDebited > 0,
    merged: payout.merged > 0,
  };
}