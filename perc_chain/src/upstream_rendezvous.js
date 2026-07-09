/**
 * Merge upstream rendezvous peer lists into a local peer map.
 * @param {Map<string, object>} localPeers
 * @param {unknown} upstreamList
 * @param {string} chainId
 * @returns {number} count of peers added or updated from upstream
 */
export function mergeUpstreamPeers(localPeers, upstreamList, chainId) {
  if (!Array.isArray(upstreamList)) return 0;
  let merged = 0;
  for (const peer of upstreamList) {
    if (!peer || typeof peer !== 'object') continue;
    const endpoint = peer.endpoint;
    if (!endpoint) continue;
    const username =
      peer.sessionUsername ??
      peer.username ??
      peer.publicAlias ??
      endpoint;
    const peerChain = peer.evolutionaryChainId ?? chainId;
    if (peerChain !== chainId) continue;
    const key = String(username);
    const existing = localPeers.get(key);
    const incomingRevision = Number(peer.revision ?? 0);
    const existingRevision = Number(existing?.revision ?? 0);
    if (!existing || incomingRevision >= existingRevision) {
      localPeers.set(key, {
        sessionUsername: key,
        endpoint,
        evolutionaryChainId: peerChain,
        blockHeight: peer.blockHeight ?? existing?.blockHeight ?? 0,
        tipHash: peer.tipHash ?? existing?.tipHash ?? '',
        revision: incomingRevision || existingRevision,
        publicAlias: peer.publicAlias ?? existing?.publicAlias,
        updatedAt: Date.now(),
        upstream: true,
      });
      merged += 1;
    }
  }
  return merged;
}