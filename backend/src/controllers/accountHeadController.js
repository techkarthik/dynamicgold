import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure the account_heads and account_head_options tables exist in the tenant's PostgreSQL schema.
 */
async function ensureAccountHeadsTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`account_heads:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS account_heads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accode TEXT UNIQUE NOT NULL,
        groupname TEXT NOT NULL,
        accountname TEXT NOT NULL,
        accounttype TEXT DEFAULT 'OTHER',
        bank_details TEXT DEFAULT '[]',
        address_line1 TEXT DEFAULT '',
        address_line2 TEXT DEFAULT '',
        city TEXT DEFAULT '',
        state TEXT DEFAULT '',
        country TEXT DEFAULT 'India',
        pincode TEXT DEFAULT '',
        phone_no TEXT DEFAULT '',
        email TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        gstno TEXT DEFAULT '',
        panno TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN accounttype TEXT DEFAULT 'OTHER';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN bank_details TEXT DEFAULT '[]';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN address_line1 TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN address_line2 TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN city TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN phone_no TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE account_heads ADD COLUMN email TEXT DEFAULT '';`);
    } catch (_) {}

    await client.execute(`
      CREATE TABLE IF NOT EXISTS account_head_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        option_type TEXT NOT NULL,
        option_value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(option_type, option_value)
      );
    `);
  });
}

/**
 * Helper to record custom option in account_head_options table.
 */
async function recordCustomOption(client, optionType, optionValue) {
  if (!optionValue || !optionValue.trim()) return;
  try {
    const now = new Date().toISOString();
    await client.execute({
      sql: `INSERT OR IGNORE INTO account_head_options (option_type, option_value, created_at) VALUES (?, ?, ?);`,
      args: [optionType.trim().toUpperCase(), optionValue.trim(), now],
    });
  } catch (_) {}
}

/**
 * Helper to generate a 7-character alphanumeric code.
 */
function generateAccode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 7; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Helper to parse/normalize bank_details
 */
function normalizeBankDetails(val) {
  if (!val) return [];
  if (Array.isArray(val)) return val;
  if (typeof val === "string") {
    try {
      const parsed = JSON.parse(val);
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }
  return [];
}

/**
 * GET /api/tenant/account-heads
 * Retrieves all account heads and custom options for the authenticated tenant.
 */
export async function getAccountHeadsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const result = await client.execute(`
      SELECT * FROM account_heads 
      ORDER BY created_at DESC;
    `);

    const optionsResult = await client.execute(`
      SELECT option_type, option_value FROM account_head_options ORDER BY id ASC;
    `);

    const customAccountTypes = (optionsResult.rows || [])
      .filter((r) => r.option_type === "ACCOUNT_TYPE")
      .map((r) => r.option_value);

    const customFinancialGroups = (optionsResult.rows || [])
      .filter((r) => r.option_type === "FINANCIAL_GROUP")
      .map((r) => r.option_value);

    const formattedRows = (result.rows || []).map((row) => ({
      ...row,
      bank_details: normalizeBankDetails(row.bank_details),
    }));

    return res.json({
      success: true,
      accountHeads: formattedRows,
      customAccountTypes,
      customFinancialGroups,
    });
  } catch (error) {
    console.error("getAccountHeadsController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch account heads.",
    });
  }
}

/**
 * GET /api/tenant/account-heads/options
 * Retrieves all custom account types and financial groups.
 */
export async function getAccountHeadOptionsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const optionsResult = await client.execute(`
      SELECT * FROM account_head_options ORDER BY id ASC;
    `);

    return res.json({
      success: true,
      options: optionsResult.rows || [],
    });
  } catch (error) {
    console.error("getAccountHeadOptionsController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch account head options.",
    });
  }
}

/**
 * POST /api/tenant/account-heads/options
 * Adds a new custom account type or financial group option.
 */
export async function createAccountHeadOptionController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const { option_type, option_value } = req.body;

    if (!option_type || !option_type.trim()) {
      return res.status(400).json({
        success: false,
        message: "Option type is required (e.g. ACCOUNT_TYPE or FINANCIAL_GROUP).",
      });
    }

    if (!option_value || !option_value.trim()) {
      return res.status(400).json({
        success: false,
        message: "Option value cannot be empty.",
      });
    }

    const typeNormalized = option_type.trim().toUpperCase();
    const valueTrimmed = option_value.trim();
    const now = new Date().toISOString();

    await client.execute({
      sql: `INSERT OR IGNORE INTO account_head_options (option_type, option_value, created_at) VALUES (?, ?, ?);`,
      args: [typeNormalized, valueTrimmed, now],
    });

    return res.status(201).json({
      success: true,
      message: "Option saved successfully!",
      option: {
        option_type: typeNormalized,
        option_value: valueTrimmed,
        created_at: now,
      },
    });
  } catch (error) {
    console.error("createAccountHeadOptionController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to save account head option.",
    });
  }
}

/**
 * POST /api/tenant/account-heads
 * Inserts a new account head. Autogenerates a 7-digit alphanumeric accode.
 */
