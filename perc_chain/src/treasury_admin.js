import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

const DEFAULT_ADMIN_USER = 'rgsnedds';

export class TreasuryAdmin {
  constructor(dataDir, { adminUsername = process.env.PERC_TREASURY_ADMIN_USER ?? DEFAULT_ADMIN_USER } = {}) {
    this.filePath = path.join(dataDir, 'treasury_admin.json');
    this.adminUsername = adminUsername.trim().toLowerCase();
    this.sessions = new Map();
    fs.mkdirSync(dataDir, { recursive: true });
    this.load();
  }

  load() {
    if (!fs.existsSync(this.filePath)) {
      this.record = {
        username: this.adminUsername,
        passwordHash: null,
        salt: null,
        blockchainLaunched: false,
      };
      return;
    }
    try {
      const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf8'));
      this.record = {
        username: (raw.username ?? this.adminUsername).trim().toLowerCase(),
        passwordHash: raw.passwordHash ?? null,
        salt: raw.salt ?? null,
        blockchainLaunched: raw.blockchainLaunched === true,
      };
    } catch {
      this.record = {
        username: this.adminUsername,
        passwordHash: null,
        salt: null,
        blockchainLaunched: false,
      };
    }
  }

  save() {
    fs.writeFileSync(this.filePath, JSON.stringify(this.record, null, 2));
  }

  needsPasswordSetup() {
    return !this.record.passwordHash;
  }

  isBlockchainLaunched() {
    return this.record.blockchainLaunched === true;
  }

  markBlockchainLaunched() {
    this.record.blockchainLaunched = true;
    this.save();
  }

  hashPassword(password, salt) {
    return crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
  }

  generateSalt() {
    return crypto.randomBytes(16).toString('base64url');
  }

  login({ username, password, confirmPassword }) {
    const user = (username ?? '').trim().toLowerCase();
    if (user !== this.record.username) {
      return { ok: false, error: 'Invalid credentials' };
    }
    if (!password || password.length < 8) {
      return { ok: false, error: 'Password must be at least 8 characters' };
    }

    if (this.needsPasswordSetup()) {
      if (!confirmPassword) {
        return { ok: false, needsSetup: true, error: 'Create a password on first login' };
      }
      if (password !== confirmPassword) {
        return { ok: false, needsSetup: true, error: 'Passwords do not match' };
      }
      const salt = this.generateSalt();
      this.record.salt = salt;
      this.record.passwordHash = this.hashPassword(password, salt);
      this.save();
    } else if (this.hashPassword(password, this.record.salt) !== this.record.passwordHash) {
      return { ok: false, error: 'Invalid credentials' };
    }

    const token = crypto.randomBytes(32).toString('hex');
    this.sessions.set(token, { username: user, createdAt: Date.now() });
    return { ok: true, token, username: user, needsSetup: false };
  }

  sessionFromAuthHeader(header) {
    if (!header || !header.startsWith('Bearer ')) return null;
    const token = header.slice('Bearer '.length).trim();
    const session = this.sessions.get(token);
    if (!session) return null;
    if (Date.now() - session.createdAt > 24 * 60 * 60 * 1000) {
      this.sessions.delete(token);
      return null;
    }
    return session;
  }

  logout(token) {
    if (token) this.sessions.delete(token);
  }
}