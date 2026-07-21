/**
 * In-memory (+ optional file) history for perpetual construe/score cycles.
 */

import fs from 'fs';
import path from 'path';

const MAX = Number(process.env.SCS_HISTORY_MAX || 200);

export class HistoryStore {
  constructor(filePath) {
    this.filePath = filePath || null;
    this.history = [];
    this.latest = null;
    if (this.filePath && fs.existsSync(this.filePath)) {
      try {
        const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf8'));
        this.history = Array.isArray(raw.history) ? raw.history : [];
        this.latest = raw.latest || this.history[this.history.length - 1] || null;
      } catch {
        this.history = [];
      }
    }
  }

  push(result) {
    const point = {
      ...(result.historyPoint || {}),
      t: Date.now(),
      refinedScs: result.refinedScs,
      progressivePct: result.progressivePct,
      regressivePct: result.regressivePct,
      constructs: result.constructs,
      lean: result.lean,
      provenance: result.construeProvenance || null,
    };
    this.history.push(point);
    if (this.history.length > MAX) this.history.splice(0, this.history.length - MAX);
    this.latest = result;
    this._persist();
    return point;
  }

  snapshot() {
    return {
      latest: this.latest,
      history: this.history.slice(),
      count: this.history.length,
    };
  }

  _persist() {
    if (!this.filePath) return;
    try {
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
      fs.writeFileSync(
        this.filePath,
        JSON.stringify({ latest: this.latest, history: this.history }, null, 2),
      );
    } catch {
      // non-fatal
    }
  }
}
