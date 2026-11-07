import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures daily_rates and supporting tables exist in the tenant's PostgreSQL schema.
 */
export async function ensureDailyRatesTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`daily_rates:${key}`, async () => {
    // Ensure metals and purities exist first
    await client.execute(`
      CREATE TABLE IF NOT EXISTS metals (
        metalid TEXT PRIMARY KEY NOT NULL,
        metalname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

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

    await client.execute(`
      CREATE TABLE IF NOT EXISTS daily_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id INTEGER DEFAULT 1,
        ratedate TEXT NOT NULL,
        purityid INTEGER NOT NULL,
        metalid TEXT NOT NULL,
        purityname TEXT NOT NULL,
        purity REAL NOT NULL,
        rate REAL NOT NULL,
        buy_rate REAL DEFAULT 0.0,
        sell_rate REAL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purityid) REFERENCES purities(purityid)
      );
    `);

    // Safe non-destructive column additions
    try {
      await client.execute(`ALTER TABLE daily_rates ADD COLUMN batch_id INTEGER DEFAULT 1;`);
    } catch (_) {}

    // Safe index creation
    try {
      await client.execute(`
        CREATE INDEX IF NOT EXISTS idx_daily_rates_purity_id 
        ON daily_rates (purityid, id DESC);
      `);
      await client.execute(`
        CREATE INDEX IF NOT EXISTS idx_daily_rates_date_id 
        ON daily_rates (ratedate, id DESC);
      `);
    } catch (_) {}
  });
}

/**
 * GET /api/tenant/rates/latest
 * Fetches latest rate for every purity in Purity Master, along with summary ticker rates.
 */
export async function getLatestRatesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureDailyRatesTable(client);

    // Fetch all purities joined with metals and their latest rate entry (highest id)
    const result = await client.execute(`
      SELECT 
        p.purityid,
        p.metalid,
        COALESCE(m.metalname, p.metalid) AS metalname,
        p.purityname,
        p.purityshortname,
        p.purity,
        p.type,
        r.id AS rate_id,
        r.batch_id,
        r.ratedate,
        COALESCE(r.rate, 0.0) AS rate,
        COALESCE(r.buy_rate, 0.0) AS buy_rate,
        COALESCE(r.sell_rate, COALESCE(r.rate, 0.0)) AS sell_rate,
        r.notes,
        r.created_at AS last_updated_at
      FROM purities p
      LEFT JOIN metals m ON p.metalid = m.metalid
      LEFT JOIN daily_rates r ON r.id = (
        SELECT dr.id 
        FROM daily_rates dr 
        WHERE dr.purityid = p.purityid 
        ORDER BY dr.id DESC 
        LIMIT 1
      )
      ORDER BY p.metalid ASC, p.purity DESC;
    `);

    const purityRates = result.rows || [];

    // Derive ticker headlines (24K, 22K 916, Silver 92.5, etc.)
    let gold24k = 0.0;
    let gold22k = 0.0;
    let silver = 0.0;
    let silverPurity = 0.0;
    let silverIs925 = false;
    let platinum = 0.0;
    let latestTimestamp = '';

    for (const pr of purityRates) {
      const rateVal = Number(pr.rate) || 0.0;
      const metalId = String(pr.metalid || '').toUpperCase();
      const purityVal = Number(pr.purity) || 0.0;
      const name = String(pr.purityname || '').toUpperCase();
      const shortName = String(pr.purityshortname || '').toUpperCase();

      if (pr.last_updated_at && (!latestTimestamp || pr.last_updated_at > latestTimestamp)) {
        latestTimestamp = pr.last_updated_at;
      }

      if (metalId === 'G' || name.includes('GOLD')) {
        if (purityVal >= 99.0 || name.includes('24K') || shortName.includes('24K')) {
          if (gold24k === 0 || purityVal >= 99.0) gold24k = rateVal;
        } else if (purityVal >= 91.0 || name.includes('22K') || shortName.includes('916')) {
          if (gold22k === 0) gold22k = rateVal;
        }
      } else if (metalId === 'S' || name.includes('SILVER')) {
        // Specifically select 92.5% (Sterling Silver) for Silver ticker display
        const is925 = Math.abs(purityVal - 92.5) < 0.6 || name.includes('92.5') || shortName.includes('92.5') || name.includes('925') || shortName.includes('925');
        if (is925) {
          silver = rateVal;
          silverIs925 = true;
        } else if (!silverIs925 && (silver === 0 || Math.abs(purityVal - 92.5) < Math.abs(silverPurity - 92.5))) {
          silver = rateVal;
          silverPurity = purityVal;
        }
      } else if (metalId === 'P' || name.includes('PLATINUM')) {
        if (platinum === 0) platinum = rateVal;
      }
    }

    // Fallbacks if no rate has been saved yet
    if (gold24k === 0.0) gold24k = 7450.0;
    if (gold22k === 0.0) gold22k = 6850.0;
    if (silver === 0.0) silver = 92.50;

    return res.json({
      success: true,
      purity_rates: purityRates,
      ticker: {
        gold_24k: gold24k,
        gold_22k: gold22k,
        silver: silver,
        platinum: platinum,
        last_updated_at: latestTimestamp,
      },
    });
  } catch (error) {
    console.error("getLatestRatesController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch latest rates.",
    });
  }
}

/**
 * GET /api/tenant/rates/by-date?date=YYYY-MM-DD
 * Retrieves rates for a specific target date, populated with latest known rates if none saved for that date.
 */
export async function getRatesByDateController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureDailyRatesTable(client);

    const targetDate = (req.query.date || new Date().toISOString().split("T")[0]).trim();

    // 1. Fetch all purities from Purity Master
    const puritiesRes = await client.execute(`
      SELECT 
        p.purityid,
        p.metalid,
        COALESCE(m.metalname, p.metalid) AS metalname,
        p.purityname,
        p.purityshortname,
        p.purity,
        p.type
      FROM purities p
      LEFT JOIN metals m ON p.metalid = m.metalid
      ORDER BY p.metalid ASC, p.purity DESC;
    `);

    const purities = puritiesRes.rows || [];

    // 2. Fetch the latest rate saved on the exact target date for each purity
    const exactDateRatesRes = await client.execute({
      sql: `
        SELECT dr.* 
        FROM daily_rates dr
        JOIN (
          SELECT purityid, MAX(id) AS max_id 
          FROM daily_rates 
          WHERE ratedate = ? 
          GROUP BY purityid
        ) latest ON dr.id = latest.max_id;
      `,
      args: [targetDate],
    });

    const exactMap = new Map();
    for (const row of exactDateRatesRes.rows || []) {
      exactMap.set(Number(row.purityid), row);
    }

    // 3. For purities without a record on targetDate, fetch their latest historical rate on or before targetDate
    const items = [];
    const isAlreadySavedForDate = exactMap.size > 0;

    for (const p of purities) {
      const pid = Number(p.purityid);
      if (exactMap.has(pid)) {
        const row = exactMap.get(pid);
        items.push({
          purityid: pid,
          metalid: p.metalid,
          metalname: p.metalname,
          purityname: p.purityname,
          purityshortname: p.purityshortname,
          purity: p.purity,
          type: p.type,
          rate_id: row.id,
          batch_id: row.batch_id || 1,
          ratedate: row.ratedate,
          rate: Number(row.rate) || 0.0,
          buy_rate: Number(row.buy_rate) || 0.0,
          sell_rate: Number(row.sell_rate) || 0.0,
          notes: row.notes || "",
          is_saved_for_date: true,
          updated_at: row.created_at || row.updated_at,
        });
      } else {
        // Fetch last known historical rate on or before targetDate
        const lastKnownRes = await client.execute({
          sql: `
            SELECT * FROM daily_rates 
            WHERE purityid = ? AND ratedate <= ?
            ORDER BY id DESC 
            LIMIT 1;
          `,
          args: [pid, targetDate],
        });

        const lastKnown = lastKnownRes.rows?.[0];
        items.push({
          purityid: pid,
          metalid: p.metalid,
          metalname: p.metalname,
          purityname: p.purityname,
          purityshortname: p.purityshortname,
          purity: p.purity,
          type: p.type,
          rate_id: null,
          batch_id: null,
          ratedate: targetDate,
          rate: lastKnown ? Number(lastKnown.rate) || 0.0 : 0.0,
          buy_rate: lastKnown ? Number(lastKnown.buy_rate) || 0.0 : 0.0,
          sell_rate: lastKnown ? Number(lastKnown.sell_rate) || 0.0 : 0.0,
          notes: "",
          is_saved_for_date: false,
          previous_rate_date: lastKnown?.ratedate || "",
          updated_at: lastKnown?.created_at || lastKnown?.updated_at || "",
        });
      }
    }

    return res.json({
      success: true,
      target_date: targetDate,
      is_already_saved_for_date: isAlreadySavedForDate,
      rates: items,
    });
  } catch (error) {
    console.error("getRatesByDateController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch rates for date.",
    });
  }
}

/**
 * POST /api/tenant/rates/bulk-update
 * ALWAYS saves a new historical rate log entry for every update, generating an auto-incrementing integer ID and batch number.
 */
export async function bulkUpdateRatesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureDailyRatesTable(client);

    const { ratedate, rates } = req.body;

    if (!ratedate || !String(ratedate).trim()) {
      return res.status(400).json({
        success: false,
        message: "Rate date (YYYY-MM-DD) is required.",
      });
    }

    if (!Array.isArray(rates) || rates.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No purity rates provided for update.",
      });
    }

    const cleanDate = ratedate.trim();
    const now = new Date().toISOString();

    // Generate unique sequential integer Batch ID for this update session
    const batchRes = await client.execute(`
      SELECT COALESCE(MAX(batch_id), 0) + 1 AS next_batch FROM daily_rates;
    `);
    const nextBatchId = Number(batchRes.rows[0]?.next_batch || 1);

    const insertedIds = [];

    for (const r of rates) {
      const purityId = parseInt(r.purityid, 10);
      const metalId = String(r.metalid || "").trim().toUpperCase();
      const purityName = String(r.purityname || "").trim();
      const purityPercent = parseFloat(r.purity) || 0.0;
      
      // Round paise in rate to whole Rupee
      const rateVal = Math.round(parseFloat(r.rate) || 0.0);
      const buyRateVal = Math.round(parseFloat(r.buy_rate) || 0.0);
      const sellRateVal = Math.round(parseFloat(r.sell_rate) || rateVal);
      const notes = String(r.notes || "").trim();

      if (!purityId) continue;

      // Always INSERT a new historical rate record (preserves full audit log history)
      const insRes = await client.execute({
        sql: `
          INSERT INTO daily_rates (
            batch_id, ratedate, purityid, metalid, purityname, purity,
            rate, buy_rate, sell_rate, notes, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        `,
        args: [
          nextBatchId,
          cleanDate,
          purityId,
          metalId,
          purityName,
          purityPercent,
          rateVal,
          buyRateVal,
          sellRateVal,
          notes,
          now,
          now,
        ],
      });

      if (insRes.lastInsertRowid) {
        insertedIds.push(Number(insRes.lastInsertRowid));
      }
    }

    return res.json({
      success: true,
      message: `Board rates update (Batch #${nextBatchId}) saved successfully for ${cleanDate} (${insertedIds.length} purities logged in history).`,
      batch_id: nextBatchId,
      saved_date: cleanDate,
      total_logged: insertedIds.length,
    });
  } catch (error) {
    console.error("bulkUpdateRatesController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update daily rates.",
    });
  }
}

