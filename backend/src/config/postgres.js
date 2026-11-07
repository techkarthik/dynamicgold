import { Pool } from "pg";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config();

let pool;

function getPool() {
  if (!pool) {
    let connectionString = process.env.DATABASE_URL?.trim();
    if (!connectionString) {
      throw new Error("DATABASE_URL is required to connect to PostgreSQL.");
    }

    const ca = process.env.PG_SSL_CA?.trim().replace(/\\n/g, "\n");
    let ssl;
    if (ca) {
      // pg's URL SSL options override an explicit SSL object. Use the supplied
      // CA with certificate and hostname verification enabled on every host.
      const url = new URL(connectionString);
      for (const key of ["ssl", "sslmode", "sslrootcert", "sslcert", "sslkey", "uselibpqcompat"]) {
        url.searchParams.delete(key);
      }
      connectionString = url.toString();
      ssl = { ca, rejectUnauthorized: true };
    }

    pool = new Pool({
      connectionString,
      ...(ssl ? { ssl } : {}),
      max: Number(process.env.PG_POOL_MAX || 5),
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });
    pool.on("error", (error) => {
      console.error("Unexpected PostgreSQL pool error:", error);
    });
  }
  return pool;
}

function replacePlaceholders(sql) {
  let result = "";
  let index = 0;
  let quote = null;
  let lineComment = false;
  let blockComment = false;

  for (let i = 0; i < sql.length; i += 1) {
    const char = sql[i];
    const next = sql[i + 1];

    if (lineComment) {
      result += char;
      if (char === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      result += char;
      if (char === "*" && next === "/") {
        result += next;
        i += 1;
        blockComment = false;
      }
      continue;
    }
    if (quote) {
      result += char;
      if (char === quote) {
        if (next === quote) {
          result += next;
          i += 1;
        } else {
          quote = null;
        }
      } else if (char === "\\" && next) {
        result += next;
        i += 1;
      }
      continue;
    }
    if (char === "-" && next === "-") {
      result += char + next;
      i += 1;
      lineComment = true;
    } else if (char === "/" && next === "*") {
      result += char + next;
      i += 1;
      blockComment = true;
    } else if (char === "'" || char === '"') {
      quote = char;
      result += char;
    } else if (char === "?") {
      index += 1;
      result += `$${index}`;
    } else {
      result += char;
    }
  }

  return result;
}

function normalizeSql(sql) {
  const ignoreConflicts = /^\s*INSERT\s+OR\s+IGNORE\b/i.test(sql);
  let normalized = sql
    .replace(/\bINTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT\b/gi, "BIGSERIAL PRIMARY KEY")
    .replace(/\bDATETIME\b/gi, "TIMESTAMP")
    .replace(/\bINSERT\s+OR\s+IGNORE\s+INTO\b/gi, "INSERT INTO");
  normalized = replacePlaceholders(normalized);

  if (ignoreConflicts) {
    const statementEnd = normalized.lastIndexOf(";");
    const suffix = statementEnd >= 0 ? normalized.slice(statementEnd) : "";
    const statement = statementEnd >= 0 ? normalized.slice(0, statementEnd) : normalized;
    normalized = `${statement} ON CONFLICT DO NOTHING${suffix}`;
  }

  if (/^\s*INSERT\b/i.test(normalized) && !/\bRETURNING\b/i.test(normalized)) {
    const statementEnd = normalized.lastIndexOf(";");
    const suffix = statementEnd >= 0 ? normalized.slice(statementEnd) : "";
    const statement = statementEnd >= 0 ? normalized.slice(0, statementEnd) : normalized;
    normalized = `${statement} RETURNING *${suffix}`;
  }

  return normalized;
}

const insertedIdFields = [
  "id",
  "empid",
  "estimate_id",
  "purityid",
  "lot_id",
  "template_id",
  "sno",
  "item_id",
  "taxid",
  "designerid",
  "productid",
  "subproductid",
  "styleid",
  "sizeid",
];

function getInsertedId(rows) {
  if (!rows.length) return null;
  const row = rows[0];
  const field = insertedIdFields.find((name) => row[name] !== undefined);
  return field ? String(row[field]) : null;
}

function createClient(schemaName = "public") {
  if (!/^[a-z][a-z0-9_]{0,62}$/.test(schemaName)) {
    throw new Error("Invalid PostgreSQL schema name.");
  }

  return {
    schemaName,
    async execute(statement) {
      const sql = typeof statement === "string" ? statement : statement.sql;
      const args = typeof statement === "string" ? [] : statement.args || [];
      const client = await getPool().connect();

      try {
        await client.query("BEGIN");
        await client.query("SELECT set_config('search_path', $1, true)", [
          `"${schemaName}", public`,
        ]);
        const normalizedSql = normalizeSql(sql);
        const queryResult = args.length
          ? await client.query(normalizedSql, args)
          : await client.query(normalizedSql);
        await client.query("COMMIT");
        const result = Array.isArray(queryResult)
          ? queryResult[queryResult.length - 1]
          : queryResult;

        return {
          rows: result.rows || [],
          columns: result.fields?.map((field) => field.name) || [],
          rowsAffected: result.rowCount || 0,
          lastInsertRowid: getInsertedId(result.rows || []),
        };
      } catch (error) {
        await client.query("ROLLBACK").catch(() => {});
        throw error;
      } finally {
        client.release();
      }
    },
    async executeMultiple(sql) {
      return this.execute(sql);
    },
  };
}

const masterClient = createClient();
const tenantClients = new Map();

export const masterDb = masterClient;

export function createTenantClient(schemaName) {
  const normalizedName = String(schemaName || "").trim();
  if (!tenantClients.has(normalizedName)) {
    tenantClients.set(normalizedName, createClient(normalizedName));
  }
  return tenantClients.get(normalizedName);
}

export async function createTenantSchema(schemaName) {
  if (!/^tenant_[a-f0-9]{32}$/.test(schemaName)) {
    throw new Error("Invalid generated tenant schema name.");
  }
  await getPool().query(`CREATE SCHEMA IF NOT EXISTS "${schemaName}"`);
}

export async function dropTenantSchema(schemaName) {
  if (!/^tenant_[a-f0-9]{32}$/.test(schemaName)) {
    throw new Error("Invalid generated tenant schema name.");
  }
  await getPool().query(`DROP SCHEMA IF EXISTS "${schemaName}" CASCADE`);
  tenantClients.delete(schemaName);
}

export async function closePostgresPool() {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
