import { indexLedgerAddresses } from './address_index.js';

/**
 * Shipped rendezvous PUT /perc/rendezvous/ledger handler body.
 * @param {{
 *   store: import('./ledger_store.js').LedgerStore,
 *   ledgers: Map<string, object>,
 *   addresses: Map<string, string>,
 *   username: string,
 *   ledger: object,
 *   seedUsername: string,
 * }} ctx
 */
export function applyRelayLedgerPut({
  store,
  ledgers,
  addresses,
  username,
  ledger,
  seedUsername,
}) {
  if (!username || !ledger) {
    return { ok: false, error: 'username and ledger required' };
  }

  ledgers.set(username, {
    username,
    ledger,
    updatedAt: Date.now(),
  });
  indexLedgerAddresses(ledger, addresses);

  let imported = false;
  if (username !== seedUsername) {
    imported = store.importLedger(ledger);
    if (imported) {
      indexLedgerAddresses(store.ledger, addresses);
    }
  }

  return { ok: true, imported };
}