import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure metals, purities, and categories tables exist in the tenant's PostgreSQL schema.
 */
export async function ensureInventoryTables(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`inventory_tables:${key}`, async () => {
    // Metals
    await client.execute(`
      CREATE TABLE IF NOT EXISTS metals (
        metalid TEXT PRIMARY KEY NOT NULL,
        metalname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Purities
    await client.execute(`
      CREATE TABLE IF NOT EXISTS purities (
        purityid INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purityshortname TEXT NOT NULL,
        purity REAL NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid)
      );
    `);

    // Categories (Refactored)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        purityid INTEGER,
        catcode TEXT UNIQUE NOT NULL,
        catname TEXT NOT NULL,
        categorytype TEXT NOT NULL,
        sgst_per REAL DEFAULT 0.0,
        cgst_per REAL DEFAULT 0.0,
        igst_per REAL DEFAULT 0.0,
        sales_accode TEXT DEFAULT '',
        purchase_accode TEXT DEFAULT '',
        sgst_accode TEXT DEFAULT '',
        cgst_accode TEXT DEFAULT '',
        igst_accode TEXT DEFAULT '',
        salesacname TEXT DEFAULT '',
        purchaseacname TEXT DEFAULT '',
        sgstacname TEXT DEFAULT '',
        cgstacname TEXT DEFAULT '',
        igstacname TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (metalid) REFERENCES metals(metalid),
        FOREIGN KEY (purityid) REFERENCES purities(purityid)
      );
    `);

    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN purityid INTEGER;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN sales_accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN purchase_accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN sgst_accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN cgst_accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN igst_accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN salesacname TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN purchaseacname TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN catname TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN catcode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN categorytype TEXT DEFAULT 'ORNAMENTS';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN sgst_per REAL DEFAULT 1.5;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN cgst_per REAL DEFAULT 1.5;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE categories ADD COLUMN igst_per REAL DEFAULT 3.0;`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE categories SET catname = name WHERE (catname IS NULL OR catname = '') AND name IS NOT NULL AND name != '';`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE categories SET catcode = code WHERE (catcode IS NULL OR catcode = '') AND code IS NOT NULL AND code != '';`);
    } catch (_) { }

    // Products (New 4th Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS products (
        productid INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryid INTEGER NOT NULL,
        productname TEXT NOT NULL,
        calctype TEXT NOT NULL DEFAULT 'WEIGHT',
        stocktype TEXT NOT NULL DEFAULT 'SKU',
        havestone_diamond TEXT NOT NULL DEFAULT 'NO',
        havesubproduct TEXT NOT NULL DEFAULT 'NO',
        studded TEXT NOT NULL DEFAULT 'N',
        diastone TEXT NOT NULL DEFAULT '',
        hsncode TEXT NOT NULL DEFAULT '',
        stoneunit TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (categoryid) REFERENCES categories(id)
      );
    `);

    try {
      await client.execute(`ALTER TABLE products ADD COLUMN productid INTEGER;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN categoryid INTEGER DEFAULT 0;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN productname TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN calctype TEXT DEFAULT 'WEIGHT';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN stocktype TEXT DEFAULT 'SKU';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN havestone_diamond TEXT DEFAULT 'NO';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN havesubproduct TEXT DEFAULT 'NO';`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE products SET productname = title WHERE (productname IS NULL OR productname = '') AND title IS NOT NULL AND title != '';`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE products SET productid = id WHERE (productid IS NULL OR productid = 0) AND id IS NOT NULL;`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE products SET categoryid = category_id WHERE (categoryid IS NULL OR categoryid = 0) AND category_id IS NOT NULL;`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN studded TEXT DEFAULT 'N';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN diastone TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN hsncode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE products ADD COLUMN stoneunit TEXT DEFAULT '';`);
    } catch (_) { }

    try {
      await client.execute(`
        CREATE UNIQUE INDEX IF NOT EXISTS idx_products_productname_unique ON products (UPPER(TRIM(productname)));
      `);
    } catch (_) { }

    // Sub-Products (New 5th Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS subproducts (
        subproductid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        subproductname TEXT NOT NULL,
        havestone_diamond TEXT NOT NULL DEFAULT 'NO',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, subproductname)
      );
    `);

    // Styles (6th Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS styles (
        styleid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        stylename TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, stylename)
      );
    `);

    // Sizes (7th Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS sizes (
        sizeid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        sizename TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        UNIQUE (productid, sizename)
      );
    `);

    // Price Setting (8th Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS pricesetting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyid TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        productid INTEGER NOT NULL,
        subproductid INTEGER DEFAULT NULL,
        accode TEXT NOT NULL,
        weight_from REAL NOT NULL DEFAULT 0.0,
        weight_to REAL NOT NULL DEFAULT 0.0,
        va_percent REAL NOT NULL DEFAULT 0.0,
        wastage REAL NOT NULL DEFAULT 0.0,
        mc_per_gram REAL NOT NULL DEFAULT 0.0,
        m_charge REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        FOREIGN KEY (subproductid) REFERENCES subproducts(subproductid)
      );
    `);

    try {
      await client.execute(`ALTER TABLE pricesetting ADD COLUMN branchid TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE pricesetting ADD COLUMN companyid TEXT DEFAULT '';`);
    } catch (_) { }

    // Diamond Price Setting (Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS diamondpricesetting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyid TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        productid INTEGER NOT NULL,
        subproductid INTEGER DEFAULT NULL,
        accode TEXT NOT NULL,
        from_cent REAL NOT NULL DEFAULT 0.0,
        to_cent REAL NOT NULL DEFAULT 0.0,
        cent_rate REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        FOREIGN KEY (subproductid) REFERENCES subproducts(subproductid)
      );
    `);

    try {
      await client.execute(`ALTER TABLE diamondpricesetting ADD COLUMN branchid TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE diamondpricesetting ADD COLUMN companyid TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE diamondpricesetting ADD COLUMN subproductid INTEGER DEFAULT NULL;`);
    } catch (_) { }

    // Designers (Master under Inventory)
    await client.execute(`
      CREATE TABLE IF NOT EXISTS designers (
        designerid INTEGER PRIMARY KEY AUTOINCREMENT,
        accode TEXT NOT NULL,
        designername TEXT NOT NULL,
        designershortname TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    try {
      await client.execute(`ALTER TABLE designers ADD COLUMN accode TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`ALTER TABLE designers ADD COLUMN designershortname TEXT DEFAULT '';`);
    } catch (_) { }
    try {
      await client.execute(`UPDATE designers SET accode = linked_accode WHERE (accode IS NULL OR accode = '') AND linked_accode IS NOT NULL AND linked_accode != '';`);
    } catch (_) { }

    try {
      await client.execute(`
        CREATE UNIQUE INDEX IF NOT EXISTS idx_designers_designername_unique ON designers (UPPER(TRIM(designername)));
      `);
    } catch (_) { }
  });
}

/**
 * Helper to determine Category Code Prefix (2 characters)
 * e.g., 'G' + 'ORNAMENTS' => 'GO'
 *       'G' + 'METAL'     => 'GB' (Gold Bar/Bullion)
 */
function getCategoryPrefix(metalId, categoryType) {
  const m = String(metalId).trim().toUpperCase().substring(0, 1);
  const typeClean = String(categoryType).trim().toUpperCase();
  const t = typeClean.includes("ORNAMENT") ? "O" : "B";
  return m + t;
}

// ==========================================
// 1. METALS CRUD CONTROLLERS
// ==========================================

export async function getMetalsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`SELECT * FROM metals ORDER BY metalname ASC;`);
    return res.json({ success: true, metals: result.rows || [] });
  } catch (error) {
    console.error("getMetals error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createMetalController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const { metalid, metalname } = req.body;

    if (!metalid || !metalid.trim()) {
      return res.status(400).json({ success: false, message: "Metal ID is required." });
    }
    const cleanId = metalid.trim().toUpperCase();
    if (cleanId.length > 2) {
      return res.status(400).json({ success: false, message: "Metal ID must be max 2 characters." });
    }

    if (!metalname || !metalname.trim()) {
      return res.status(400).json({ success: false, message: "Metal Name is required." });
    }

    // Check duplicate
    const checkDup = await client.execute({
      sql: `SELECT metalid FROM metals WHERE metalid = ? LIMIT 1;`,
      args: [cleanId],
    });
    if (checkDup.rows.length > 0) {
      return res.status(409).json({ success: false, message: `Metal ID "${cleanId}" already exists.` });
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `INSERT INTO metals (metalid, metalname, created_at, updated_at) VALUES (?, ?, ?, ?);`,
      args: [cleanId, metalname.trim(), now, now],
    });

    return res.status(201).json({
      success: true,
      message: "Metal created successfully!",
      metal: { metalid: cleanId, metalname: metalname.trim(), created_at: now, updated_at: now }
    });
  } catch (error) {
    console.error("createMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateMetalController(req, res) {
  try {
    const { id } = req.params; // metalid
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const { metalname } = req.body;
    if (!metalname || !metalname.trim()) {
      return res.status(400).json({ success: false, message: "Metal Name is required." });
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `UPDATE metals SET metalname = ?, updated_at = ? WHERE metalid = ?;`,
      args: [metalname.trim(), now, id.toUpperCase()],
    });

    return res.json({ success: true, message: "Metal updated successfully!" });
  } catch (error) {
    console.error("updateMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteMetalController(req, res) {
  try {
    const { id } = req.params; // metalid
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    // Verify dependencies in purities & categories
    const checkPurity = await client.execute({
      sql: `SELECT purityid FROM purities WHERE metalid = ? LIMIT 1;`,
      args: [id.toUpperCase()],
    });
    if (checkPurity.rows.length > 0) {
      return res.status(400).json({ success: false, message: "Cannot delete metal as it is linked to Purity master records." });
    }

    const checkCat = await client.execute({
      sql: `SELECT id FROM categories WHERE metalid = ? LIMIT 1;`,
      args: [id.toUpperCase()],
    });
    if (checkCat.rows.length > 0) {
      return res.status(400).json({ success: false, message: "Cannot delete metal as it is linked to Category master records." });
    }

    await client.execute({
      sql: `DELETE FROM metals WHERE metalid = ?;`,
      args: [id.toUpperCase()],
    });

    return res.json({ success: true, message: "Metal deleted successfully!" });
  } catch (error) {
    console.error("deleteMetal error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 2. PURITIES CRUD CONTROLLERS
// ==========================================

export async function getPuritiesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT p.*, m.metalname 
      FROM purities p
      JOIN metals m ON p.metalid = m.metalid
      ORDER BY p.purity DESC;
    `);
    return res.json({ success: true, purities: result.rows || [] });
  } catch (error) {
    console.error("getPurities error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createPurityController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const { metalid, purityname, purityshortname, purity, type } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!purityname || !purityname.trim()) return res.status(400).json({ success: false, message: "Purity Name is required." });
    if (!purityshortname || !purityshortname.trim()) return res.status(400).json({ success: false, message: "Purity Short Name is required." });
    if (purity === undefined || isNaN(Number(purity))) return res.status(400).json({ success: false, message: "Purity percentage numeric value is required." });
    if (!type || (type !== 'ORNAMENT' && type !== 'METAL')) return res.status(400).json({ success: false, message: "Purity Type must be ORNAMENT or METAL." });

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        INSERT INTO purities (metalid, purityname, purityshortname, purity, type, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        metalid.toUpperCase(),
        purityname.trim(),
        purityshortname.trim(),
        Number(purity),
        type,
        now,
        now,
      ],
    });

    return res.status(201).json({ success: true, message: "Purity Master record created successfully!" });
  } catch (error) {
    console.error("createPurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updatePurityController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const { metalid, purityname, purityshortname, purity, type } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!purityname || !purityname.trim()) return res.status(400).json({ success: false, message: "Purity Name is required." });
    if (!purityshortname || !purityshortname.trim()) return res.status(400).json({ success: false, message: "Purity Short Name is required." });
    if (purity === undefined || isNaN(Number(purity))) return res.status(400).json({ success: false, message: "Purity value is required." });
    if (!type || (type !== 'ORNAMENT' && type !== 'METAL')) return res.status(400).json({ success: false, message: "Purity Type must be ORNAMENT or METAL." });

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        UPDATE purities
        SET metalid = ?,
            purityname = ?,
            purityshortname = ?,
            purity = ?,
            type = ?,
            updated_at = ?
        WHERE purityid = ?;
      `,
      args: [
        metalid.toUpperCase(),
        purityname.trim(),
        purityshortname.trim(),
        Number(purity),
        type,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Purity updated successfully!" });
  } catch (error) {
    console.error("updatePurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deletePurityController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM purities WHERE purityid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Purity record deleted successfully!" });
  } catch (error) {
    console.error("deletePurity error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * Helper to auto-create / ensure an Account Head in account_heads table, returning its accode.
 */
async function ensureAccountHead(client, accountName, groupName) {
  if (!accountName || !accountName.trim()) return "";
  const trimmedName = accountName.trim().toUpperCase();
  try {
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

    const existing = await client.execute({
      sql: `SELECT accode FROM account_heads WHERE UPPER(TRIM(accountname)) = ? LIMIT 1;`,
      args: [trimmedName],
    });

    if (existing.rows.length > 0) {
      return String(existing.rows[0].accode || "").trim();
    }

    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let accode = "";
    let isUnique = false;
    let attempts = 0;
    while (!isUnique && attempts < 10) {
      accode = "";
      for (let i = 0; i < 7; i++) {
        accode += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      const checkCode = await client.execute({
        sql: `SELECT id FROM account_heads WHERE accode = ? LIMIT 1;`,
        args: [accode],
      });
      if (checkCode.rows.length === 0) isUnique = true;
      attempts++;
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        INSERT INTO account_heads (
          accode, groupname, accountname, accounttype, active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
      `,
      args: [accode, groupName, trimmedName, 'INTERNAL', 1, now, now],
    });
    return accode;
  } catch (err) {
    console.error("ensureAccountHead error:", err);
    return "";
  }
}

