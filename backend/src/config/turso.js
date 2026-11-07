import { createClient } from "@libsql/client";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

try {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  dotenv.config({ path: path.resolve(__dirname, "../../.env") });
  dotenv.config();
} catch (_) {}

function getMasterUrl() {
  const url = (
    process.env.MASTER_TURSO_URL ||
    process.env.TURSO_DATABASE_URL ||
    process.env.TURSO_URL ||
    "libsql://gold-techkarthik.aws-ap-south-1.turso.io"
  ).trim();
  if (!url.startsWith("libsql://") && !url.startsWith("https://") && !url.startsWith("http://")) {
    return `libsql://${url}`;
  }
  return url;
}

function getMasterToken() {
  return (
    process.env.MASTER_TURSO_AUTH_TOKEN ||
    process.env.TURSO_AUTH_TOKEN ||
    process.env.TURSO_TOKEN ||
    process.env.TURSO_MASTER_TOKEN ||
    process.env.MASTER_TOKEN ||
    (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || "")
  ).trim();
}

let _masterDbClient = null;
let _lastToken = null;
let _lastUrl = null;

export function getMasterClient() {
  const url = getMasterUrl();
  const token = getMasterToken();
  if (!_masterDbClient || _lastToken !== token || _lastUrl !== url) {
    _lastUrl = url;
    _lastToken = token;
    _masterDbClient = createClient({
      url: url,
      authToken: token,
    });
  }
  return _masterDbClient;
}

// Master Turso Database Client Proxy
export const masterDb = new Proxy(
  {},
  {
    get(target, prop) {
      const client = getMasterClient();
      const val = client[prop];
      if (typeof val === "function") {
        return val.bind(client);
      }
      return val;
    },
  }
);

const _tenantClients = new Map();

/**
 * Creates or retrieves a cached dynamic Turso client for a specific tenant database.
 * @param {string} url - The tenant's Turso database URL (e.g. libsql://tenant.turso.io)
 * @param {string} authToken - The tenant's Turso auth token
 * @returns {Client}
 */
export function createTenantClient(url, authToken) {
  let formattedUrl = (url || "").trim();
  if (!formattedUrl.startsWith("libsql://") && !formattedUrl.startsWith("https://") && !formattedUrl.startsWith("http://")) {
    formattedUrl = `libsql://${formattedUrl}`;
  }
  const cleanToken = (authToken || "").trim();
  const cacheKey = `${formattedUrl}:${cleanToken}`;

  let client = _tenantClients.get(cacheKey);
  if (!client) {
    client = createClient({
      url: formattedUrl,
      authToken: cleanToken,
    });
    _tenantClients.set(cacheKey, client);
  }
  return client;
}