/**
 * GET /api/tenant/rates/history
 * Returns chronological history of every single rate update ever performed with its unique integer Record ID and Batch ID.
 */
export async function getRateHistoryController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureDailyRatesTable(client);

    const { from_date, to_date, metalid, purityid, limit = 200 } = req.query;

    let sql = `
      SELECT 
        r.id,
        COALESCE(r.batch_id, 1) AS batch_id,
        r.ratedate,
        r.purityid,
        r.metalid,
        COALESCE(m.metalname, r.metalid) AS metalname,
        r.purityname,
        p.purityshortname,
        r.purity,
        r.rate,
        r.buy_rate,
        r.sell_rate,
        r.notes,
        r.created_at,
        r.updated_at
      FROM daily_rates r
      LEFT JOIN metals m ON r.metalid = m.metalid
      LEFT JOIN purities p ON r.purityid = p.purityid
      WHERE 1=1
    `;
    const args = [];

    if (from_date && from_date.trim()) {
      sql += ` AND r.ratedate >= ?`;
      args.push(from_date.trim());
    }

    if (to_date && to_date.trim()) {
      sql += ` AND r.ratedate <= ?`;
      args.push(to_date.trim());
    }

    if (metalid && metalid.trim() && metalid.trim() !== 'ALL') {
      sql += ` AND UPPER(r.metalid) = ?`;
      args.push(metalid.trim().toUpperCase());
    }

    if (purityid && parseInt(purityid, 10)) {
      sql += ` AND r.purityid = ?`;
      args.push(parseInt(purityid, 10));
    }

    sql += ` ORDER BY r.id DESC LIMIT ?;`;
    args.push(parseInt(limit, 10) || 200);

    const result = await client.execute({ sql, args });

    return res.json({
      success: true,
      history: result.rows || [],
      total_records: (result.rows || []).length,
    });
  } catch (error) {
    console.error("getRateHistoryController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch rate history.",
    });
  }
}

/**
 * DELETE /api/tenant/rates/:id
 * Deletes a single rate history entry by integer ID.
 */
export async function deleteRateRecordController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureDailyRatesTable(client);

    const { id } = req.params;
    const rateId = parseInt(id, 10);
    if (isNaN(rateId)) {
      return res.status(400).json({ success: false, message: "Invalid rate entry ID." });
    }

    await client.execute({
      sql: `DELETE FROM daily_rates WHERE id = ?;`,
      args: [rateId],
    });

    return res.json({
      success: true,
      message: `Rate record #${rateId} deleted successfully.`,
    });
  } catch (error) {
    console.error("deleteRateRecordController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete rate entry.",
    });
  }
}