// ==========================================
// 3. CATEGORIES CRUD CONTROLLERS
// ==========================================

export async function getCategoriesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT 
        c.*, 
        m.metalname, 
        p.purityname, 
        p.purityshortname, 
        p.purity,
        COALESCE(ah_sales.accountname, c.salesacname, '') AS salesacname,
        COALESCE(ah_purch.accountname, c.purchaseacname, '') AS purchaseacname,
        COALESCE(ah_sgst.accountname, c.sgstacname, '') AS sgstacname,
        COALESCE(ah_cgst.accountname, c.cgstacname, '') AS cgstacname,
        COALESCE(ah_igst.accountname, c.igstacname, '') AS igstacname
      FROM categories c
      JOIN metals m ON c.metalid = m.metalid
      LEFT JOIN purities p ON c.purityid = p.purityid
      LEFT JOIN account_heads ah_sales ON (c.sales_accode != '' AND c.sales_accode = ah_sales.accode)
      LEFT JOIN account_heads ah_purch ON (c.purchase_accode != '' AND c.purchase_accode = ah_purch.accode)
      LEFT JOIN account_heads ah_sgst ON (c.sgst_accode != '' AND c.sgst_accode = ah_sgst.accode)
      LEFT JOIN account_heads ah_cgst ON (c.cgst_accode != '' AND c.cgst_accode = ah_cgst.accode)
      LEFT JOIN account_heads ah_igst ON (c.igst_accode != '' AND c.igst_accode = ah_igst.accode)
      ORDER BY c.created_at DESC;
    `);
    return res.json({ success: true, categories: result.rows || [] });
  } catch (error) {
    console.error("getCategories error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createCategoryController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      metalid,
      purityid,
      catname,
      categorytype,
      sgst_per = 0.0,
      cgst_per = 0.0,
      igst_per = 0.0,
      sales_accode = "",
      purchase_accode = "",
      sgst_accode = "",
      cgst_accode = "",
      igst_accode = "",
      salesacname = "",
      purchaseacname = "",
      sgstacname = "",
      cgstacname = "",
      igstacname = "",
    } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!catname || !catname.trim()) return res.status(400).json({ success: false, message: "Category Name is required." });
    if (!categorytype || (categorytype !== 'METAL' && categorytype !== 'ORNAMENTS/STONE')) {
      return res.status(400).json({ success: false, message: "Category Type must be METAL or ORNAMENTS/STONE." });
    }

    const cleanMetalId = metalid.trim().toUpperCase();
    const cleanPurityId = purityid ? Number(purityid) : null;

    // Fetch purity details if purityid is given
    let purityLabel = "";
    if (cleanPurityId) {
      const purityQuery = await client.execute({
        sql: `SELECT purityname, purityshortname FROM purities WHERE purityid = ? LIMIT 1;`,
        args: [cleanPurityId],
      });
      if (purityQuery.rows.length > 0) {
        const row = purityQuery.rows[0];
        purityLabel = (row.purityshortname || row.purityname || "").toString().trim();
      }
    }

    // Compute total GST percentage
    const totalGst = (Number(sgst_per) || 0) + (Number(cgst_per) || 0) || (Number(igst_per) || 0);
    const gstStr = totalGst > 0 ? `${totalGst % 1 === 0 ? totalGst.toFixed(0) : totalGst.toFixed(2)}%` : '';

    // Auto-generate Sales and Purchase Account Names if not explicitly provided
    const purityPart = purityLabel ? `${purityLabel} ` : '';
    const gstPart = gstStr ? `GST ${gstStr} ` : 'GST ';
    const autoSalesAcName = `${catname.trim()} ${purityPart}${gstPart}SALES`.replace(/\s+/g, ' ').trim().toUpperCase();
    const autoPurchaseAcName = `${catname.trim()} ${purityPart}${gstPart}PURCHASE`.replace(/\s+/g, ' ').trim().toUpperCase();

    // Resolve Sales accode
    let finalSalesAccode = (sales_accode && String(sales_accode).trim()) ? String(sales_accode).trim().toUpperCase() : "";
    let finalSalesAcName = (salesacname && String(salesacname).trim()) ? String(salesacname).trim().toUpperCase() : autoSalesAcName;
    if (!finalSalesAccode) {
      finalSalesAccode = await ensureAccountHead(client, finalSalesAcName, 'Sales Account');
    }

    // Resolve Purchase accode
    let finalPurchaseAccode = (purchase_accode && String(purchase_accode).trim()) ? String(purchase_accode).trim().toUpperCase() : "";
    let finalPurchaseAcName = (purchaseacname && String(purchaseacname).trim()) ? String(purchaseacname).trim().toUpperCase() : autoPurchaseAcName;
    if (!finalPurchaseAccode) {
      finalPurchaseAccode = await ensureAccountHead(client, finalPurchaseAcName, 'Purchase Account');
    }

    // Resolve tax accodes if names provided
    let finalSgstAccode = (sgst_accode && String(sgst_accode).trim()) ? String(sgst_accode).trim() : "";
    let finalCgstAccode = (cgst_accode && String(cgst_accode).trim()) ? String(cgst_accode).trim() : "";
    let finalIgstAccode = (igst_accode && String(igst_accode).trim()) ? String(igst_accode).trim() : "";

    // Generate unique sequential alphanumeric Category Code
    const prefix = getCategoryPrefix(cleanMetalId, categorytype);
    const codeQuery = await client.execute({
      sql: `SELECT catcode FROM categories WHERE catcode LIKE ? ORDER BY catcode DESC LIMIT 1;`,
      args: [`${prefix}%`],
    });

    let nextNum = 1;
    if (codeQuery.rows.length > 0) {
      const lastCode = String(codeQuery.rows[0].catcode);
      const numberPart = lastCode.substring(prefix.length);
      const parsed = parseInt(numberPart, 10);
      if (!isNaN(parsed)) {
        nextNum = parsed + 1;
      }
    }
    const catcode = prefix + String(nextNum).padStart(5, '0');

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        INSERT INTO categories (
          metalid, purityid, catcode, catname, categorytype, sgst_per, cgst_per, igst_per,
          sales_accode, purchase_accode, sgst_accode, cgst_accode, igst_accode,
          salesacname, purchaseacname, sgstacname, cgstacname, igstacname,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        cleanMetalId,
        cleanPurityId,
        catcode,
        catname.trim(),
        categorytype,
        Number(sgst_per) || 0.0,
        Number(cgst_per) || 0.0,
        Number(igst_per) || 0.0,
        finalSalesAccode,
        finalPurchaseAccode,
        finalSgstAccode,
        finalCgstAccode,
        finalIgstAccode,
        finalSalesAcName,
        finalPurchaseAcName,
        String(sgstacname || "").trim(),
        String(cgstacname || "").trim(),
        String(igstacname || "").trim(),
        now,
        now,
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Category created successfully!",
      catcode: catcode,
      sales_accode: finalSalesAccode,
      purchase_accode: finalPurchaseAccode,
      salesacname: finalSalesAcName,
      purchaseacname: finalPurchaseAcName,
    });
  } catch (error) {
    console.error("createCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateCategoryController(req, res) {
  try {
    const { id } = req.params; // category table auto-increment id
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      metalid,
      purityid,
      catname,
      categorytype,
      sgst_per,
      cgst_per,
      igst_per,
      sales_accode,
      purchase_accode,
      sgst_accode,
      cgst_accode,
      igst_accode,
      salesacname,
      purchaseacname,
      sgstacname,
      cgstacname,
      igstacname,
    } = req.body;

    if (!metalid) return res.status(400).json({ success: false, message: "Metal ID selection is required." });
    if (!catname || !catname.trim()) return res.status(400).json({ success: false, message: "Category Name is required." });
    if (!categorytype || (categorytype !== 'METAL' && categorytype !== 'ORNAMENTS/STONE')) {
      return res.status(400).json({ success: false, message: "Category Type must be METAL or ORNAMENTS/STONE." });
    }

    // Verify existing category
    const checkCat = await client.execute({
      sql: `SELECT metalid, categorytype, catcode, sales_accode, purchase_accode FROM categories WHERE id = ? LIMIT 1;`,
      args: [Number(id)],
    });

    if (checkCat.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Category record not found." });
    }

    let finalCatcode = checkCat.rows[0].catcode;
    const oldMetalid = checkCat.rows[0].metalid;
    const oldType = checkCat.rows[0].categorytype;

    // If metal id or category type is updated, regenerate code
    if (oldMetalid !== metalid.toUpperCase() || oldType !== categorytype) {
      const prefix = getCategoryPrefix(metalid, categorytype);
      const codeQuery = await client.execute({
        sql: `SELECT catcode FROM categories WHERE catcode LIKE ? ORDER BY catcode DESC LIMIT 1;`,
        args: [`${prefix}%`],
      });

      let nextNum = 1;
      if (codeQuery.rows.length > 0) {
        const lastCode = String(codeQuery.rows[0].catcode);
        const numberPart = lastCode.substring(prefix.length);
        const parsed = parseInt(numberPart, 10);
        if (!isNaN(parsed)) {
          nextNum = parsed + 1;
        }
      }
      finalCatcode = prefix + String(nextNum).padStart(5, '0');
    }

    const cleanPurityId = purityid !== undefined ? (purityid ? Number(purityid) : null) : null;

    let finalSalesAccode = sales_accode !== undefined ? String(sales_accode).trim().toUpperCase() : checkCat.rows[0].sales_accode;
    if (!finalSalesAccode && salesacname && salesacname.trim()) {
      finalSalesAccode = await ensureAccountHead(client, salesacname.trim(), 'Sales Account');
    }

    let finalPurchaseAccode = purchase_accode !== undefined ? String(purchase_accode).trim().toUpperCase() : checkCat.rows[0].purchase_accode;
    if (!finalPurchaseAccode && purchaseacname && purchaseacname.trim()) {
      finalPurchaseAccode = await ensureAccountHead(client, purchaseacname.trim(), 'Purchase Account');
    }

    const now = new Date().toISOString();
    await client.execute({
      sql: `
        UPDATE categories
        SET metalid = ?,
            purityid = ?,
            catcode = ?,
            catname = ?,
            categorytype = ?,
            sgst_per = ?,
            cgst_per = ?,
            igst_per = ?,
            sales_accode = ?,
            purchase_accode = ?,
            sgst_accode = ?,
            cgst_accode = ?,
            igst_accode = ?,
            salesacname = ?,
            purchaseacname = ?,
            sgstacname = ?,
            cgstacname = ?,
            igstacname = ?,
            updated_at = ?
        WHERE id = ?;
      `,
      args: [
        metalid.toUpperCase(),
        cleanPurityId,
        finalCatcode,
        catname.trim(),
        categorytype,
        sgst_per !== undefined ? Number(sgst_per) : 0.0,
        cgst_per !== undefined ? Number(cgst_per) : 0.0,
        igst_per !== undefined ? Number(igst_per) : 0.0,
        finalSalesAccode || "",
        finalPurchaseAccode || "",
        sgst_accode !== undefined ? String(sgst_accode).trim() : "",
        cgst_accode !== undefined ? String(cgst_accode).trim() : "",
        igst_accode !== undefined ? String(igst_accode).trim() : "",
        salesacname !== undefined ? String(salesacname).trim().toUpperCase() : "",
        purchaseacname !== undefined ? String(purchaseacname).trim().toUpperCase() : "",
        sgstacname !== undefined ? String(sgstacname).trim() : "",
        cgstacname !== undefined ? String(cgstacname).trim() : "",
        igstacname !== undefined ? String(igstacname).trim() : "",
        now,
        Number(id),
      ],
    });

    return res.json({
      success: true,
      message: "Category updated successfully!",
      catcode: finalCatcode,
      sales_accode: finalSalesAccode,
      purchase_accode: finalPurchaseAccode,
    });
  } catch (error) {
    console.error("updateCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteCategoryController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM categories WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Category deleted successfully!" });
  } catch (error) {
    console.error("deleteCategory error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 4. PRODUCTS CRUD CONTROLLERS (4th Inventory Master)
// ==========================================

export async function getProductsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT p.*, c.catname, c.catcode, c.categorytype, m.metalname, m.metalid
      FROM products p
      JOIN categories c ON p.categoryid = c.id
      JOIN metals m ON c.metalid = m.metalid
      ORDER BY p.productid DESC;
    `);

    // Get max/last productid
    const metaResult = await client.execute(`
      SELECT MAX(productid) AS max_id, COUNT(*) AS total_count FROM products;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const nextId = maxId + 1;
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);

    return res.json({
      success: true,
      products: result.rows || [],
      last_productid: maxId,
      next_productid: nextId,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("getProducts error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createProductController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      categoryid,
      productname,
      calctype = "WEIGHT",
      stocktype = "SKU",
      havestone_diamond = "NO",
      havesubproduct = "NO",
      studded = "N",
      diastone = "",
      hsncode = "",
      stoneunit = "",
    } = req.body;

    if (!categoryid) {
      return res.status(400).json({ success: false, message: "Category selection is required." });
    }

    if (!productname || !productname.trim()) {
      return res.status(400).json({ success: false, message: "Product Name is required." });
    }

    const cleanName = productname.trim().substring(0, 100);

    // Enforce Unique Product Name (Case-Insensitive)
    const checkDuplicate = await client.execute({
      sql: `SELECT productid FROM products WHERE UPPER(TRIM(productname)) = UPPER(?) LIMIT 1;`,
      args: [cleanName],
    });

    if (checkDuplicate.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Product name "${cleanName}" already exists. Product name must be unique.`,
      });
    }

    const validCalcTypes = ["WEIGHT", "RATE", "METAL", "FIXED"];
    const validStockTypes = ["SKU", "OPEN"];
    const validYesNo = ["YES", "NO"];
    const validYN = ["Y", "N"];
    const validDiaStone = ["D", "S", "P", ""];
    const validStoneUnits = ["CARAT", "GRAM", "CTS", "GMS", ""];

    const cleanCalc = validCalcTypes.includes(String(calctype).toUpperCase())
      ? String(calctype).toUpperCase()
      : "WEIGHT";

    const cleanStock = validStockTypes.includes(String(stocktype).toUpperCase())
      ? String(stocktype).toUpperCase()
      : "SKU";

    const cleanStone = validYesNo.includes(String(havestone_diamond).toUpperCase())
      ? String(havestone_diamond).toUpperCase()
      : "NO";

    const cleanSub = validYesNo.includes(String(havesubproduct).toUpperCase())
      ? String(havesubproduct).toUpperCase()
      : "NO";

    const cleanStudded = validYN.includes(String(studded).toUpperCase())
      ? String(studded).toUpperCase()
      : (cleanStone === "YES" ? "Y" : "N");

    const cleanDiaStone = validDiaStone.includes(String(diastone).toUpperCase())
      ? String(diastone).toUpperCase()
      : "";

    const cleanHsn = String(hsncode || "").trim();

    let cleanStoneUnit = validStoneUnits.includes(String(stoneunit).toUpperCase())
      ? String(stoneunit).toUpperCase()
      : "";
    if (cleanStoneUnit === "CTS") cleanStoneUnit = "CARAT";
    if (cleanStoneUnit === "GMS") cleanStoneUnit = "GRAM";

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO products (
          categoryid, productname, calctype, stocktype, havestone_diamond, havesubproduct,
          studded, diastone, hsncode, stoneunit, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        Number(categoryid),
        cleanName,
        cleanCalc,
        cleanStock,
        cleanStone,
        cleanSub,
        cleanStudded,
        cleanDiaStone,
        cleanHsn,
        cleanStoneUnit,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Product created successfully!",
      productid: newId,
    });
  } catch (error) {
    console.error("createProduct error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(409).json({
        success: false,
        message: "Product name already exists. Product name must be unique.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateProductController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      categoryid,
      productname,
      calctype = "WEIGHT",
      stocktype = "SKU",
      havestone_diamond = "NO",
      havesubproduct = "NO",
      studded = "N",
      diastone = "",
      hsncode = "",
      stoneunit = "",
    } = req.body;

    if (!categoryid) {
      return res.status(400).json({ success: false, message: "Category selection is required." });
    }

    if (!productname || !productname.trim()) {
      return res.status(400).json({ success: false, message: "Product Name is required." });
    }

    const cleanName = productname.trim().substring(0, 100);

    // Enforce Unique Product Name (Case-Insensitive) excluding current productid
    const checkDuplicate = await client.execute({
      sql: `SELECT productid FROM products WHERE UPPER(TRIM(productname)) = UPPER(?) AND productid != ? LIMIT 1;`,
      args: [cleanName, Number(id)],
    });

    if (checkDuplicate.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `Product name "${cleanName}" already exists. Product name must be unique.`,
      });
    }

    const validCalcTypes = ["WEIGHT", "RATE", "METAL", "FIXED"];
    const validStockTypes = ["SKU", "OPEN"];
    const validYesNo = ["YES", "NO"];
    const validYN = ["Y", "N"];
    const validDiaStone = ["D", "S", "P", ""];
    const validStoneUnits = ["CARAT", "GRAM", "CTS", "GMS", ""];

    const cleanCalc = validCalcTypes.includes(String(calctype).toUpperCase())
      ? String(calctype).toUpperCase()
      : "WEIGHT";

    const cleanStock = validStockTypes.includes(String(stocktype).toUpperCase())
      ? String(stocktype).toUpperCase()
      : "SKU";

    const cleanStone = validYesNo.includes(String(havestone_diamond).toUpperCase())
      ? String(havestone_diamond).toUpperCase()
      : "NO";

    const cleanSub = validYesNo.includes(String(havesubproduct).toUpperCase())
      ? String(havesubproduct).toUpperCase()
      : "NO";

    const cleanStudded = validYN.includes(String(studded).toUpperCase())
      ? String(studded).toUpperCase()
      : (cleanStone === "YES" ? "Y" : "N");

    const cleanDiaStone = validDiaStone.includes(String(diastone).toUpperCase())
      ? String(diastone).toUpperCase()
      : "";

    const cleanHsn = String(hsncode || "").trim();

    let cleanStoneUnit = validStoneUnits.includes(String(stoneunit).toUpperCase())
      ? String(stoneunit).toUpperCase()
      : "";
    if (cleanStoneUnit === "CTS") cleanStoneUnit = "CARAT";
    if (cleanStoneUnit === "GMS") cleanStoneUnit = "GRAM";

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE products
        SET categoryid = ?,
            productname = ?,
            calctype = ?,
            stocktype = ?,
            havestone_diamond = ?,
            havesubproduct = ?,
            studded = ?,
            diastone = ?,
            hsncode = ?,
            stoneunit = ?,
            updated_at = ?
        WHERE productid = ?;
      `,
      args: [
        Number(categoryid),
        cleanName,
        cleanCalc,
        cleanStock,
        cleanStone,
        cleanSub,
        cleanStudded,
        cleanDiaStone,
        cleanHsn,
        cleanStoneUnit,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Product updated successfully!" });
  } catch (error) {
    console.error("updateProduct error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(409).json({
        success: false,
        message: "Product name already exists. Product name must be unique.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteProductController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM products WHERE productid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Product deleted successfully!" });
  } catch (error) {
    console.error("deleteProduct error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 5. SUB-PRODUCTS CRUD CONTROLLERS (5th Inventory Master)
// ==========================================

export async function getSubProductsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT s.*, p.productname, p.havesubproduct, c.catname, c.catcode, m.metalname, m.metalid
      FROM subproducts s
      JOIN products p ON s.productid = p.productid
      JOIN categories c ON p.categoryid = c.id
      JOIN metals m ON c.metalid = m.metalid
      ORDER BY s.subproductid DESC;
    `);

    // Get max/last subproductid
    const metaResult = await client.execute(`
      SELECT MAX(subproductid) AS max_id, COUNT(*) AS total_count FROM subproducts;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const nextId = maxId + 1;
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);

    return res.json({
      success: true,
      subproducts: result.rows || [],
      last_subproductid: maxId,
      next_subproductid: nextId,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("getSubProducts error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createSubProductController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      subproductname,
      havestone_diamond = "NO",
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Parent Product selection is required." });
    }

    if (!subproductname || !subproductname.trim()) {
      return res.status(400).json({ success: false, message: "Sub-Product Name is required." });
    }

    const cleanName = subproductname.trim().substring(0, 100);
    const cleanStone = String(havestone_diamond).toUpperCase() === "YES" ? "YES" : "NO";

    // 1. Verify parent product exists and has havesubproduct = 'YES'
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname, havesubproduct FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Parent Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];
    if (String(parentProd.havesubproduct).toUpperCase() !== "YES") {
      return res.status(400).json({
        success: false,
        message: `Product '${parentProd.productname}' does not have 'HAVE SUB-PRODUCT' enabled. Please enable it in Product Master first.`,
      });
    }

    // 2. Check uniqueness of (productid, subproductname)
    const duplicateCheck = await client.execute({
      sql: `SELECT subproductid FROM subproducts WHERE productid = ? AND LOWER(subproductname) = LOWER(?) LIMIT 1;`,
      args: [Number(productid), cleanName],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Sub-product '${cleanName}' already exists under '${parentProd.productname}'. Sub-product name must be unique within the product.`,
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO subproducts (
          productid, subproductname, havestone_diamond, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?);
      `,
      args: [
        Number(productid),
        cleanName,
        cleanStone,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Sub-Product created successfully!",
      subproductid: newId,
    });
  } catch (error) {
    console.error("createSubProduct error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateSubProductController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      subproductname,
      havestone_diamond = "NO",
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Parent Product selection is required." });
    }

    if (!subproductname || !subproductname.trim()) {
      return res.status(400).json({ success: false, message: "Sub-Product Name is required." });
    }

    const cleanName = subproductname.trim().substring(0, 100);
    const cleanStone = String(havestone_diamond).toUpperCase() === "YES" ? "YES" : "NO";

    // 1. Verify parent product exists and has havesubproduct = 'YES'
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname, havesubproduct FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Parent Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];
    if (String(parentProd.havesubproduct).toUpperCase() !== "YES") {
      return res.status(400).json({
        success: false,
        message: `Product '${parentProd.productname}' does not have 'HAVE SUB-PRODUCT' enabled.`,
      });
    }

    // 2. Check uniqueness of (productid, subproductname) for other records
    const duplicateCheck = await client.execute({
      sql: `SELECT subproductid FROM subproducts WHERE productid = ? AND LOWER(subproductname) = LOWER(?) AND subproductid != ? LIMIT 1;`,
      args: [Number(productid), cleanName, Number(id)],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Sub-product '${cleanName}' already exists under '${parentProd.productname}'.`,
      });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE subproducts
        SET productid = ?,
            subproductname = ?,
            havestone_diamond = ?,
            updated_at = ?
        WHERE subproductid = ?;
      `,
      args: [
        Number(productid),
        cleanName,
        cleanStone,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Sub-Product updated successfully!" });
  } catch (error) {
    console.error("updateSubProduct error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteSubProductController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM subproducts WHERE subproductid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Sub-Product deleted successfully!" });
  } catch (error) {
    console.error("deleteSubProduct error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 6. STYLES CRUD CONTROLLERS (6th Inventory Master)
// ==========================================

export async function getStylesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT s.*, p.productname, c.catname, c.catcode, m.metalname, m.metalid
      FROM styles s
      LEFT JOIN products p ON s.productid = p.productid
      LEFT JOIN categories c ON p.categoryid = c.id
      LEFT JOIN metals m ON c.metalid = m.metalid
      ORDER BY s.styleid DESC;
    `);

    const metaResult = await client.execute(`
      SELECT MAX(styleid) AS max_id, COUNT(*) AS total_count FROM styles;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const nextId = maxId + 1;
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);

    return res.json({
      success: true,
      styles: result.rows || [],
      last_styleid: maxId,
      next_styleid: nextId,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("getStyles error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createStyleController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      stylename,
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!stylename || !stylename.trim()) {
      return res.status(400).json({ success: false, message: "Style Name is required." });
    }

    const cleanName = stylename.trim().substring(0, 100);

    // 1. Verify parent product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];

    // 2. Check uniqueness of (productid, stylename)
    const duplicateCheck = await client.execute({
      sql: `SELECT styleid FROM styles WHERE productid = ? AND UPPER(TRIM(stylename)) = UPPER(?) LIMIT 1;`,
      args: [Number(productid), cleanName],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Style '${cleanName}' already exists under '${parentProd.productname}'. Style name must be unique per product.`,
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO styles (
          productid, stylename, created_at, updated_at
        ) VALUES (?, ?, ?, ?);
      `,
      args: [
        Number(productid),
        cleanName,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Style created successfully!",
      styleid: newId,
    });
  } catch (error) {
    console.error("createStyle error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(400).json({
        success: false,
        message: "Style name already exists for this product.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateStyleController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      stylename,
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!stylename || !stylename.trim()) {
      return res.status(400).json({ success: false, message: "Style Name is required." });
    }

    const cleanName = stylename.trim().substring(0, 100);

    // 1. Verify parent product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];

    // 2. Check uniqueness of (productid, stylename) for other records
    const duplicateCheck = await client.execute({
      sql: `SELECT styleid FROM styles WHERE productid = ? AND UPPER(TRIM(stylename)) = UPPER(?) AND styleid != ? LIMIT 1;`,
      args: [Number(productid), cleanName, Number(id)],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Style '${cleanName}' already exists under '${parentProd.productname}'.`,
      });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE styles
        SET productid = ?,
            stylename = ?,
            updated_at = ?
        WHERE styleid = ?;
      `,
      args: [
        Number(productid),
        cleanName,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Style updated successfully!" });
  } catch (error) {
    console.error("updateStyle error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(400).json({
        success: false,
        message: "Style name already exists for this product.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteStyleController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM styles WHERE styleid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Style deleted successfully!" });
  } catch (error) {
    console.error("deleteStyle error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 7. SIZES CRUD CONTROLLERS (7th Inventory Master)
// ==========================================

export async function getSizesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT sz.*, p.productname, c.catname, c.catcode, m.metalname, m.metalid
      FROM sizes sz
      LEFT JOIN products p ON sz.productid = p.productid
      LEFT JOIN categories c ON p.categoryid = c.id
      LEFT JOIN metals m ON c.metalid = m.metalid
      ORDER BY sz.sizeid DESC;
    `);

    const metaResult = await client.execute(`
      SELECT MAX(sizeid) AS max_id, COUNT(*) AS total_count FROM sizes;
    `);

    const maxId = Number(metaResult.rows[0]?.max_id || 0);
    const nextId = maxId + 1;
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);

    return res.json({
      success: true,
      sizes: result.rows || [],
      last_sizeid: maxId,
      next_sizeid: nextId,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("getSizes error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createSizeController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      sizename,
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!sizename || !sizename.trim()) {
      return res.status(400).json({ success: false, message: "Size Name is required." });
    }

    const cleanName = sizename.trim().substring(0, 100);

    // 1. Verify parent product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];

    // 2. Check uniqueness of (productid, sizename)
    const duplicateCheck = await client.execute({
      sql: `SELECT sizeid FROM sizes WHERE productid = ? AND UPPER(TRIM(sizename)) = UPPER(?) LIMIT 1;`,
      args: [Number(productid), cleanName],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Size '${cleanName}' already exists under '${parentProd.productname}'. Size name must be unique per product.`,
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO sizes (
          productid, sizename, created_at, updated_at
        ) VALUES (?, ?, ?, ?);
      `,
      args: [
        Number(productid),
        cleanName,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Size created successfully!",
      sizeid: newId,
    });
  } catch (error) {
    console.error("createSize error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(400).json({
        success: false,
        message: "Size name already exists for this product.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateSizeController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      productid,
      sizename,
    } = req.body;

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!sizename || !sizename.trim()) {
      return res.status(400).json({ success: false, message: "Size Name is required." });
    }

    const cleanName = sizename.trim().substring(0, 100);

    // 1. Verify parent product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });

    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }

    const parentProd = prodCheck.rows[0];

    // 2. Check uniqueness of (productid, sizename) for other records
    const duplicateCheck = await client.execute({
      sql: `SELECT sizeid FROM sizes WHERE productid = ? AND UPPER(TRIM(sizename)) = UPPER(?) AND sizeid != ? LIMIT 1;`,
      args: [Number(productid), cleanName, Number(id)],
    });

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Size '${cleanName}' already exists under '${parentProd.productname}'.`,
      });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE sizes
        SET productid = ?,
            sizename = ?,
            updated_at = ?
        WHERE sizeid = ?;
      `,
      args: [
        Number(productid),
        cleanName,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Size updated successfully!" });
  } catch (error) {
    console.error("updateSize error:", error);
    if (error.message && error.message.includes("UNIQUE constraint failed")) {
      return res.status(400).json({
        success: false,
        message: "Size name already exists for this product.",
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteSizeController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM sizes WHERE sizeid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Size deleted successfully!" });
  } catch (error) {
    console.error("deleteSize error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 8. PRICE SETTING CRUD CONTROLLERS (8th Inventory Master)
// ==========================================

export async function getPriceSettingsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const companyClean = (req.query.companyid || "").toString().trim().toUpperCase();

    let sql = `
      SELECT 
        ps.id,
        COALESCE(ps.companyid, '') AS companyid,
        ps.branchid,
        COALESCE(b.branchname, '') AS branchname,
        COALESCE(b.companyid, '') AS branch_companyid,
        ps.productid,
        COALESCE(p.productname, '') AS productname,
        ps.subproductid,
        COALESCE(sp.subproductname, '') AS subproductname,
        ps.accode,
        COALESCE(ah.accountname, '') AS dealername,
        COALESCE(ah.accounttype, '') AS accounttype,
        ps.weight_from,
        ps.weight_to,
        ps.va_percent,
        ps.wastage,
        ps.mc_per_gram,
        ps.m_charge,
        ps.created_at,
        ps.updated_at
      FROM pricesetting ps
      LEFT JOIN branches b ON UPPER(TRIM(ps.branchid)) = UPPER(TRIM(b.branchid))
      LEFT JOIN products p ON ps.productid = p.productid
      LEFT JOIN subproducts sp ON ps.subproductid = sp.subproductid
      LEFT JOIN account_heads ah ON ps.accode = ah.accode
    `;
    const args = [];
    if (companyClean) {
      sql += ` WHERE (UPPER(TRIM(COALESCE(ps.companyid, ''))) = ? OR UPPER(TRIM(COALESCE(b.companyid, ''))) = ?)`;
      args.push(companyClean, companyClean);
    }
    sql += ` ORDER BY ps.branchid ASC, p.productname ASC, sp.subproductname ASC, ah.accountname ASC, ps.weight_from ASC;`;

    const result = await client.execute({ sql, args });

    return res.json({
      success: true,
      price_settings: result.rows || [],
      total_count: (result.rows || []).length,
    });
  } catch (error) {
    console.error("getPriceSettings error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getPriceSettingDealersController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT id, accode, groupname, accountname, accounttype
      FROM account_heads
      WHERE UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') AND active = 1
      ORDER BY accountname ASC;
    `);

    return res.json({
      success: true,
      dealers: result.rows || [],
    });
  } catch (error) {
    console.error("getPriceSettingDealers error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createPriceSettingController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      companyid = "",
      branchid = "",
      productid,
      subproductid,
      accode,
      weight_from,
      weight_to,
      va_percent,
      wastage,
      mc_per_gram,
      m_charge,
    } = req.body;

    const branchClean = (branchid || "").toString().trim().toUpperCase();
    let companyClean = (companyid || req.query.companyid || "").toString().trim().toUpperCase();

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Dealer selection is required." });
    }

    const wFrom = parseFloat(weight_from);
    const wTo = parseFloat(weight_to);

    if (isNaN(wFrom) || isNaN(wTo)) {
      return res.status(400).json({ success: false, message: "Valid numeric weight range (from and to) is required." });
    }

    if (wFrom < 0) {
      return res.status(400).json({ success: false, message: "Weight From cannot be negative." });
    }

    if (wTo <= wFrom) {
      return res.status(400).json({ success: false, message: "Weight To must be greater than Weight From." });
    }

    // 1. Verify Branch exists if provided and not global/ALL
    let branchName = "All / Global";
    if (branchClean && branchClean !== "ALL") {
      const branchCheck = await client.execute({
        sql: `SELECT branchid, branchname, companyid FROM branches WHERE UPPER(TRIM(branchid)) = ? LIMIT 1;`,
        args: [branchClean],
      });
      if (branchCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Branch does not exist." });
      }
      branchName = branchCheck.rows[0].branchname || branchClean;
      if (!companyClean && branchCheck.rows[0].companyid) {
        companyClean = branchCheck.rows[0].companyid.toString().trim().toUpperCase();
      }
    }

    // 2. Verify Product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });
    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }
    const prodName = prodCheck.rows[0].productname;

    // 3. If subproductid provided, verify it belongs to productid
    let subProdId = null;
    let subProdName = "None / General";
    if (subproductid !== undefined && subproductid !== null && subproductid !== "" && Number(subproductid) > 0) {
      subProdId = Number(subproductid);
      const subCheck = await client.execute({
        sql: `SELECT subproductid, subproductname FROM subproducts WHERE subproductid = ? AND productid = ? LIMIT 1;`,
        args: [subProdId, Number(productid)],
      });
      if (subCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Sub-Product does not belong to this Product." });
      }
      subProdName = subCheck.rows[0].subproductname;
    }

    // 4. Verify Dealer exists with accounttype in ('SMITH', 'DEALER')
    const dealerCheck = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE accode = ? AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [accode.trim()],
    });
    if (dealerCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Dealer is not a valid Smith or Dealer account." });
    }
    const dealerName = dealerCheck.rows[0].accountname;

    // 5. Overlap & Duplicate check scoped for the same (companyid, branchid, productid, subproductid, accode)
    let overlapQuery;
    let overlapArgs;
    if (subProdId !== null) {
      overlapQuery = `
        SELECT id, weight_from, weight_to 
        FROM pricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND subproductid = ? 
          AND accode = ? 
          AND weight_from < ? 
          AND weight_to > ? 
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), subProdId, accode.trim(), wTo, wFrom];
    } else {
      overlapQuery = `
        SELECT id, weight_from, weight_to 
        FROM pricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND (subproductid IS NULL OR subproductid = 0) 
          AND accode = ? 
          AND weight_from < ? 
          AND weight_to > ? 
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), accode.trim(), wTo, wFrom];
    }

    const overlapResult = await client.execute({
      sql: overlapQuery,
      args: overlapArgs,
    });

    if (overlapResult.rows.length > 0) {
      const existing = overlapResult.rows[0];
      const branchDisplay = branchClean ? `Branch '${branchName}'` : "Global / All Branches";
      return res.status(400).json({
        success: false,
        message: `Weight range ${wFrom}g - ${wTo}g overlaps with existing range (${existing.weight_from}g - ${existing.weight_to}g) for ${branchDisplay}, Product '${prodName}', Sub-Product '${subProdName}', and Dealer '${dealerName}'.`,
      });
    }

    const vaPer = parseFloat(va_percent) || 0.0;
    const wst = parseFloat(wastage) || 0.0;
    const mcPg = parseFloat(mc_per_gram) || 0.0;
    const mChg = parseFloat(m_charge) || 0.0;

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO pricesetting (
          companyid,
          branchid,
          productid,
          subproductid,
          accode,
          weight_from,
          weight_to,
          va_percent,
          wastage,
          mc_per_gram,
          m_charge,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        companyClean,
        branchClean,
        Number(productid),
        subProdId,
        accode.trim(),
        wFrom,
        wTo,
        vaPer,
        wst,
        mcPg,
        mChg,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Price Setting created successfully!",
      id: newId,
    });
  } catch (error) {
    console.error("createPriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updatePriceSettingController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      companyid = "",
      branchid = "",
      productid,
      subproductid,
      accode,
      weight_from,
      weight_to,
      va_percent,
      wastage,
      mc_per_gram,
      m_charge,
    } = req.body;

    const branchClean = (branchid || "").toString().trim().toUpperCase();
    let companyClean = (companyid || req.query.companyid || "").toString().trim().toUpperCase();

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Dealer selection is required." });
    }

    const wFrom = parseFloat(weight_from);
    const wTo = parseFloat(weight_to);

    if (isNaN(wFrom) || isNaN(wTo)) {
      return res.status(400).json({ success: false, message: "Valid numeric weight range (from and to) is required." });
    }

    if (wFrom < 0) {
      return res.status(400).json({ success: false, message: "Weight From cannot be negative." });
    }

    if (wTo <= wFrom) {
      return res.status(400).json({ success: false, message: "Weight To must be greater than Weight From." });
    }

    // 1. Verify Branch exists if provided and not global/ALL
    let branchName = "All / Global";
    if (branchClean && branchClean !== "ALL") {
      const branchCheck = await client.execute({
        sql: `SELECT branchid, branchname, companyid FROM branches WHERE UPPER(TRIM(branchid)) = ? LIMIT 1;`,
        args: [branchClean],
      });
      if (branchCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Branch does not exist." });
      }
      branchName = branchCheck.rows[0].branchname || branchClean;
      if (!companyClean && branchCheck.rows[0].companyid) {
        companyClean = branchCheck.rows[0].companyid.toString().trim().toUpperCase();
      }
    }

    // 2. Verify Product exists
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });
    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }
    const prodName = prodCheck.rows[0].productname;

    // 3. If subproductid provided, verify it belongs to productid
    let subProdId = null;
    let subProdName = "None / General";
    if (subproductid !== undefined && subproductid !== null && subproductid !== "" && Number(subproductid) > 0) {
      subProdId = Number(subproductid);
      const subCheck = await client.execute({
        sql: `SELECT subproductid, subproductname FROM subproducts WHERE subproductid = ? AND productid = ? LIMIT 1;`,
        args: [subProdId, Number(productid)],
      });
      if (subCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Sub-Product does not belong to this Product." });
      }
      subProdName = subCheck.rows[0].subproductname;
    }

    // 4. Verify Dealer exists
    const dealerCheck = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE accode = ? AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [accode.trim()],
    });
    if (dealerCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Dealer is not a valid Smith or Dealer account." });
    }
    const dealerName = dealerCheck.rows[0].accountname;

    // 5. Overlap check excluding current ID
    let overlapQuery;
    let overlapArgs;
    if (subProdId !== null) {
      overlapQuery = `
        SELECT id, weight_from, weight_to 
        FROM pricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND subproductid = ? 
          AND accode = ? 
          AND weight_from < ? 
          AND weight_to > ? 
          AND id != ?
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), subProdId, accode.trim(), wTo, wFrom, Number(id)];
    } else {
      overlapQuery = `
        SELECT id, weight_from, weight_to 
        FROM pricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND (subproductid IS NULL OR subproductid = 0) 
          AND accode = ? 
          AND weight_from < ? 
          AND weight_to > ? 
          AND id != ?
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), accode.trim(), wTo, wFrom, Number(id)];
    }

    const overlapResult = await client.execute({
      sql: overlapQuery,
      args: overlapArgs,
    });

    if (overlapResult.rows.length > 0) {
      const existing = overlapResult.rows[0];
      const branchDisplay = branchClean ? `Branch '${branchName}'` : "Global / All Branches";
      return res.status(400).json({
        success: false,
        message: `Weight range ${wFrom}g - ${wTo}g overlaps with existing range (${existing.weight_from}g - ${existing.weight_to}g) for ${branchDisplay}, Product '${prodName}', Sub-Product '${subProdName}', and Dealer '${dealerName}'.`,
      });
    }

    const vaPer = parseFloat(va_percent) || 0.0;
    const wst = parseFloat(wastage) || 0.0;
    const mcPg = parseFloat(mc_per_gram) || 0.0;
    const mChg = parseFloat(m_charge) || 0.0;

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE pricesetting
        SET companyid = ?,
            branchid = ?,
            productid = ?,
            subproductid = ?,
            accode = ?,
            weight_from = ?,
            weight_to = ?,
            va_percent = ?,
            wastage = ?,
            mc_per_gram = ?,
            m_charge = ?,
            updated_at = ?
        WHERE id = ?;
      `,
      args: [
        companyClean,
        branchClean,
        Number(productid),
        subProdId,
        accode.trim(),
        wFrom,
        wTo,
        vaPer,
        wst,
        mcPg,
        mChg,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Price Setting updated successfully!" });
  } catch (error) {
    console.error("updatePriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deletePriceSettingController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM pricesetting WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Price Setting deleted successfully!" });
  } catch (error) {
    console.error("deletePriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 9. DIAMOND PRICE SETTING CRUD CONTROLLERS
// ==========================================

export async function getDiamondPriceSettingsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const companyClean = (req.query.companyid || "").toString().trim().toUpperCase();

    let sql = `
      SELECT 
        dps.id,
        COALESCE(dps.companyid, '') AS companyid,
        dps.branchid,
        COALESCE(b.branchname, '') AS branchname,
        COALESCE(b.companyid, '') AS branch_companyid,
        dps.productid,
        COALESCE(p.productname, '') AS productname,
        dps.subproductid,
        COALESCE(sp.subproductname, '') AS subproductname,
        dps.accode,
        COALESCE(ah.accountname, '') AS dealername,
        COALESCE(ah.accounttype, '') AS accounttype,
        dps.from_cent,
        dps.to_cent,
        dps.cent_rate,
        dps.created_at,
        dps.updated_at
      FROM diamondpricesetting dps
      LEFT JOIN branches b ON UPPER(TRIM(dps.branchid)) = UPPER(TRIM(b.branchid))
      LEFT JOIN products p ON dps.productid = p.productid
      LEFT JOIN subproducts sp ON dps.subproductid = sp.subproductid
      LEFT JOIN account_heads ah ON dps.accode = ah.accode
    `;
    const args = [];
    if (companyClean) {
      sql += ` WHERE (UPPER(TRIM(COALESCE(dps.companyid, ''))) = ? OR UPPER(TRIM(COALESCE(b.companyid, ''))) = ?)`;
      args.push(companyClean, companyClean);
    }
    sql += ` ORDER BY dps.branchid ASC, p.productname ASC, sp.subproductname ASC, ah.accountname ASC, dps.from_cent ASC;`;

    const result = await client.execute({ sql, args });

    return res.json({
      success: true,
      diamond_price_settings: result.rows || [],
      total_count: (result.rows || []).length,
    });
  } catch (error) {
    console.error("getDiamondPriceSettings error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getDiamondProductsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT 
        p.productid,
        p.categoryid,
        p.productname,
        p.calctype,
        p.stocktype,
        p.havestone_diamond,
        p.havesubproduct,
        p.studded,
        p.diastone,
        p.hsncode,
        p.stoneunit,
        c.catname,
        c.catcode,
        c.categorytype,
        m.metalid,
        m.metalname,
        p.created_at,
        p.updated_at
      FROM products p
      JOIN categories c ON p.categoryid = c.id
      JOIN metals m ON c.metalid = m.metalid
      WHERE UPPER(TRIM(p.diastone)) IN ('D', 'S')
      ORDER BY p.productname ASC;
    `);

    return res.json({
      success: true,
      products: result.rows || [],
      total_count: (result.rows || []).length,
    });
  } catch (error) {
    console.error("getDiamondProducts error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createDiamondPriceSettingController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      companyid = "",
      branchid = "",
      productid,
      subproductid,
      accode,
      from_cent,
      to_cent,
      cent_rate,
    } = req.body;

    const branchClean = (branchid || "").toString().trim().toUpperCase();
    let companyClean = (companyid || req.query.companyid || "").toString().trim().toUpperCase();

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Dealer selection is required." });
    }

    const fCent = parseFloat(from_cent);
    const tCent = parseFloat(to_cent);
    const cRate = parseFloat(cent_rate);

    if (isNaN(fCent) || isNaN(tCent)) {
      return res.status(400).json({ success: false, message: "Valid numeric cent weight range (from and to) is required." });
    }

    if (fCent < 0) {
      return res.status(400).json({ success: false, message: "From Cent weight cannot be negative." });
    }

    if (tCent <= fCent) {
      return res.status(400).json({ success: false, message: "To Cent weight must be greater than From Cent weight." });
    }

    if (isNaN(cRate) || cRate < 0) {
      return res.status(400).json({ success: false, message: "Cent Rate must be a valid non-negative number." });
    }

    // 1. Verify Branch exists if provided and not global/ALL
    let branchName = "All / Global";
    if (branchClean && branchClean !== "ALL") {
      const branchCheck = await client.execute({
        sql: `SELECT branchid, branchname, companyid FROM branches WHERE UPPER(TRIM(branchid)) = ? LIMIT 1;`,
        args: [branchClean],
      });
      if (branchCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Branch does not exist." });
      }
      branchName = branchCheck.rows[0].branchname || branchClean;
      if (!companyClean && branchCheck.rows[0].companyid) {
        companyClean = branchCheck.rows[0].companyid.toString().trim().toUpperCase();
      }
    }

    // 2. Verify Product exists and has diastone IN ('D', 'S')
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname, diastone FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });
    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }
    const prodName = prodCheck.rows[0].productname;
    const diaStoneVal = (prodCheck.rows[0].diastone || "").toString().trim().toUpperCase();
    if (diaStoneVal !== "D" && diaStoneVal !== "S") {
      return res.status(400).json({
        success: false,
        message: `Product '${prodName}' does not have Diamond/Stone type (diastone='D' or 'S').`,
      });
    }

    // 3. If subproductid provided, verify it belongs to productid
    let subProdId = null;
    let subProdName = "None / General";
    if (subproductid !== undefined && subproductid !== null && subproductid !== "" && Number(subproductid) > 0) {
      subProdId = Number(subproductid);
      const subCheck = await client.execute({
        sql: `SELECT subproductid, subproductname FROM subproducts WHERE subproductid = ? AND productid = ? LIMIT 1;`,
        args: [subProdId, Number(productid)],
      });
      if (subCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Sub-Product does not belong to this Product." });
      }
      subProdName = subCheck.rows[0].subproductname;
    }

    // 4. Verify Dealer exists
    const dealerCheck = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE accode = ? AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [accode.trim()],
    });
    if (dealerCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Dealer is not a valid Smith or Dealer account." });
    }
    const dealerName = dealerCheck.rows[0].accountname;

    // 5. Overlap & Duplicate check scoped for (companyid, branchid, productid, subproductid, accode)
    let overlapQuery;
    let overlapArgs;
    if (subProdId !== null) {
      overlapQuery = `
        SELECT id, from_cent, to_cent 
        FROM diamondpricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND subproductid = ? 
          AND accode = ? 
          AND from_cent < ? 
          AND to_cent > ? 
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), subProdId, accode.trim(), tCent, fCent];
    } else {
      overlapQuery = `
        SELECT id, from_cent, to_cent 
        FROM diamondpricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND (subproductid IS NULL OR subproductid = 0) 
          AND accode = ? 
          AND from_cent < ? 
          AND to_cent > ? 
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), accode.trim(), tCent, fCent];
    }

    const overlapResult = await client.execute({
      sql: overlapQuery,
      args: overlapArgs,
    });

    if (overlapResult.rows.length > 0) {
      const existing = overlapResult.rows[0];
      const branchDisplay = branchClean ? `Branch '${branchName}'` : "Global / All Branches";
      return res.status(400).json({
        success: false,
        message: `Cent weight range ${fCent} - ${tCent} overlaps with existing range (${existing.from_cent} - ${existing.to_cent}) for ${branchDisplay}, Product '${prodName}', Sub-Product '${subProdName}', and Dealer '${dealerName}'.`,
      });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO diamondpricesetting (
          companyid,
          branchid,
          productid,
          subproductid,
          accode,
          from_cent,
          to_cent,
          cent_rate,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        companyClean,
        branchClean,
        Number(productid),
        subProdId,
        accode.trim(),
        fCent,
        tCent,
        cRate,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Diamond Price Setting created successfully!",
      id: newId,
    });
  } catch (error) {
    console.error("createDiamondPriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateDiamondPriceSettingController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      companyid = "",
      branchid = "",
      productid,
      subproductid,
      accode,
      from_cent,
      to_cent,
      cent_rate,
    } = req.body;

    const branchClean = (branchid || "").toString().trim().toUpperCase();
    let companyClean = (companyid || req.query.companyid || "").toString().trim().toUpperCase();

    if (!productid) {
      return res.status(400).json({ success: false, message: "Product selection is required." });
    }

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Dealer selection is required." });
    }

    const fCent = parseFloat(from_cent);
    const tCent = parseFloat(to_cent);
    const cRate = parseFloat(cent_rate);

    if (isNaN(fCent) || isNaN(tCent)) {
      return res.status(400).json({ success: false, message: "Valid numeric cent weight range (from and to) is required." });
    }

    if (fCent < 0) {
      return res.status(400).json({ success: false, message: "From Cent weight cannot be negative." });
    }

    if (tCent <= fCent) {
      return res.status(400).json({ success: false, message: "To Cent weight must be greater than From Cent weight." });
    }

    if (isNaN(cRate) || cRate < 0) {
      return res.status(400).json({ success: false, message: "Cent Rate must be a valid non-negative number." });
    }

    // 1. Verify Branch exists if provided
    let branchName = "All / Global";
    if (branchClean && branchClean !== "ALL") {
      const branchCheck = await client.execute({
        sql: `SELECT branchid, branchname, companyid FROM branches WHERE UPPER(TRIM(branchid)) = ? LIMIT 1;`,
        args: [branchClean],
      });
      if (branchCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Branch does not exist." });
      }
      branchName = branchCheck.rows[0].branchname || branchClean;
      if (!companyClean && branchCheck.rows[0].companyid) {
        companyClean = branchCheck.rows[0].companyid.toString().trim().toUpperCase();
      }
    }

    // 2. Verify Product exists and has diastone IN ('D', 'S')
    const prodCheck = await client.execute({
      sql: `SELECT productid, productname, diastone FROM products WHERE productid = ? LIMIT 1;`,
      args: [Number(productid)],
    });
    if (prodCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Selected Product does not exist." });
    }
    const prodName = prodCheck.rows[0].productname;
    const diaStoneVal = (prodCheck.rows[0].diastone || "").toString().trim().toUpperCase();
    if (diaStoneVal !== "D" && diaStoneVal !== "S") {
      return res.status(400).json({
        success: false,
        message: `Product '${prodName}' does not have Diamond/Stone type (diastone='D' or 'S').`,
      });
    }

    // 3. If subproductid provided, verify it belongs to productid
    let subProdId = null;
    let subProdName = "None / General";
    if (subproductid !== undefined && subproductid !== null && subproductid !== "" && Number(subproductid) > 0) {
      subProdId = Number(subproductid);
      const subCheck = await client.execute({
        sql: `SELECT subproductid, subproductname FROM subproducts WHERE subproductid = ? AND productid = ? LIMIT 1;`,
        args: [subProdId, Number(productid)],
      });
      if (subCheck.rows.length === 0) {
        return res.status(400).json({ success: false, message: "Selected Sub-Product does not belong to this Product." });
      }
      subProdName = subCheck.rows[0].subproductname;
    }

    // 4. Verify Dealer exists
    const dealerCheck = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE accode = ? AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [accode.trim()],
    });
    if (dealerCheck.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Dealer is not a valid Smith or Dealer account." });
    }
    const dealerName = dealerCheck.rows[0].accountname;

    // 5. Overlap check excluding current ID
    let overlapQuery;
    let overlapArgs;
    if (subProdId !== null) {
      overlapQuery = `
        SELECT id, from_cent, to_cent 
        FROM diamondpricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND subproductid = ? 
          AND accode = ? 
          AND from_cent < ? 
          AND to_cent > ? 
          AND id != ?
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), subProdId, accode.trim(), tCent, fCent, Number(id)];
    } else {
      overlapQuery = `
        SELECT id, from_cent, to_cent 
        FROM diamondpricesetting 
        WHERE (UPPER(TRIM(COALESCE(companyid, ''))) = ? OR ? = '')
          AND UPPER(TRIM(COALESCE(branchid, ''))) = ?
          AND productid = ? 
          AND (subproductid IS NULL OR subproductid = 0) 
          AND accode = ? 
          AND from_cent < ? 
          AND to_cent > ? 
          AND id != ?
        LIMIT 1;
      `;
      overlapArgs = [companyClean, companyClean, branchClean, Number(productid), accode.trim(), tCent, fCent, Number(id)];
    }

    const overlapResult = await client.execute({
      sql: overlapQuery,
      args: overlapArgs,
    });

    if (overlapResult.rows.length > 0) {
      const existing = overlapResult.rows[0];
      const branchDisplay = branchClean ? `Branch '${branchName}'` : "Global / All Branches";
      return res.status(400).json({
        success: false,
        message: `Cent weight range ${fCent} - ${tCent} overlaps with existing range (${existing.from_cent} - ${existing.to_cent}) for ${branchDisplay}, Product '${prodName}', Sub-Product '${subProdName}', and Dealer '${dealerName}'.`,
      });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE diamondpricesetting
        SET companyid = ?,
            branchid = ?,
            productid = ?,
            subproductid = ?,
            accode = ?,
            from_cent = ?,
            to_cent = ?,
            cent_rate = ?,
            updated_at = ?
        WHERE id = ?;
      `,
      args: [
        companyClean,
        branchClean,
        Number(productid),
        subProdId,
        accode.trim(),
        fCent,
        tCent,
        cRate,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Diamond Price Setting updated successfully!" });
  } catch (error) {
    console.error("updateDiamondPriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteDiamondPriceSettingController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM diamondpricesetting WHERE id = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Diamond Price Setting deleted successfully!" });
  } catch (error) {
    console.error("deleteDiamondPriceSetting error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

// ==========================================
// 10. DESIGNER MASTER CRUD CONTROLLERS
// ==========================================

export async function getDesignersController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const result = await client.execute(`
      SELECT 
        d.designerid,
        d.accode,
        COALESCE(ah.accountname, '') AS accountname,
        COALESCE(ah.accounttype, '') AS accounttype,
        d.designername,
        d.designershortname,
        d.created_at,
        d.updated_at
      FROM designers d
      LEFT JOIN account_heads ah ON UPPER(TRIM(d.accode)) = UPPER(TRIM(ah.accode))
      ORDER BY d.designername ASC;
    `);

    const meta = await client.execute(`
      SELECT MAX(designerid) AS max_id, COUNT(*) AS total_count FROM designers;
    `);
    const maxId = Number(meta.rows[0]?.max_id || 0);

    return res.json({
      success: true,
      designers: result.rows || [],
      last_designerid: maxId,
      next_designerid: maxId + 1,
      total_count: Number(meta.rows[0]?.total_count || 0),
    });
  } catch (error) {
    console.error("getDesigners error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function createDesignerController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      accode,
      designername,
      designershortname = "",
    } = req.body;

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Account Head (Smith/Dealer) selection is required." });
    }

    if (!designername || !designername.trim()) {
      return res.status(400).json({ success: false, message: "Designer Name is required." });
    }

    const cleanAccode = accode.trim();
    const cleanName = designername.trim().substring(0, 50);
    const cleanShortName = (designershortname || "").trim().substring(0, 10).toUpperCase();

    // 1. Verify Dealer/Smith exists in account_heads
    const checkAccount = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE UPPER(TRIM(accode)) = UPPER(?) AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [cleanAccode],
    });

    if (checkAccount.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Account is not a valid Smith or Dealer." });
    }

    // 2. Check unique designer name
    const checkDuplicate = await client.execute({
      sql: `SELECT designerid FROM designers WHERE UPPER(TRIM(designername)) = UPPER(?) LIMIT 1;`,
      args: [cleanName],
    });

    if (checkDuplicate.rows.length > 0) {
      return res.status(400).json({ success: false, message: `Designer Name '${cleanName}' already exists.` });
    }

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO designers (
          accode,
          designername,
          designershortname,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?);
      `,
      args: [
        cleanAccode,
        cleanName,
        cleanShortName,
        now,
        now,
      ],
    });

    const newId = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "Designer created successfully!",
      designerid: newId,
    });
  } catch (error) {
    console.error("createDesigner error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function updateDesignerController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    const {
      accode,
      designername,
      designershortname = "",
    } = req.body;

    if (!accode || !accode.trim()) {
      return res.status(400).json({ success: false, message: "Account Head (Smith/Dealer) selection is required." });
    }

    if (!designername || !designername.trim()) {
      return res.status(400).json({ success: false, message: "Designer Name is required." });
    }

    const cleanAccode = accode.trim();
    const cleanName = designername.trim().substring(0, 50);
    const cleanShortName = (designershortname || "").trim().substring(0, 10).toUpperCase();

    // 1. Verify Dealer/Smith exists
    const checkAccount = await client.execute({
      sql: `SELECT accode, accountname, accounttype FROM account_heads WHERE UPPER(TRIM(accode)) = UPPER(?) AND UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') LIMIT 1;`,
      args: [cleanAccode],
    });

    if (checkAccount.rows.length === 0) {
      return res.status(400).json({ success: false, message: "Selected Account is not a valid Smith or Dealer." });
    }

    // 2. Check unique designer name excluding current ID
    const checkDuplicate = await client.execute({
      sql: `SELECT designerid FROM designers WHERE UPPER(TRIM(designername)) = UPPER(?) AND designerid != ? LIMIT 1;`,
      args: [cleanName, Number(id)],
    });

    if (checkDuplicate.rows.length > 0) {
      return res.status(400).json({ success: false, message: `Designer Name '${cleanName}' already exists.` });
    }

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE designers
        SET accode = ?,
            designername = ?,
            designershortname = ?,
            updated_at = ?
        WHERE designerid = ?;
      `,
      args: [
        cleanAccode,
        cleanName,
        cleanShortName,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "Designer updated successfully!" });
  } catch (error) {
    console.error("updateDesigner error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteDesignerController(req, res) {
  try {
    const { id } = req.params;
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureInventoryTables(client);

    await client.execute({
      sql: `DELETE FROM designers WHERE designerid = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "Designer deleted successfully!" });
  } catch (error) {
    console.error("deleteDesigner error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}
