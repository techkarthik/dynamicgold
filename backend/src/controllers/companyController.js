import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures the company table exists in the tenant's PostgreSQL schema.
 * companyid is VARCHAR(5) / TEXT PRIMARY KEY (Manually assigned, no autoincrement).
 */
async function ensureCompanyTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`company:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS company (
        companyid TEXT PRIMARY KEY NOT NULL,
        companyname TEXT NOT NULL,
        gstno TEXT DEFAULT '',
        mobilenumber TEXT DEFAULT '',
        address TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        accountname TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe non-destructive column additions
    try {
      await client.execute(`ALTER TABLE company ADD COLUMN state_id INTEGER DEFAULT 0;`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE company ADD COLUMN country_id INTEGER DEFAULT 1;`);
    } catch (_) {}
  });
}

/**
 * GET /api/tenant/companies
 * Retrieves all company records for the authenticated tenant.
 */
export async function getCompaniesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureCompanyTable(client);

    const result = await client.execute(`
      SELECT * FROM company 
      ORDER BY created_at DESC;
    `);

    return res.json({
      success: true,
      companies: result.rows || [],
    });
  } catch (error) {
    console.error("getCompaniesController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch companies.",
    });
  }
}

/**
 * POST /api/tenant/companies
 * Inserts a new company record with manually assigned VARCHAR(5) companyid.
 */
export async function createCompanyController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureCompanyTable(client);

    const {
      companyid,
      companyname,
      gstno = "",
      mobilenumber = "",
      address = "",
      city = "",
      state = "",
      state_id = 0,
      country = "India",
      country_id = 1,
      accountname = "",
      branchid = "",
    } = req.body;

    if (!companyid || !String(companyid).trim()) {
      return res.status(400).json({
        success: false,
        message: "Company ID is required.",
      });
    }

    const cleanCompanyId = String(companyid).trim().toUpperCase();
    if (cleanCompanyId.length > 5) {
      return res.status(400).json({
        success: false,
        message: "Company ID must be at most 5 characters (VARCHAR 5).",
      });
    }

    if (!companyname || !companyname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Company Name is required.",
      });
    }

    // Check if Company ID already exists
    const checkExists = await client.execute({
      sql: `SELECT companyid FROM company WHERE companyid = ? LIMIT 1;`,
      args: [cleanCompanyId],
    });

    if (checkExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Company ID "${cleanCompanyId}" already exists. Please choose a unique ID.`,
      });
    }

    const now = new Date().toISOString();
    const branchidStr = Array.isArray(branchid) ? branchid.join(", ") : String(branchid || "");

    await client.execute({
      sql: `
        INSERT INTO company (
          companyid, companyname, gstno, mobilenumber, address, city, state, state_id, country, country_id, accountname, branchid, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        cleanCompanyId,
        companyname.trim(),
        gstno.trim(),
        mobilenumber.trim(),
        address.trim(),
        city.trim(),
        state.trim(),
        Number(state_id) || 0,
        country.trim() || "India",
        Number(country_id) || 1,
        accountname.trim(),
        branchidStr.trim(),
        now,
        now,
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Company created successfully!",
      company: {
        companyid: cleanCompanyId,
        companyname: companyname.trim(),
        gstno: gstno.trim(),
        mobilenumber: mobilenumber.trim(),
        address: address.trim(),
        city: city.trim(),
        state: state.trim(),
        state_id: Number(state_id) || 0,
        country: country.trim() || "India",
        country_id: Number(country_id) || 1,
        accountname: accountname.trim(),
        branchid: branchidStr.trim(),
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createCompanyController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create company.",
    });
  }
}

/**
 * PUT /api/tenant/companies/:id
 * Updates an existing company record by companyid.
 */
export async function updateCompanyController(req, res) {
  try {
    const companyId = req.params.id;
    if (!companyId) {
      return res.status(400).json({ success: false, message: "Company ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureCompanyTable(client);

    const {
      companyname,
      gstno,
      mobilenumber,
      address,
      city,
      state,
      state_id,
      country,
      country_id,
      accountname,
      branchid,
    } = req.body;

    if (companyname !== undefined && (!companyname || !companyname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Company Name cannot be empty.",
      });
    }

    const now = new Date().toISOString();
    const branchidStr = Array.isArray(branchid) ? branchid.join(", ") : branchid;

    await client.execute({
      sql: `
        UPDATE company
        SET companyname = COALESCE(?, companyname),
            gstno = COALESCE(?, gstno),
            mobilenumber = COALESCE(?, mobilenumber),
            address = COALESCE(?, address),
            city = COALESCE(?, city),
            state = COALESCE(?, state),
            state_id = COALESCE(?, state_id),
            country = COALESCE(?, country),
            country_id = COALESCE(?, country_id),
            accountname = COALESCE(?, accountname),
            branchid = COALESCE(?, branchid),
            updated_at = ?
        WHERE companyid = ?
      `,
      args: [
        companyname !== undefined ? companyname.trim() : null,
        gstno !== undefined ? gstno.trim() : null,
        mobilenumber !== undefined ? mobilenumber.trim() : null,
        address !== undefined ? address.trim() : null,
        city !== undefined ? city.trim() : null,
        state !== undefined ? state.trim() : null,
        state_id !== undefined ? Number(state_id) : null,
        country !== undefined ? country.trim() : null,
        country_id !== undefined ? Number(country_id) : null,
        accountname !== undefined ? accountname.trim() : null,
        branchidStr !== undefined ? String(branchidStr).trim() : null,
        now,
        String(companyId).trim().toUpperCase(),
      ],
    });

    return res.json({
      success: true,
      message: "Company updated successfully!",
    });
  } catch (error) {
    console.error("updateCompanyController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update company.",
    });
  }
}

/**
 * DELETE /api/tenant/companies/:id
 * Deletes a company record by companyid.
 */
export async function deleteCompanyController(req, res) {
  try {
    const companyId = req.params.id;
    if (!companyId) {
      return res.status(400).json({ success: false, message: "Company ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureCompanyTable(client);

    const result = await client.execute({
      sql: `DELETE FROM company WHERE companyid = ?;`,
      args: [String(companyId).trim().toUpperCase()],
    });

    return res.json({
      success: true,
      message: "Company deleted successfully!",
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteCompanyController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete company.",
    });
  }
}
