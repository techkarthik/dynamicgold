import { masterDb } from "./postgres.js";

export async function initMasterSchema() {
  await masterDb.execute(`
    CREATE TABLE IF NOT EXISTS tenants (
      id BIGSERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      contact_number TEXT NOT NULL,
      schema_name TEXT UNIQUE NOT NULL,
      valid_from TEXT NOT NULL,
      valid_to TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'ACTIVE',
      business_name TEXT NOT NULL DEFAULT 'ProGold Business',
      business_logo TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  `);

  await masterDb.execute(`
    CREATE TABLE IF NOT EXISTS email_otps (
      id BIGSERIAL PRIMARY KEY,
      email TEXT NOT NULL,
      otp_code TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      is_verified SMALLINT NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  `);

  await masterDb.execute(`
    CREATE TABLE IF NOT EXISTS tenant_users_lookup (
      email TEXT PRIMARY KEY NOT NULL,
      tenant_id BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
      userid TEXT NOT NULL,
      username TEXT NOT NULL
    )
  `);

  await masterDb.execute(`
    CREATE INDEX IF NOT EXISTS idx_otps_email ON email_otps (email)
  `);
  await masterDb.execute(`
    CREATE INDEX IF NOT EXISTS idx_tenant_users_lookup_tenant ON tenant_users_lookup (tenant_id)
  `);

  console.log("PostgreSQL master schema initialized.");
}
