/**
 * In-memory registry to ensure DDL queries are executed AT MOST ONCE per tenant schema.
 * This prevents running redundant CREATE TABLE / ALTER TABLE / CREATE INDEX queries
 * on every single API request over the network.
 */
const _ensuredTenants = new Set();

export async function ensureTableOnce(cacheKey, ensureFn) {
  if (_ensuredTenants.has(cacheKey)) {
    return;
  }
  await ensureFn();
  _ensuredTenants.add(cacheKey);
}

export function clearEnsuredTableCache(schemaName = null) {
  if (!schemaName) {
    _ensuredTenants.clear();
    return;
  }
  for (const key of _ensuredTenants) {
    if (key.includes(schemaName)) {
      _ensuredTenants.delete(key);
    }
  }
}
