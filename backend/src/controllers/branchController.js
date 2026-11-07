import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures the branches table exists in the tenant's PostgreSQL schema.
 */
async function ensureBranchesTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`branches:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS branches (
        branchid TEXT PRIMARY KEY NOT NULL,
        branchname TEXT NOT NULL,
        companyid TEXT NOT NULL,
        accountname TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        address TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe non-destructive column additions
    try {
      await client.execute(`ALTER TABLE branches ADD COLUMN state_id INTEGER DEFAULT 0;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE branches ADD COLUMN country_id INTEGER DEFAULT 1;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE branches ADD COLUMN is_active INTEGER DEFAULT 1;`);
    } catch (_) { }
  });
}

/**
 * GET /api/tenant/branches
 * Retrieves all branch records for the tenant, joined with company name.
 */
export async function getBranchesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBranchesTable(client);

    // Fetch branches with company name if company table exists, optionally filtered by companyid
    let sql = `
      SELECT 
        b.*,
        COALESCE(c.companyname, '') AS companyname
      FROM branches b
      LEFT JOIN company c ON UPPER(TRIM(b.companyid)) = UPPER(TRIM(c.companyid))
    `;
    const args = [];
    if (req.query.companyid && String(req.query.companyid).trim()) {
      sql += ` WHERE UPPER(TRIM(b.companyid)) = ?`;
      args.push(String(req.query.companyid).trim().toUpperCase());
    }
    sql += ` ORDER BY b.created_at DESC;`;

    const result = await client.execute({ sql, args });

    return res.json({
      success: true,
      branches: result.rows || [],
    });
  } catch (error) {
    console.error("getBranchesController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch branches.",
    });
  }
}

/**
 * POST /api/tenant/branches
 * Inserts a new branch record.
 */
export async function createBranchController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBranchesTable(client);

    const {
      branchid,
      branchname,
      companyid,
      accountname = "",
      state = "",
      state_id = 0,
      country = "India",
      country_id = 1,
      address = "",
      mobile = "",
      email = "",
      is_active = 1,
    } = req.body;

    if (!branchid || !String(branchid).trim()) {
      return res.status(400).json({
        success: false,
        message: "Branch ID is required.",
      });
    }

    const cleanBranchId = String(branchid).trim().toUpperCase();

    if (!branchname || !String(branchname).trim()) {
      return res.status(400).json({
        success: false,
        message: "Branch Name is required.",
      });
    }

    if (!companyid || !String(companyid).trim()) {
      return res.status(400).json({
        success: false,
        message: "Company selection is required.",
      });
    }

    // Check for duplicate Branch ID
    const checkExists = await client.execute({
      sql: `SELECT branchid FROM branches WHERE branchid = ? LIMIT 1;`,
      args: [cleanBranchId],
    });

    if (checkExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Branch ID "${cleanBranchId}" already exists. Please choose a unique ID.`,
      });
    }

    const now = new Date().toISOString();
    const activeInt = (is_active === 1 || is_active === true || is_active === "1" || is_active === "yes" || is_active === "Yes") ? 1 : 0;

    await client.execute({
      sql: `
        INSERT INTO branches (
          branchid, branchname, companyid, accountname, state, state_id, country, country_id, address, mobile, email, is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        cleanBranchId,
        String(branchname).trim(),
        String(companyid).trim().toUpperCase(),
        String(accountname || "").trim(),
        String(state || "").trim(),
        Number(state_id) || 0,
        String(country || "India").trim(),
        Number(country_id) || 1,
        String(address || "").trim(),
        String(mobile || "").trim(),
        String(email || "").trim(),
        activeInt,
        now,
        now,
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Branch created successfully!",
      branch: {
        branchid: cleanBranchId,
        branchname: String(branchname).trim(),
        companyid: String(companyid).trim().toUpperCase(),
        accountname: String(accountname || "").trim(),
        state: String(state || "").trim(),
        state_id: Number(state_id) || 0,
        country: String(country || "India").trim(),
        country_id: Number(country_id) || 1,
        address: String(address || "").trim(),
        mobile: String(mobile || "").trim(),
        email: String(email || "").trim(),
        is_active: activeInt,
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createBranchController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create branch.",
    });
  }
}

/**
 * PUT /api/tenant/branches/:id
 * Updates an existing branch record.
 */
export async function updateBranchController(req, res) {
  try {
    const branchId = req.params.id;
    if (!branchId) {
      return res.status(400).json({ success: false, message: "Branch ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBranchesTable(client);

    const {
      branchname,
      companyid,
      accountname,
      state,
      state_id,
      country,
      country_id,
      address,
      mobile,
      email,
      is_active,
    } = req.body;

    if (branchname !== undefined && (!branchname || !String(branchname).trim())) {
      return res.status(400).json({
        success: false,
        message: "Branch Name cannot be empty.",
      });
    }

    if (companyid !== undefined && (!companyid || !String(companyid).trim())) {
      return res.status(400).json({
        success: false,
        message: "Company selection cannot be empty.",
      });
    }

    const now = new Date().toISOString();
    let activeVal = null;
    if (is_active !== undefined) {
      activeVal = (is_active === 1 || is_active === true || is_active === "1" || is_active === "yes" || is_active === "Yes") ? 1 : 0;
    }

    await client.execute({
      sql: `
        UPDATE branches
        SET branchname = COALESCE(?, branchname),
            companyid = COALESCE(?, companyid),
            accountname = COALESCE(?, accountname),
            state = COALESCE(?, state),
            state_id = COALESCE(?, state_id),
            country = COALESCE(?, country),
            country_id = COALESCE(?, country_id),
            address = COALESCE(?, address),
            mobile = COALESCE(?, mobile),
            email = COALESCE(?, email),
            is_active = COALESCE(?, is_active),
            updated_at = ?
        WHERE branchid = ?
      `,
      args: [
        branchname !== undefined ? String(branchname).trim() : null,
        companyid !== undefined ? String(companyid).trim().toUpperCase() : null,
        accountname !== undefined ? String(accountname).trim() : null,
        state !== undefined ? String(state).trim() : null,
        state_id !== undefined ? Number(state_id) : null,
        country !== undefined ? String(country).trim() : null,
        country_id !== undefined ? Number(country_id) : null,
        address !== undefined ? String(address).trim() : null,
        mobile !== undefined ? String(mobile).trim() : null,
        email !== undefined ? String(email).trim() : null,
        activeVal,
        now,
        String(branchId).trim().toUpperCase(),
      ],
    });

    return res.json({
      success: true,
      message: "Branch updated successfully!",
    });
  } catch (error) {
    console.error("updateBranchController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update branch.",
    });
  }
}

/**
 * DELETE /api/tenant/branches/:id
 * Deletes a branch record.
 */
export async function deleteBranchController(req, res) {
  try {
    const branchId = req.params.id;
    if (!branchId) {
      return res.status(400).json({ success: false, message: "Branch ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBranchesTable(client);

    const result = await client.execute({
      sql: `DELETE FROM branches WHERE branchid = ?;`,
      args: [String(branchId).trim().toUpperCase()],
    });

    return res.json({
      success: true,
      message: "Branch deleted successfully!",
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteBranchController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete branch.",
    });
  }
}
