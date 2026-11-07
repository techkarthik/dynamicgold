import { masterDb } from "../config/postgres.js";
import {
  getTenantDatabaseOverview,
  getTenantDatabaseStatus,
  getTenantTablesBreakdown,
  optimizeTenantDatabase,
  executeTenantQuery,
  testTenantDatabase,
} from "../services/postgresService.js";
import { syncTenantDatabaseSchema } from "../services/tenantSchemaService.js";
import { invalidateTenantAuthCache } from "../middleware/authMiddleware.js";

/**
 * Get tenant profile and validity metadata
 */
export async function getProfileController(req, res) {
  try {
    const tenant = req.tenant;
    const today = new Date();
    const validToDate = new Date(tenant.valid_to);

    const diffTime = validToDate.getTime() - today.getTime();
    const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    return res.json({
      success: true,
      role: req.user ? req.user.role : "ADMIN",
      user: req.user || null,
      tenant: {
        id: tenant.id,
        email: tenant.email,
        contact_number: tenant.contact_number,
        business_name: tenant.business_name || "ProGold Business",
        business_logo: tenant.business_logo || "",
        valid_from: tenant.valid_from,
        valid_to: tenant.valid_to,
        status: tenant.status,
        days_remaining: daysRemaining,
        is_active: tenant.status === "ACTIVE",
        has_database: Boolean(tenant.schema_name),
        schema_name: tenant.schema_name,
      },
    });
  } catch (error) {
    console.error("getProfileController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch profile." });
  }
}

/**
 * Update business profile details
 */
export async function updateProfileController(req, res) {
  try {
    const { business_name, business_logo, contact_number } = req.body;
    const tenantId = req.tenant.id;
    const now = new Date().toISOString();

    await masterDb.execute({
      sql: `UPDATE tenants SET business_name = COALESCE(?, business_name),
                               business_logo = COALESCE(?, business_logo),
                               contact_number = COALESCE(?, contact_number),
                               updated_at = ?
            WHERE id = ?`,
      args: [business_name || null, business_logo || null, contact_number || null, now, tenantId],
    });

    // Invalidate auth cache so changes reflect immediately
    invalidateTenantAuthCache(tenantId);

    return res.json({
      success: true,
      message: "Business profile updated successfully!",
      business_name,
      business_logo,
    });
  } catch (error) {
    console.error("updateProfileController error:", error);
    return res.status(500).json({ success: false, message: "Failed to update profile." });
  }
}

/**
 * Get PostgreSQL schema status, size, latency, and optional table breakdown.
 */
export async function getTenantDbStatusController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const includeTables = req.query.include_tables === "true";
    const status = await getTenantDatabaseStatus(schemaName, req.tenant, { includeTables });
    return res.json(status);
  } catch (error) {
    console.error("getTenantDbStatusController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch database status." });
  }
}

/**
 * Get a breakdown of all tables in the tenant's PostgreSQL schema.
 */
export async function getTenantDbTablesController(req, res) {
  try {
    const tablesData = await getTenantTablesBreakdown(req.tenant.schema_name);
    return res.json(tablesData);
  } catch (error) {
    console.error("getTenantDbTablesController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch database tables." });
  }
}

/**
 * Refresh query-planner statistics for the tenant's PostgreSQL schema.
 */
export async function optimizeTenantDbController(req, res) {
  try {
    const result = await optimizeTenantDatabase(req.tenant.schema_name);
    return res.json(result);
  } catch (error) {
    console.error("optimizeTenantDbController error:", error);
    return res.status(500).json({ success: false, message: "Failed to optimize database." });
  }
}

/**
 * Get an overview of tables in the tenant's PostgreSQL schema.
 */
export async function getTenantDbOverviewController(req, res) {
  try {
    const overview = await getTenantDatabaseOverview(req.tenant.schema_name);
    return res.json(overview);
  } catch (error) {
    console.error("getTenantDbOverviewController error:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch database overview." });
  }
}

/**
 * Execute a custom SQL query in the tenant's PostgreSQL schema.
 */
export async function executeTenantQueryController(req, res) {
  try {
    const { sql, args = [] } = req.body;
    if (!sql || typeof sql !== "string") {
      return res.status(400).json({ success: false, message: "SQL query string is required." });
    }

    const result = await executeTenantQuery(req.tenant.schema_name, sql.trim(), args);
    return res.json(result);
  } catch (error) {
    console.error("executeTenantQueryController error:", error);
    return res.status(500).json({ success: false, message: "Failed to execute database query." });
  }
}

/**
 * Test health of tenant's PostgreSQL schema
 */
export async function testTenantDbHealthController(req, res) {
  try {
    const result = await testTenantDatabase(req.tenant.schema_name);
    return res.json(result);
  } catch (error) {
    console.error("testTenantDbHealthController error:", error);
    return res.status(500).json({ success: false, message: "Database health check failed." });
  }
}

/**
 * Reinstall & Synchronize latest ProGold ERP schema into tenant's database on demand
 */
export async function reinstallTenantDbController(req, res) {
  try {
    const syncResult = await syncTenantDatabaseSchema(req.tenant.schema_name);
    return res.json(syncResult);
  } catch (error) {
    console.error("reinstallTenantDbController error:", error);
    return res.status(500).json({
      success: false,
      message: `Failed to reinstall schema: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}
