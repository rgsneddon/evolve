import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';

export function tipHash(ledger) {
  const chainId = ledger?.evolutionaryChainId || CHAIN_ID;
  if (!ledger) {
    return crypto.createHash('sha256').update(`genesis:${chainId}`).digest('hex');
  }
  const blocks = ledger.blocks ?? [];
  if (blocks.length === 0) {
    return crypto.createHash('sha256').update(`genesis:${chainId}`).digest('hex');
  }
  const payload = JSON.stringify(blocks[blocks.length - 1]);
  return crypto.createHash('sha256').update(payload).digest('hex');
}

export function blockHeight(ledger) {
  if (!ledger) return 0;
  return ledger.blocks?.length ?? 0;
}

export function shouldImportLedger(local, remote) {
  if (!remote || typeof remote !== 'object') return false;
  const localH = blockHeight(local);
  const remoteH = blockHeight(remote);
  if (remoteH > localH) return true;
  if (remoteH === localH && remoteH > 0) {
    return tipHash(remote) !== tipHash(local);
  }
  return false;
}

export class LedgerStore {
  constructor(dataDir) {
    this.dataDir = dataDir;
    this.filePath = path.join(dataDir, 'seed_ledger.json');
    this.revision = 0;
    this.ledger = null;
    fs.mkdirSync(dataDir, { recursive: true });
    this.load();
  }

  load() {
    if (!fs.existsSync(this.filePath)) return;
    try {
      const raw = fs.readFileSync(this.filePath, 'utf8');
      const parsed = JSON.parse(raw);
      this.ledger = parsed.ledger ?? null;
      this.revision = parsed.revision ?? 0;
    } catch {
      this.ledger = null;
      this.revision = 0;
    }
  }

  save() {
    const payload = {
      revision: this.revision,
      ledger: this.ledger,
      savedAt: new Date().toISOString(),
    };
    fs.writeFileSync(this.filePath, JSON.stringify(payload, null, 2));
  }

  hasLedger() {
    return this.ledger != null && blockHeight(this.ledger) > 0;
  }

  status(sessionUsername, endpoint) {
    const ledger = this.ledger;
    return {
      evolutionaryChainId: ledger?.evolutionaryChainId || CHAIN_ID,
      blockHeight: blockHeight(ledger),
      tipHash: tipHash(ledger),
      revision: this.revision,
      sessionUsername,
      endpoint,
    };
  }

  importLedger(remote) {
    if (!shouldImportLedger(this.ledger, remote)) return false;
    this.ledger = remote;
    this.revision += 1;
    this.save();
    return true;
  }
}