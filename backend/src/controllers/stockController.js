import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure prepare_sku_lots table and sub-tables exist in the tenant's PostgreSQL schema.
 */
export async function ensureStockTables(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`stock:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS prepare_sku_lots (
        lot_id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_number TEXT UNIQUE NOT NULL,
        companyid TEXT NOT NULL,
        branchid TEXT NOT NULL,
        designerid INTEGER NOT NULL,
        productid INTEGER NOT NULL,
        subproductid INTEGER,
        purityid INTEGER NOT NULL,
        rate REAL DEFAULT 0.0,
        is_assorted TEXT NOT NULL DEFAULT 'NO',
        total_pcs INTEGER NOT NULL DEFAULT 1,
        total_gross_weight REAL NOT NULL DEFAULT 0.0,
        total_net_weight REAL NOT NULL DEFAULT 0.0,
        
        -- Stone Details (Optional / multi-items)
        stone_productid INTEGER,
        stone_subproductid INTEGER,
        stone_unit TEXT DEFAULT 'G',
        total_stone_pcs INTEGER DEFAULT 0,
        total_stone_weight REAL DEFAULT 0.0,
        total_stone_amount REAL DEFAULT 0.0,
        stone_items_json TEXT DEFAULT '[]',
        
        -- Diamond Details (Optional / multi-items)
        diamond_productid INTEGER,
        diamond_subproductid INTEGER,
        diamond_unit TEXT DEFAULT 'C',
        total_diamond_pcs INTEGER DEFAULT 0,
        total_diamond_weight REAL DEFAULT 0.0,
        total_diamond_amount REAL DEFAULT 0.0,
        diamond_items_json TEXT DEFAULT '[]',
        
        is_active INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'PENDING_SKU',
        remarks TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Ensure columns exist on legacy tables
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN stone_unit TEXT DEFAULT 'G';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN diamond_unit TEXT DEFAULT 'C';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN stone_items_json TEXT DEFAULT '[]';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN diamond_items_json TEXT DEFAULT '[]';`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN total_stone_amount REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN total_diamond_amount REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lots ADD COLUMN is_active INTEGER DEFAULT 1;`); } catch (_) {}

    await client.execute(`
      CREATE TABLE IF NOT EXISTS prepare_sku_lot_stones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_id INTEGER NOT NULL,
        stone_productid INTEGER NOT NULL,
        stone_subproductid INTEGER,
        stone_unit TEXT DEFAULT 'G',
        pcs INTEGER DEFAULT 0,
        weight REAL DEFAULT 0.0,
        rate REAL DEFAULT 0.0,
        amount REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (lot_id) REFERENCES prepare_sku_lots(lot_id) ON DELETE CASCADE
      );
    `);
    try { await client.execute(`ALTER TABLE prepare_sku_lot_stones ADD COLUMN rate REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lot_stones ADD COLUMN amount REAL DEFAULT 0.0;`); } catch (_) {}

    await client.execute(`
      CREATE TABLE IF NOT EXISTS prepare_sku_lot_diamonds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lot_id INTEGER NOT NULL,
        diamond_productid INTEGER NOT NULL,
        diamond_subproductid INTEGER,
        diamond_unit TEXT DEFAULT 'C',
        pcs INTEGER DEFAULT 0,
        weight REAL DEFAULT 0.0,
        rate REAL DEFAULT 0.0,
        amount REAL DEFAULT 0.0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (lot_id) REFERENCES prepare_sku_lots(lot_id) ON DELETE CASCADE
      );
    `);
    try { await client.execute(`ALTER TABLE prepare_sku_lot_diamonds ADD COLUMN rate REAL DEFAULT 0.0;`); } catch (_) {}
    try { await client.execute(`ALTER TABLE prepare_sku_lot_diamonds ADD COLUMN amount REAL DEFAULT 0.0;`); } catch (_) {}

    await client.execute(`
      CREATE INDEX IF NOT EXISTS idx_prepare_sku_company ON prepare_sku_lots (companyid);
    `);
    await client.execute(`
      CREATE INDEX IF NOT EXISTS idx_prepare_sku_branch ON prepare_sku_lots (branchid);
    `);
    await client.execute(`
      CREATE INDEX IF NOT EXISTS idx_prepare_sku_lot_no ON prepare_sku_lots (lot_number);
    `);
    await client.execute(`
      CREATE INDEX IF NOT EXISTS idx_prepare_sku_created ON prepare_sku_lots (created_at);
    `);
  });
}

/**
 * Returns current financial year code e.g. '2627' for FY 2026-2027 (April-March).
 */
function getFinancialYearPrefix(now = new Date()) {
  const month = now.getMonth() + 1;
  const fullYear = now.getFullYear();
  let startYear = fullYear;
  if (month < 4) {
    startYear = fullYear - 1;
  }
  const endYear = startYear + 1;
  const startYY = String(startYear).slice(-2);
  const endYY = String(endYear).slice(-2);
  return `${startYY}${endYY}`;
}

/**
 * Generates a concise unique sequential Lot Number e.g. '2627-1', '2627-2', '2627-3'
 */
async function generateNextLotNumber(client) {
  const fyPrefix = getFinancialYearPrefix();

  const res = await client.execute({
    sql: `SELECT lot_number FROM prepare_sku_lots WHERE lot_number LIKE ? OR lot_number LIKE ? ORDER BY lot_id DESC;`,
    args: [`${fyPrefix}-%`, `${fyPrefix}%`],
  });

  let maxSeq = 0;
  if (res.rows && res.rows.length > 0) {
    for (const row of res.rows) {
      const lotStr = String(row.lot_number || '').trim();
      const match = lotStr.match(new RegExp(`^${fyPrefix}-?(\\d+)$`));
      if (match && match[1]) {
        const n = parseInt(match[1], 10);
        if (!isNaN(n) && n > maxSeq) {
          maxSeq = n;
        }
      }
    }
  }

  const nextSeq = maxSeq + 1;
  return `${fyPrefix}-${nextSeq}`;
}

/**
 * GET /api/tenant/stock/prepare-sku
 * Retrieves prepare_sku_lots with joined names, filtered by companyid, date range, branch, active status.
 */
export async function getPrepareSkuLotsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureStockTables(client);

    const { companyid, branchid, designerid, productid, purityid, from_date, fromDate, to_date, toDate, is_active, status } = req.query;

    let query = `
      SELECT 
        l.*,
        d.designername,
        d.designershortname,
        d.accode AS designer_accode,
        p.productname,
        p.calctype,
        p.stocktype,
        p.diastone,
        sp.subproductname,
        pu.purityname,
        pu.purityshortname,
        pu.purity,
        pu.type AS purity_type,
        b.branchname,
        c.companyname,
        stone_p.productname AS stone_productname,
        stone_sp.subproductname AS stone_subproductname,
        diamond_p.productname AS diamond_productname,
        diamond_sp.subproductname AS diamond_subproductname
      FROM prepare_sku_lots l
      LEFT JOIN designers d ON l.designerid = d.designerid
      LEFT JOIN products p ON l.productid = p.productid
      LEFT JOIN subproducts sp ON l.subproductid = sp.subproductid
      LEFT JOIN purities pu ON l.purityid = pu.purityid
      LEFT JOIN branches b ON l.branchid = b.branchid
      LEFT JOIN company c ON l.companyid = c.companyid
      LEFT JOIN products stone_p ON l.stone_productid = stone_p.productid
      LEFT JOIN subproducts stone_sp ON l.stone_subproductid = stone_sp.subproductid
      LEFT JOIN products diamond_p ON l.diamond_productid = diamond_p.productid
      LEFT JOIN subproducts diamond_sp ON l.diamond_subproductid = diamond_sp.subproductid
    `;

    const whereClauses = [];
    const args = [];

    if (companyid && String(companyid).trim() !== "") {
      whereClauses.push(`l.companyid = ?`);
      args.push(String(companyid).trim());
    }

    if (branchid && String(branchid).trim() !== "" && String(branchid).trim().toUpperCase() !== "ALL") {
      whereClauses.push(`l.branchid = ?`);
      args.push(String(branchid).trim());
    }

    if (designerid && parseInt(designerid, 10) > 0) {
      whereClauses.push(`l.designerid = ?`);
      args.push(parseInt(designerid, 10));
    }

    if (productid && parseInt(productid, 10) > 0) {
      whereClauses.push(`l.productid = ?`);
      args.push(parseInt(productid, 10));
    }

    if (purityid && parseInt(purityid, 10) > 0) {
      whereClauses.push(`l.purityid = ?`);
      args.push(parseInt(purityid, 10));
    }

    // Date range filter
    const startDate = (from_date || fromDate || '').toString().trim();
    const endDate = (to_date || toDate || '').toString().trim();

    if (startDate) {
      whereClauses.push(`l.created_at::timestamptz::date >= ?::date`);
      args.push(startDate.slice(0, 10));
    }

    if (endDate) {
      whereClauses.push(`l.created_at::timestamptz::date <= ?::date`);
      args.push(endDate.slice(0, 10));
    }

    // Active status filter
    const activeParam = (is_active !== undefined ? is_active : status);
    if (activeParam !== undefined && activeParam !== null && String(activeParam).trim() !== "" && String(activeParam).toUpperCase() !== "ALL") {
      const val = String(activeParam).toUpperCase().trim();
      if (val === "1" || val === "TRUE" || val === "ACTIVE") {
        whereClauses.push(`(l.is_active = 1 AND l.status != 'DISABLED')`);
      } else if (val === "0" || val === "FALSE" || val === "DISABLED" || val === "INACTIVE") {
        whereClauses.push(`(l.is_active = 0 OR l.status = 'DISABLED')`);
      }
    }

    if (whereClauses.length > 0) {
      query += ` WHERE ` + whereClauses.join(" AND ");
    }

    query += ` ORDER BY l.lot_id DESC;`;

    const result = await client.execute({ sql: query, args });

    const rows = result.rows.map((row) => {
      let stoneItems = [];
      try {
        if (row.stone_items_json) {
          stoneItems = typeof row.stone_items_json === 'string' ? JSON.parse(row.stone_items_json) : row.stone_items_json;
        }
      } catch (_) {}

      let diamondItems = [];
      try {
        if (row.diamond_items_json) {
          diamondItems = typeof row.diamond_items_json === 'string' ? JSON.parse(row.diamond_items_json) : row.diamond_items_json;
        }
      } catch (_) {}

      const isActiveBool = (row.is_active !== 0 && String(row.status || '').toUpperCase() !== 'DISABLED');

      return {
        lot_id: row.lot_id,
        lot_number: row.lot_number,
        companyid: row.companyid,
        branchid: row.branchid,
        designerid: row.designerid,
        productid: row.productid,
        subproductid: row.subproductid,
        purityid: row.purityid,
        rate: Number(row.rate || 0.0),
        is_assorted: row.is_assorted || 'NO',
        total_pcs: Number(row.total_pcs || 1),
        total_gross_weight: Number(row.total_gross_weight || 0.0),
        total_net_weight: Number(row.total_net_weight || 0.0),
        stone_productid: row.stone_productid,
        stone_subproductid: row.stone_subproductid,
        stone_unit: row.stone_unit || 'G',
        total_stone_pcs: Number(row.total_stone_pcs || 0),
        total_stone_weight: Number(row.total_stone_weight || 0.0),
        total_stone_amount: Number(row.total_stone_amount || 0.0),
        stone_items: stoneItems,
        diamond_productid: row.diamond_productid,
        diamond_subproductid: row.diamond_subproductid,
        diamond_unit: row.diamond_unit || 'C',
        total_diamond_pcs: Number(row.total_diamond_pcs || 0),
        total_diamond_weight: Number(row.total_diamond_weight || 0.0),
        total_diamond_amount: Number(row.total_diamond_amount || 0.0),
        diamond_items: diamondItems,
        is_active: isActiveBool,
        status: row.status || (isActiveBool ? 'PENDING_SKU' : 'DISABLED'),
        remarks: row.remarks || '',
        created_at: row.created_at,
        updated_at: row.updated_at,
        designername: row.designername,
        designershortname: row.designershortname,
        designer_accode: row.designer_accode,
        productname: row.productname,
        calctype: row.calctype,
        stocktype: row.stocktype,
        diastone: row.diastone,
        subproductname: row.subproductname,
        purityname: row.purityname,
        purityshortname: row.purityshortname,
        purity: row.purity,
        purity_type: row.purity_type,
        branchname: row.branchname,
        companyname: row.companyname,
        stone_productname: row.stone_productname,
        stone_subproductname: row.stone_subproductname,
        diamond_productname: row.diamond_productname,
        diamond_subproductname: row.diamond_subproductname,
      };
    });

    return res.json({
      success: true,
      lots: rows,
      total_count: rows.length,
    });
  } catch (error) {
    console.error("Error getPrepareSkuLotsController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to fetch SKU lots." });
  }
}

/**
 * POST /api/tenant/stock/prepare-sku
 * Creates a new prepare_sku_lot and auto-generates a unique lot_number.
 */
export async function createPrepareSkuLotController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureStockTables(client);

    const {
      companyid,
      branchid,
      designerid,
      productid,
      subproductid,
      purityid,
      rate,
      is_assorted,
      total_pcs,
      total_gross_weight,
      total_net_weight,
      stone_productid,
      stone_subproductid,
      stone_unit = 'G',
      total_stone_pcs,
      total_stone_weight,
      stone_items = [],
      diamond_productid,
      diamond_subproductid,
      diamond_unit = 'C',
      total_diamond_pcs,
      total_diamond_weight,
      diamond_items = [],
      remarks,
    } = req.body;

    if (!companyid || String(companyid).trim() === "") {
      return res.status(400).json({ success: false, message: "Company is required." });
    }
    if (!branchid || String(branchid).trim() === "") {
      return res.status(400).json({ success: false, message: "Branch is required." });
    }
    if (!designerid) {
      return res.status(400).json({ success: false, message: "Designer is required." });
    }
    if (!productid) {
      return res.status(400).json({ success: false, message: "Product is required." });
    }
    if (!purityid) {
      return res.status(400).json({ success: false, message: "Ornament Purity is required." });
    }

    const pcs = parseInt(total_pcs, 10);
    if (isNaN(pcs) || pcs <= 0) {
      return res.status(400).json({ success: false, message: "Total Pieces must be at least 1." });
    }

    const grsWt = parseFloat(total_gross_weight);
    if (isNaN(grsWt) || grsWt <= 0) {
      return res.status(400).json({ success: false, message: "Total Gross Weight must be greater than 0." });
    }

    const netWt = parseFloat(total_net_weight);
    if (isNaN(netWt) || netWt < 0) {
      return res.status(400).json({ success: false, message: "Total Net Weight must be non-negative." });
    }

    // Compute aggregated stone/diamond totals from items if provided
    let finalStonePcs = parseInt(total_stone_pcs, 10) || 0;
    let finalStoneWt = parseFloat(total_stone_weight) || 0.0;
    let finalStoneAmount = parseFloat(req.body.total_stone_amount) || 0.0;
    let finalStoneProductId = stone_productid ? parseInt(stone_productid, 10) : null;
    let finalStoneSubProductId = stone_subproductid ? parseInt(stone_subproductid, 10) : null;
    let finalStoneUnit = (String(stone_unit || 'G').toUpperCase() === 'C') ? 'C' : 'G';

    if (Array.isArray(stone_items) && stone_items.length > 0) {
      finalStonePcs = stone_items.reduce((sum, item) => sum + (parseInt(item.pcs, 10) || 0), 0);
      finalStoneWt = stone_items.reduce((sum, item) => sum + (parseFloat(item.weight) || 0.0), 0.0);
      finalStoneAmount = stone_items.reduce((sum, item) => {
        const amt = parseFloat(item.amount);
        if (!isNaN(amt) && amt > 0) return sum + amt;
        const w = parseFloat(item.weight) || 0.0;
        const r = parseFloat(item.rate) || 0.0;
        return sum + (w * r);
      }, 0.0);
      finalStoneProductId = stone_items[0].stone_productid || finalStoneProductId;
      finalStoneSubProductId = stone_items[0].stone_subproductid || finalStoneSubProductId;
      finalStoneUnit = stone_items[0].stone_unit || finalStoneUnit;
    }

    let finalDiamondPcs = parseInt(total_diamond_pcs, 10) || 0;
    let finalDiamondWt = parseFloat(total_diamond_weight) || 0.0;
    let finalDiamondAmount = parseFloat(req.body.total_diamond_amount) || 0.0;
    let finalDiamondProductId = diamond_productid ? parseInt(diamond_productid, 10) : null;
    let finalDiamondSubProductId = diamond_subproductid ? parseInt(diamond_subproductid, 10) : null;
    let finalDiamondUnit = (String(diamond_unit || 'C').toUpperCase() === 'G') ? 'G' : 'C';

    if (Array.isArray(diamond_items) && diamond_items.length > 0) {
      finalDiamondPcs = diamond_items.reduce((sum, item) => sum + (parseInt(item.pcs, 10) || 0), 0);
      finalDiamondWt = diamond_items.reduce((sum, item) => sum + (parseFloat(item.weight) || 0.0), 0.0);
      finalDiamondAmount = diamond_items.reduce((sum, item) => {
        const amt = parseFloat(item.amount);
        if (!isNaN(amt) && amt > 0) return sum + amt;
        const w = parseFloat(item.weight) || 0.0;
        const r = parseFloat(item.rate) || 0.0;
        return sum + (w * r);
      }, 0.0);
      finalDiamondProductId = diamond_items[0].diamond_productid || finalDiamondProductId;
      finalDiamondSubProductId = diamond_items[0].diamond_subproductid || finalDiamondSubProductId;
      finalDiamondUnit = diamond_items[0].diamond_unit || finalDiamondUnit;
    }

    // Generate Unique Lot Number
    const lotNumber = await generateNextLotNumber(client);

    const insertResult = await client.execute({
      sql: `
        INSERT INTO prepare_sku_lots (
          lot_number,
          companyid,
          branchid,
          designerid,
          productid,
          subproductid,
          purityid,
          rate,
          is_assorted,
          total_pcs,
          total_gross_weight,
          total_net_weight,
          stone_productid,
          stone_subproductid,
          stone_unit,
          total_stone_pcs,
          total_stone_weight,
          total_stone_amount,
          stone_items_json,
          diamond_productid,
          diamond_subproductid,
          diamond_unit,
          total_diamond_pcs,
          total_diamond_weight,
          total_diamond_amount,
          diamond_items_json,
          remarks,
          is_active,
          status,
          created_at,
          updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'PENDING_SKU', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
      `,
      args: [
        lotNumber,
        String(companyid).trim(),
        String(branchid).trim(),
        parseInt(designerid, 10),
        parseInt(productid, 10),
        subproductid ? parseInt(subproductid, 10) : null,
        parseInt(purityid, 10),
        parseFloat(rate) || 0.0,
        (String(is_assorted || '').toUpperCase() === 'YES') ? 'YES' : 'NO',
        pcs,
        grsWt,
        netWt,
        finalStoneProductId,
        finalStoneSubProductId,
        finalStoneUnit,
        finalStonePcs,
        finalStoneWt,
        finalStoneAmount,
        JSON.stringify(stone_items || []),
        finalDiamondProductId,
        finalDiamondSubProductId,
        finalDiamondUnit,
        finalDiamondPcs,
        finalDiamondWt,
        finalDiamondAmount,
        JSON.stringify(diamond_items || []),
        remarks ? String(remarks).trim() : '',
      ],
    });

    const newLotId = Number(insertResult.lastInsertRowid);

    // Persist child stone items
    if (Array.isArray(stone_items) && stone_items.length > 0) {
      for (const item of stone_items) {
        if (item.stone_productid) {
          const itemWt = parseFloat(item.weight) || 0.0;
          const itemRate = parseFloat(item.rate) || 0.0;
          const itemAmt = parseFloat(item.amount) || (itemWt * itemRate);
          await client.execute({
            sql: `INSERT INTO prepare_sku_lot_stones (lot_id, stone_productid, stone_subproductid, stone_unit, pcs, weight, rate, amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
            args: [
              newLotId,
              parseInt(item.stone_productid, 10),
              item.stone_subproductid ? parseInt(item.stone_subproductid, 10) : null,
              item.stone_unit || 'G',
              parseInt(item.pcs, 10) || 0,
              itemWt,
              itemRate,
              itemAmt,
            ],
          });
        }
      }
    }

    // Persist child diamond items
    if (Array.isArray(diamond_items) && diamond_items.length > 0) {
      for (const item of diamond_items) {
        if (item.diamond_productid) {
          const itemWt = parseFloat(item.weight) || 0.0;
          const itemRate = parseFloat(item.rate) || 0.0;
          const itemAmt = parseFloat(item.amount) || (itemWt * itemRate);
          await client.execute({
            sql: `INSERT INTO prepare_sku_lot_diamonds (lot_id, diamond_productid, diamond_subproductid, diamond_unit, pcs, weight, rate, amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
            args: [
              newLotId,
              parseInt(item.diamond_productid, 10),
              item.diamond_subproductid ? parseInt(item.diamond_subproductid, 10) : null,
              item.diamond_unit || 'C',
              parseInt(item.pcs, 10) || 0,
              itemWt,
              itemRate,
              itemAmt,
            ],
          });
        }
      }
    }

    return res.status(201).json({
      success: true,
      message: `SKU Lot ${lotNumber} prepared successfully!`,
      lot_id: newLotId,
      lot_number: lotNumber,
    });
  } catch (error) {
    console.error("Error createPrepareSkuLotController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to create SKU lot." });
  }
}

/**
 * PUT /api/tenant/stock/prepare-sku/:id
 * Updates an existing prepare_sku_lot.
 */
export async function updatePrepareSkuLotController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureStockTables(client);

    const { id } = req.params;
    const {
      companyid,
      branchid,
      designerid,
      productid,
      subproductid,
      purityid,
      rate,
      is_assorted,
      total_pcs,
      total_gross_weight,
      total_net_weight,
      stone_productid,
      stone_subproductid,
      stone_unit = 'G',
      total_stone_pcs,
      total_stone_weight,
      total_stone_amount,
      stone_items = [],
      diamond_productid,
      diamond_subproductid,
      diamond_unit = 'C',
      total_diamond_pcs,
      total_diamond_weight,
      total_diamond_amount,
      diamond_items = [],
      remarks,
      is_active,
      status,
    } = req.body;

    const lotId = parseInt(id, 10);
    if (isNaN(lotId)) {
      return res.status(400).json({ success: false, message: "Invalid Lot ID." });
    }

    const pcs = parseInt(total_pcs, 10) || 1;
    const grsWt = parseFloat(total_gross_weight) || 0.0;
    const netWt = parseFloat(total_net_weight) || 0.0;

    let finalStonePcs = parseInt(total_stone_pcs, 10) || 0;
    let finalStoneWt = parseFloat(total_stone_weight) || 0.0;
    let finalStoneAmount = parseFloat(total_stone_amount) || 0.0;
    let finalStoneProductId = stone_productid ? parseInt(stone_productid, 10) : null;
    let finalStoneSubProductId = stone_subproductid ? parseInt(stone_subproductid, 10) : null;
    let finalStoneUnit = (String(stone_unit || 'G').toUpperCase() === 'C') ? 'C' : 'G';

    if (Array.isArray(stone_items) && stone_items.length > 0) {
      finalStonePcs = stone_items.reduce((sum, item) => sum + (parseInt(item.pcs, 10) || 0), 0);
      finalStoneWt = stone_items.reduce((sum, item) => sum + (parseFloat(item.weight) || 0.0), 0.0);
      finalStoneAmount = stone_items.reduce((sum, item) => {
        const amt = parseFloat(item.amount);
        if (!isNaN(amt) && amt > 0) return sum + amt;
        const w = parseFloat(item.weight) || 0.0;
        const r = parseFloat(item.rate) || 0.0;
        return sum + (w * r);
      }, 0.0);
      finalStoneProductId = stone_items[0].stone_productid || finalStoneProductId;
      finalStoneSubProductId = stone_items[0].stone_subproductid || finalStoneSubProductId;
      finalStoneUnit = stone_items[0].stone_unit || finalStoneUnit;
    }

    let finalDiamondPcs = parseInt(total_diamond_pcs, 10) || 0;
    let finalDiamondWt = parseFloat(total_diamond_weight) || 0.0;
    let finalDiamondAmount = parseFloat(total_diamond_amount) || 0.0;
    let finalDiamondProductId = diamond_productid ? parseInt(diamond_productid, 10) : null;
    let finalDiamondSubProductId = diamond_subproductid ? parseInt(diamond_subproductid, 10) : null;
    let finalDiamondUnit = (String(diamond_unit || 'C').toUpperCase() === 'G') ? 'G' : 'C';

    if (Array.isArray(diamond_items) && diamond_items.length > 0) {
      finalDiamondPcs = diamond_items.reduce((sum, item) => sum + (parseInt(item.pcs, 10) || 0), 0);
      finalDiamondWt = diamond_items.reduce((sum, item) => sum + (parseFloat(item.weight) || 0.0), 0.0);
      finalDiamondAmount = diamond_items.reduce((sum, item) => {
        const amt = parseFloat(item.amount);
        if (!isNaN(amt) && amt > 0) return sum + amt;
        const w = parseFloat(item.weight) || 0.0;
        const r = parseFloat(item.rate) || 0.0;
        return sum + (w * r);
      }, 0.0);
      finalDiamondProductId = diamond_items[0].diamond_productid || finalDiamondProductId;
      finalDiamondSubProductId = diamond_items[0].diamond_subproductid || finalDiamondSubProductId;
      finalDiamondUnit = diamond_items[0].diamond_unit || finalDiamondUnit;
    }

    let updatedIsActive = null;
    if (is_active !== undefined && is_active !== null) {
      updatedIsActive = (is_active === true || is_active === 1 || String(is_active).toUpperCase() === 'ACTIVE') ? 1 : 0;
    }

    const result = await client.execute({
      sql: `
        UPDATE prepare_sku_lots SET
          companyid = COALESCE(?, companyid),
          branchid = COALESCE(?, branchid),
          designerid = COALESCE(?, designerid),
          productid = COALESCE(?, productid),
          subproductid = ?,
          purityid = COALESCE(?, purityid),
          rate = COALESCE(?, rate),
          is_assorted = COALESCE(?, is_assorted),
          total_pcs = ?,
          total_gross_weight = ?,
          total_net_weight = ?,
          stone_productid = ?,
          stone_subproductid = ?,
          stone_unit = ?,
          total_stone_pcs = ?,
          total_stone_weight = ?,
          total_stone_amount = ?,
          stone_items_json = ?,
          diamond_productid = ?,
          diamond_subproductid = ?,
          diamond_unit = ?,
          total_diamond_pcs = ?,
          total_diamond_weight = ?,
          total_diamond_amount = ?,
          diamond_items_json = ?,
          remarks = COALESCE(?, remarks),
          is_active = COALESCE(?, is_active),
          status = COALESCE(?, status),
          updated_at = CURRENT_TIMESTAMP
        WHERE lot_id = ?;
      `,
      args: [
        companyid ? String(companyid).trim() : null,
        branchid ? String(branchid).trim() : null,
        designerid ? parseInt(designerid, 10) : null,
        productid ? parseInt(productid, 10) : null,
        subproductid ? parseInt(subproductid, 10) : null,
        purityid ? parseInt(purityid, 10) : null,
        rate !== undefined ? parseFloat(rate) : null,
        is_assorted ? ((String(is_assorted).toUpperCase() === 'YES') ? 'YES' : 'NO') : null,
        pcs,
        grsWt,
        netWt,
        finalStoneProductId,
        finalStoneSubProductId,
        finalStoneUnit,
        finalStonePcs,
        finalStoneWt,
        finalStoneAmount,
        JSON.stringify(stone_items || []),
        finalDiamondProductId,
        finalDiamondSubProductId,
        finalDiamondUnit,
        finalDiamondPcs,
        finalDiamondWt,
        finalDiamondAmount,
        JSON.stringify(diamond_items || []),
        remarks !== undefined ? String(remarks).trim() : null,
        updatedIsActive,
        status ? String(status).trim() : null,
        lotId,
      ],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "SKU Lot not found." });
    }

    // Sync child stone items
    if (Array.isArray(stone_items)) {
      await client.execute({ sql: `DELETE FROM prepare_sku_lot_stones WHERE lot_id = ?;`, args: [lotId] });
      for (const item of stone_items) {
        if (item.stone_productid) {
          const itemWt = parseFloat(item.weight) || 0.0;
          const itemRate = parseFloat(item.rate) || 0.0;
          const itemAmt = parseFloat(item.amount) || (itemWt * itemRate);
          await client.execute({
            sql: `INSERT INTO prepare_sku_lot_stones (lot_id, stone_productid, stone_subproductid, stone_unit, pcs, weight, rate, amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
            args: [
              lotId,
              parseInt(item.stone_productid, 10),
              item.stone_subproductid ? parseInt(item.stone_subproductid, 10) : null,
              item.stone_unit || 'G',
              parseInt(item.pcs, 10) || 0,
              itemWt,
              itemRate,
              itemAmt,
            ],
          });
        }
      }
    }

    // Sync child diamond items
    if (Array.isArray(diamond_items)) {
      await client.execute({ sql: `DELETE FROM prepare_sku_lot_diamonds WHERE lot_id = ?;`, args: [lotId] });
      for (const item of diamond_items) {
        if (item.diamond_productid) {
          const itemWt = parseFloat(item.weight) || 0.0;
          const itemRate = parseFloat(item.rate) || 0.0;
          const itemAmt = parseFloat(item.amount) || (itemWt * itemRate);
          await client.execute({
            sql: `INSERT INTO prepare_sku_lot_diamonds (lot_id, diamond_productid, diamond_subproductid, diamond_unit, pcs, weight, rate, amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?);`,
            args: [
              lotId,
              parseInt(item.diamond_productid, 10),
              item.diamond_subproductid ? parseInt(item.diamond_subproductid, 10) : null,
              item.diamond_unit || 'C',
              parseInt(item.pcs, 10) || 0,
              itemWt,
              itemRate,
              itemAmt,
            ],
          });
        }
      }
    }

    return res.json({ success: true, message: "SKU Lot updated successfully." });
  } catch (error) {
    console.error("Error updatePrepareSkuLotController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to update SKU lot." });
  }
}

/**
 * DELETE /api/tenant/stock/prepare-sku/:id
 * Soft deactivates/disables a prepare_sku_lot (cannot be permanently deleted).
 */
export async function deletePrepareSkuLotController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureStockTables(client);

    const { id } = req.params;
    const lotId = parseInt(id, 10);
    if (isNaN(lotId)) {
      return res.status(400).json({ success: false, message: "Invalid Lot ID." });
    }

    // Soft deactivation: set is_active = 0, status = 'DISABLED'
    const result = await client.execute({
      sql: `UPDATE prepare_sku_lots SET is_active = 0, status = 'DISABLED', updated_at = CURRENT_TIMESTAMP WHERE lot_id = ?;`,
      args: [lotId],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "SKU Lot not found." });
    }

    return res.json({ success: true, message: "SKU Lot deactivated/disabled successfully." });
  } catch (error) {
    console.error("Error deletePrepareSkuLotController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to deactivate SKU lot." });
  }
}
