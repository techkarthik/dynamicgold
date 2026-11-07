import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Helper to ensure system_controls table exists in the tenant's PostgreSQL schema.
 */
async function ensureSystemControlsTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`system_controls:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS system_controls (
        sno INTEGER PRIMARY KEY AUTOINCREMENT,
        ctlid TEXT NOT NULL,
        ctlname TEXT NOT NULL,
        ctlvalue TEXT NOT NULL,
        module TEXT NOT NULL,
        branch_id TEXT NOT NULL DEFAULT 'ALL',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
  });
}

/**
 * GET /api/tenant/system-controls
 * Fetches all system controls joined with branch names (if applicable) and ID metadata.
 */
export async function getSystemControlsController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureSystemControlsTable(client);

    // Query system controls joined with branches if matching
    const result = await client.execute(`
      SELECT sc.*, b.branchname
      FROM system_controls sc
      LEFT JOIN branches b ON sc.branch_id = b.branchid
      ORDER BY sc.sno DESC;
    `);

    // Get max/last sno
    const metaResult = await client.execute(`
      SELECT MAX(sno) AS max_sno, COUNT(*) AS total_count FROM system_controls;
    `);

    const maxSno = Number(metaResult.rows[0]?.max_sno || 0);
    const nextSno = maxSno + 1;
    const totalCount = Number(metaResult.rows[0]?.total_count || 0);

    return res.json({
      success: true,
      controls: result.rows || [],
      last_sno: maxSno,
      next_sno: nextSno,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("getSystemControls error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * POST /api/tenant/system-controls
 * Creates a new system control record.
 */
export async function createSystemControlController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureSystemControlsTable(client);

    const {
      ctlid,
      ctlname,
      ctlvalue,
      module = "GENERAL",
      branch_id = "ALL",
    } = req.body;

    if (!ctlid || !ctlid.trim()) {
      return res.status(400).json({ success: false, message: "Control ID (ctlid) is required." });
    }

    if (!ctlname || !ctlname.trim()) {
      return res.status(400).json({ success: false, message: "Control Name (ctlname) is required." });
    }

    if (ctlvalue === undefined || ctlvalue === null || String(ctlvalue).trim() === "") {
      return res.status(400).json({ success: false, message: "Control Value (ctlvalue) is required." });
    }

    const cleanCtlId = ctlid.trim().toUpperCase().substring(0, 30);
    const cleanCtlName = ctlname.trim().substring(0, 150);
    const cleanCtlValue = String(ctlvalue).trim().substring(0, 500);
    const cleanModule = String(module).trim().toUpperCase();
    const cleanBranch = String(branch_id).trim();

    const now = new Date().toISOString();

    const insertResult = await client.execute({
      sql: `
        INSERT INTO system_controls (
          ctlid, ctlname, ctlvalue, module, branch_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        cleanCtlId,
        cleanCtlName,
        cleanCtlValue,
        cleanModule,
        cleanBranch,
        now,
        now,
      ],
    });

    const newSno = insertResult.lastInsertRowid ? Number(insertResult.lastInsertRowid) : null;

    return res.status(201).json({
      success: true,
      message: "System Control created successfully!",
      sno: newSno,
    });
  } catch (error) {
    console.error("createSystemControl error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * PUT /api/tenant/system-controls/:id
 * Updates an existing system control record by sno.
 */
export async function updateSystemControlController(req, res) {
  try {
    const { id } = req.params; // sno
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureSystemControlsTable(client);

    const {
      ctlid,
      ctlname,
      ctlvalue,
      module = "GENERAL",
      branch_id = "ALL",
    } = req.body;

    if (!ctlid || !ctlid.trim()) {
      return res.status(400).json({ success: false, message: "Control ID (ctlid) is required." });
    }

    if (!ctlname || !ctlname.trim()) {
      return res.status(400).json({ success: false, message: "Control Name (ctlname) is required." });
    }

    if (ctlvalue === undefined || ctlvalue === null || String(ctlvalue).trim() === "") {
      return res.status(400).json({ success: false, message: "Control Value (ctlvalue) is required." });
    }

    const cleanCtlId = ctlid.trim().toUpperCase().substring(0, 30);
    const cleanCtlName = ctlname.trim().substring(0, 150);
    const cleanCtlValue = String(ctlvalue).trim().substring(0, 500);
    const cleanModule = String(module).trim().toUpperCase();
    const cleanBranch = String(branch_id).trim();

    const now = new Date().toISOString();

    await client.execute({
      sql: `
        UPDATE system_controls
        SET ctlid = ?,
            ctlname = ?,
            ctlvalue = ?,
            module = ?,
            branch_id = ?,
            updated_at = ?
        WHERE sno = ?;
      `,
      args: [
        cleanCtlId,
        cleanCtlName,
        cleanCtlValue,
        cleanModule,
        cleanBranch,
        now,
        Number(id),
      ],
    });

    return res.json({ success: true, message: "System Control updated successfully!" });
  } catch (error) {
    console.error("updateSystemControl error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * DELETE /api/tenant/system-controls/:id
 * Deletes a system control record by sno.
 */
export async function deleteSystemControlController(req, res) {
  try {
    const { id } = req.params; // sno
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureSystemControlsTable(client);

    await client.execute({
      sql: `DELETE FROM system_controls WHERE sno = ?;`,
      args: [Number(id)],
    });

    return res.json({ success: true, message: "System Control deleted successfully!" });
  } catch (error) {
    console.error("deleteSystemControl error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
}