export async function createAccountHeadController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const {
      groupname,
      accountname,
      accounttype = "OTHER",
      bank_details = [],
      address_line1 = "",
      address_line2 = "",
      city = "",
      state = "",
      country = "India",
      pincode = "",
      phone_no = "",
      email = "",
      active = 1,
      gstno = "",
      panno = "",
    } = req.body;

    if (!groupname || !groupname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Group name is required.",
      });
    }

    if (!accountname || !accountname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Account name is required.",
      });
    }

    const resolvedAccountType = accounttype && accounttype.trim() ? accounttype.trim().toUpperCase() : "OTHER";
    const resolvedGroupName = groupname.trim();
    const normalizedBanks = normalizeBankDetails(bank_details);
    const bankDetailsJson = JSON.stringify(normalizedBanks);

    // Generate a unique 7-digit alphanumeric accode
    let accode = "";
    let isUnique = false;
    let attempts = 0;
    while (!isUnique && attempts < 10) {
      accode = generateAccode();
      const existing = await client.execute({
        sql: "SELECT id FROM account_heads WHERE accode = ? LIMIT 1;",
        args: [accode],
      });
      if (existing.rows.length === 0) {
        isUnique = true;
      }
      attempts++;
    }

    if (!isUnique) {
      return res.status(500).json({
        success: false,
        message: "Failed to generate a unique account code.",
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO account_heads (
          accode, groupname, accountname, accounttype, bank_details,
          address_line1, address_line2, city, state, country, pincode, phone_no, email,
          active, gstno, panno, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        accode,
        resolvedGroupName,
        accountname.trim(),
        resolvedAccountType,
        bankDetailsJson,
        address_line1.trim(),
        address_line2.trim(),
        city.trim(),
        state.trim(),
        country.trim(),
        pincode.trim(),
        phone_no.trim(),
        email.trim(),
        Number(active) === 0 ? 0 : 1,
        gstno.trim(),
        panno.trim(),
        now,
        now,
      ],
    });

    const newId = Number(insertResult.lastInsertRowid);

    // Record options asynchronously for persistent dropdown lists
    await recordCustomOption(client, "ACCOUNT_TYPE", resolvedAccountType);
    await recordCustomOption(client, "FINANCIAL_GROUP", resolvedGroupName);

    return res.status(201).json({
      success: true,
      message: "Account Head created successfully!",
      accountHead: {
        id: newId,
        accode,
        groupname: resolvedGroupName,
        accountname: accountname.trim(),
        accounttype: resolvedAccountType,
        bank_details: normalizedBanks,
        address_line1: address_line1.trim(),
        address_line2: address_line2.trim(),
        city: city.trim(),
        state: state.trim(),
        country: country.trim(),
        pincode: pincode.trim(),
        phone_no: phone_no.trim(),
        email: email.trim(),
        active: Number(active) === 0 ? 0 : 1,
        gstno: gstno.trim(),
        panno: panno.trim(),
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create account head.",
    });
  }
}

/**
 * PUT /api/tenant/account-heads/:id
 * Updates an existing account head by ID.
 */
export async function updateAccountHeadController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Account Head ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const {
      groupname,
      accountname,
      accounttype,
      bank_details,
      address_line1,
      address_line2,
      city,
      state,
      country,
      pincode,
      phone_no,
      email,
      active,
      gstno,
      panno,
    } = req.body;

    if (groupname !== undefined && (!groupname || !groupname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Group name cannot be empty.",
      });
    }

    if (accountname !== undefined && (!accountname || !accountname.trim())) {
      return res.status(400).json({
        success: false,
        message: "Account name cannot be empty.",
      });
    }

    const now = new Date().toISOString();
    const resolvedAccountType = accounttype !== undefined ? (accounttype ? accounttype.trim().toUpperCase() : "OTHER") : null;
    const resolvedGroupName = groupname !== undefined ? groupname.trim() : null;
    const bankDetailsJson = bank_details !== undefined ? JSON.stringify(normalizeBankDetails(bank_details)) : null;

    await client.execute({
      sql: `
        UPDATE account_heads
        SET groupname = COALESCE(?, groupname),
          accountname = COALESCE(?, accountname),
          accounttype = COALESCE(?, accounttype),
          bank_details = COALESCE(?, bank_details),
          address_line1 = COALESCE(?, address_line1),
          address_line2 = COALESCE(?, address_line2),
          city = COALESCE(?, city),
          state = COALESCE(?, state),
          country = COALESCE(?, country),
          pincode = COALESCE(?, pincode),
          phone_no = COALESCE(?, phone_no),
          email = COALESCE(?, email),
          active = COALESCE(?, active),
          gstno = COALESCE(?, gstno),
          panno = COALESCE(?, panno),
          updated_at = ?
        WHERE id = ?
      `,
      args: [
        resolvedGroupName,
        accountname !== undefined ? accountname.trim() : null,
        resolvedAccountType,
        bankDetailsJson,
        address_line1 !== undefined ? address_line1.trim() : null,
        address_line2 !== undefined ? address_line2.trim() : null,
        city !== undefined ? city.trim() : null,
        state !== undefined ? state.trim() : null,
        country !== undefined ? country.trim() : null,
        pincode !== undefined ? pincode.trim() : null,
        phone_no !== undefined ? phone_no.trim() : null,
        email !== undefined ? email.trim() : null,
        active !== undefined ? (Number(active) === 0 ? 0 : 1) : null,
        gstno !== undefined ? gstno.trim() : null,
        panno !== undefined ? panno.trim() : null,
        now,
        Number(id),
      ],
    });

    if (resolvedAccountType) {
      await recordCustomOption(client, "ACCOUNT_TYPE", resolvedAccountType);
    }
    if (resolvedGroupName) {
      await recordCustomOption(client, "FINANCIAL_GROUP", resolvedGroupName);
    }

    return res.json({
      success: true,
      message: "Account Head updated successfully!",
    });
  } catch (error) {
    console.error("updateAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update account head.",
    });
  }
}

/**
 * DELETE /api/tenant/account-heads/:id
 * Deletes an account head by ID.
 */
export async function deleteAccountHeadController(req, res) {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: "Account Head ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureAccountHeadsTable(client);

    const result = await client.execute({
      sql: `DELETE FROM account_heads WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({
      success: true,
      message: "Account Head deleted successfully!",
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteAccountHeadController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete account head.",
    });
  }
}
