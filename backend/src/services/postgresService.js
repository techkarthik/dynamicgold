import { createTenantClient } from "../config/postgres.js";

function formatBytes(bytes) {
  const value = Number(bytes || 0);
  if (value < 1024) return `${value} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let size = value / 1024;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(2)} ${units[unitIndex]}`;
}

export async function getTenantTablesBreakdown(schemaName) {
  const client = createTenantClient(schemaName);
  const startTime = Date.now();

  try {
    const tableResult = await client.execute(`
      SELECT table_name AS name, table_type AS type
      FROM information_schema.tables
      WHERE table_schema = current_schema()
        AND table_type IN ('BASE TABLE', 'VIEW')
      ORDER BY table_name
    `);

    const tables = await Promise.all(tableResult.rows.map(async (table) => {
      const columnsResult = await client.execute({
        sql: `SELECT column_name FROM information_schema.columns
              WHERE table_schema = current_schema() AND table_name = ? ORDER BY ordinal_position`,
        args: [table.name],
      });
      let rowCount = 0;

      if (table.type === "BASE TABLE") {
        const quotedName = `"${String(table.name).replace(/"/g, '""')}"`;
        const countResult = await client.execute(`SELECT COUNT(*) AS count FROM ${quotedName}`);
        rowCount = Number(countResult.rows[0]?.count || 0);
      }

      return {
        name: table.name,
        type: table.type === "BASE TABLE" ? "table" : "view",
        sql: columnsResult.rows.map((column) => column.column_name).join(", "),
        rowCount,
      };
    }));

    return {
      success: true,
      tables,
      totalTables: tables.length,
      totalRows: tables.reduce((total, table) => total + table.rowCount, 0),
      executionTimeMs: Date.now() - startTime,
    };
  } catch (error) {
    console.error("getTenantTablesBreakdown error:", error);
    return { success: false, message: error.message, tables: [] };
  }
}

export async function getTenantDatabaseStatus(schemaName, tenant = {}, options = {}) {
  const client = createTenantClient(schemaName);
  const startTime = Date.now();

  try {
    const [versionResult, sizeResult, tablesResult] = await Promise.all([
      client.execute("SELECT current_setting('server_version') AS version"),
      client.execute(`
        SELECT COALESCE(SUM(pg_total_relation_size(
          format('%I.%I', schemaname, tablename)::regclass
        )), 0) AS size
        FROM pg_tables
        WHERE schemaname = current_schema()
      `),
      getTenantTablesBreakdown(schemaName),
    ]);

    const sizeBytes = Number(sizeResult.rows[0]?.size || 0);
    const includeTables = options.includeTables === true;
    const tables = includeTables && tablesResult.success ? tablesResult.tables : [];

    return {
      success: true,
      database: {
        status: "ONLINE & HEALTHY",
        database_name: "PostgreSQL",
        schema_name: schemaName,
        engine: "PostgreSQL",
        postgres_version: versionResult.rows[0]?.version || "",
        latency_ms: Date.now() - startTime,
        total_size_bytes: sizeBytes,
        total_size_formatted: formatBytes(sizeBytes),
        total_tables: tablesResult.totalTables || 0,
        total_rows: tablesResult.totalRows || 0,
        tenant_email: tenant.email || "",
        business_name: tenant.business_name || "ProGold Enterprise",
      },
      tables,
    };
  } catch (error) {
    console.error("getTenantDatabaseStatus error:", error);
    return { success: false, message: error.message, database: null, tables: [] };
  }
}

export async function optimizeTenantDatabase(schemaName) {
  const client = createTenantClient(schemaName);
  const startTime = Date.now();

  try {
    const result = await getTenantTablesBreakdown(schemaName);
    if (!result.success) throw new Error(result.message || "Unable to list tenant tables.");

    for (const table of result.tables) {
      if (table.type !== "table") continue;
      const quotedSchema = `"${schemaName.replace(/"/g, '""')}"`;
      const quotedTable = `"${table.name.replace(/"/g, '""')}"`;
      await client.execute(`ANALYZE ${quotedSchema}.${quotedTable}`);
    }

    return {
      success: true,
      message: "PostgreSQL statistics updated successfully.",
      executionTimeMs: Date.now() - startTime,
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

export async function getTenantDatabaseOverview(schemaName) {
  const breakdown = await getTenantTablesBreakdown(schemaName);
  return breakdown.success
    ? { success: true, tables: breakdown.tables }
    : { success: false, message: breakdown.message, tables: [] };
}

export async function executeTenantQuery(schemaName, sql, args = []) {
  const client = createTenantClient(schemaName);
  const startTime = Date.now();

  try {
    const result = await client.execute({ sql, args });
    return {
      success: true,
      columns: result.columns,
      rows: result.rows,
      rowsAffected: result.rowsAffected,
      lastInsertRowid: result.lastInsertRowid,
      executionTimeMs: Date.now() - startTime,
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

export async function testTenantDatabase(schemaName) {
  const startTime = Date.now();
  try {
    await createTenantClient(schemaName).execute("SELECT 1 AS ping");
    return {
      success: true,
      message: "Successfully connected to the PostgreSQL tenant schema.",
      latencyMs: Date.now() - startTime,
    };
  } catch (error) {
    console.error("PostgreSQL tenant health check failed:", error);
    return { success: false, message: error.message };
  }
}
