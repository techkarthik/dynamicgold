import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure the tax_master table exists in the tenant's PostgreSQL schema.
 */
async function ensureTaxMasterTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`tax_master:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS tax_master (
        taxid INTEGER PRIMARY KEY AUTOINCREMENT,
        taxcode TEXT NOT NULL UNIQUE,
        taxname TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        sgstacname TEXT DEFAULT '',
        cgst_per REAL DEFAULT 0.0,
        cgstacname TEXT DEFAULT '',
        igst_per REAL DEFAULT 0.0,
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
  });
}

/**
 * GET /api/tenant/tax-master
 * Retrieves all tax master records for the authenticated tenant.
 */
export async function getTaxMasterController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureTaxMasterTable(client);

    const result = await client.execute(`
      SELECT * FROM tax_master 
      ORDER BY created_at DESC;
    `);

    return res.json({
      success: true,
      taxRecords: result.rows || [],
    });
  } catch (error) {
    console.error("getTaxMasterController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch tax records.",
    });
  }
}

/**
 * POST /api/tenant/tax-master
 * Inserts a new tax master record.
 */
export async function createTaxMasterController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureTaxMasterTable(client);

    const {
      taxcode,
      taxname,
      sgst_per = 0.0,
      sgstacname = "",
      cgst_per = 0.0,
      cgstacname = "",
      igst_per = 0.0,
      igstacname = "",
    } = req.body;

    if (!taxcode || !taxcode.trim()) {
      return res.status(400).json({
        success: false,
        message: "Tax code is required.",
      });
    }

    const cleanTaxCode = taxcode.trim().toUpperCase();
    if (cleanTaxCode.length > 3) {
      return res.status(400).json({
        success: false,
        message: "Tax code must be at most 3 characters.",
      });
    }

    if (!taxname || !taxname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Tax name is required.",
      });
    }

    // Check if Tax Code already exists
    const checkExists = await client.execute({
      sql: `SELECT taxid FROM tax_master WHERE taxcode = ? LIMIT 1;`,
      args: [cleanTaxCode],
    });

    if (checkExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Tax code "${cleanTaxCode}" already exists. Please choose a unique code.`,
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO tax_master (
          taxcode, taxname, sgst_per, sgstacname, cgst_per, cgstacname, igst_per, igstacname, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        cleanTaxCode,
        taxname.trim(),
        Number(sgst_per) || 0.0,
        sgstacname.trim(),
        Number(cgst_per) || 0.0,
        cgstacname.trim(),
        Number(igst_per) || 0.0,
        igstacname.trim(),
        now,
        now,
      ],
    });

    const newId = Number(insertResult.lastInsertRowid);

    return res.status(201).json({
      success: true,
      message: "Tax Master record created successfully!",
      taxRecord: {
        taxid: newId,
        taxcode: cleanTaxCode,
        taxname: taxname.trim(),
        sgst_per: Number(sgst_per) || 0.0,
        sgstacname: sgstacname.trim(),
        cgst_per: Number(cgst_per) || 0.0,
        cgstacname: cgstacname.trim(),
        igst_per: Number(igst_per) || 0.0,
        igstacname: igstacname.trim(),
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createTaxMasterController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create tax master record.",
    });
  }
}

/**
 * PUT /api/tenant/tax-master/:id
 * Updates an existing tax master record by taxid.
 */
export async function updateTaxMasterController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Tax Master ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureTaxMasterTable(client);

    const {
      taxcode,
      taxname,
      sgst_per,
      sgstacname,
      cgst_per,
      cgstacname,
      igst_per,
      igstacname,
    } = req.body;

    if (taxcode !== undefined && (!taxcode || !taxcode.trim())) {
      return res.status(400).json({
        success: false,
        message: "Tax code cannot be empty.",
      });
    }

    if (taxcode !== undefined && taxcode.trim().length > 3) {
      return res.status(400).json({
        success: false,
        message: "Tax code must be at most 3 characters.",
      });
    }

    if (taxname !== undefined && (!taxname || !taxname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Tax name cannot be empty.",
      });
    }

    // If changing tax code, verify uniqueness
    if (taxcode !== undefined) {
      const cleanTaxCode = taxcode.trim().toUpperCase();
      const checkExists = await client.execute({
        sql: `SELECT taxid FROM tax_master WHERE taxcode = ? AND taxid != ? LIMIT 1;`,
        args: [cleanTaxCode, Number(id)],
      });
      if (checkExists.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: `Tax code "${cleanTaxCode}" is already in use by another record.`,
        });
      }
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE tax_master
        SET taxcode = COALESCE(?, taxcode),
            taxname = COALESCE(?, taxname),
            sgst_per = COALESCE(?, sgst_per),
            sgstacname = COALESCE(?, sgstacname),
            cgst_per = COALESCE(?, cgst_per),
            cgstacname = COALESCE(?, cgstacname),
            igst_per = COALESCE(?, igst_per),
            igstacname = COALESCE(?, igstacname),
            updated_at = ?
        WHERE taxid = ?
      `,
      args: [
        taxcode !== undefined ? taxcode.trim().toUpperCase() : null,
        taxname !== undefined ? taxname.trim() : null,
        sgst_per !== undefined ? Number(sgst_per) : null,
        sgstacname !== undefined ? sgstacname.trim() : null,
        cgst_per !== undefined ? Number(cgst_per) : null,
        cgstacname !== undefined ? cgstacname.trim() : null,
        igst_per !== undefined ? Number(igst_per) : null,
        igstacname !== undefined ? igstacname.trim() : null,
        now,
        Number(id),
      ],
    });

    return res.json({
      success: true,
      message: "Tax Master updated successfully!",
    });
  } catch (error) {
    console.error("updateTaxMasterController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update tax master record.",
    });
  }
}

/**
 * DELETE /api/tenant/tax-master/:id
 * Deletes a tax master record by taxid.
 */
export async function deleteTaxMasterController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Tax Master ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureTaxMasterTable(client);

    const result = await client.execute({
      sql: `DELETE FROM tax_master WHERE taxid = ?;`,
      args: [Number(id)],
    });

    return res.json({
      success: true,
      message: "Tax Master deleted successfully!",
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteTaxMasterController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete tax master record.",
    });
  }
}
