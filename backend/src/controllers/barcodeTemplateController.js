import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Standard default templates seeded automatically for every tenant.
 */
const DEFAULT_TEMPLATES = [
  {
    name: "Jewelry Butterfly Tag (80x13mm, 2-Across)",
    width_mm: 80.0,
    height_mm: 13.0,
    unit: "mm",
    labels_per_row: 2,
    gap_mm: 3.0,
    margin_top_mm: 1.0,
    margin_left_mm: 1.5,
    tag_style: "JEWELRY_BUTTERFLY",
    is_default: 1,
    elements_json: JSON.stringify([
      {
        id: "elem_qr",
        type: "barcode_2d",
        field_key: "sku",
        label_prefix: "",
        format_template: "{sku}",
        x_mm: 1.5,
        y_mm: 1.5,
        width_mm: 10.0,
        height_mm: 10.0,
        font_size: 8,
        font_weight: "normal",
        alignment: "center",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_comp",
        type: "text",
        field_key: "company_name",
        label_prefix: "",
        format_template: "{company_name}",
        x_mm: 12.5,
        y_mm: 1.0,
        width_mm: 25.0,
        height_mm: 3.5,
        font_size: 7,
        font_weight: "bold",
        alignment: "left",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_item",
        type: "text",
        field_key: "product_name",
        label_prefix: "",
        format_template: "{product_name}",
        x_mm: 12.5,
        y_mm: 4.5,
        width_mm: 25.0,
        height_mm: 3.0,
        font_size: 6,
        font_weight: "normal",
        alignment: "left",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_purity",
        type: "text",
        field_key: "purity",
        label_prefix: "",
        format_template: "{purity}",
        x_mm: 12.5,
        y_mm: 7.5,
        width_mm: 25.0,
        height_mm: 3.0,
        font_size: 6,
        font_weight: "bold",
        alignment: "left",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_grs",
        type: "text",
        field_key: "gross_weight",
        label_prefix: "GRS: ",
        format_template: "GRS: {gross_weight}g",
        x_mm: 40.0,
        y_mm: 1.0,
        width_mm: 38.0,
        height_mm: 3.5,
        font_size: 6.5,
        font_weight: "bold",
        alignment: "left",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_net",
        type: "text",
        field_key: "net_weight",
        label_prefix: "NET: ",
        format_template: "NET: {net_weight}g",
        x_mm: 40.0,
        y_mm: 4.5,
        width_mm: 38.0,
        height_mm: 3.0,
        font_size: 6,
        font_weight: "normal",
        alignment: "left",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_stone",
        type: "text",
        field_key: "stone_info",
        label_prefix: "S: ",
        format_template: "S: {stone_pcs}/{stone_weight}g",
        x_mm: 40.0,
        y_mm: 7.5,
        width_mm: 38.0,
        height_mm: 2.5,
        font_size: 5.5,
        font_weight: "normal",
        alignment: "left",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_dmd",
        type: "text",
        field_key: "diamond_info",
        label_prefix: "D: ",
        format_template: "D: {diamond_pcs}/{diamond_weight}ct",
        x_mm: 40.0,
        y_mm: 10.0,
        width_mm: 38.0,
        height_mm: 2.5,
        font_size: 5.5,
        font_weight: "normal",
        alignment: "left",
        is_bold: false,
        is_visible: true,
      },
    ]),
  },
  {
    name: "Standard Retail Barcode (50x25mm, 1-Across)",
    width_mm: 50.0,
    height_mm: 25.0,
    unit: "mm",
    labels_per_row: 1,
    gap_mm: 2.0,
    margin_top_mm: 1.5,
    margin_left_mm: 1.5,
    tag_style: "RECTANGLE",
    is_default: 0,
    elements_json: JSON.stringify([
      {
        id: "elem_comp",
        type: "text",
        field_key: "company_name",
        label_prefix: "",
        format_template: "{company_name}",
        x_mm: 2.0,
        y_mm: 1.5,
        width_mm: 46.0,
        height_mm: 3.5,
        font_size: 8,
        font_weight: "bold",
        alignment: "center",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_barcode",
        type: "barcode_1d",
        field_key: "sku",
        label_prefix: "",
        format_template: "{sku}",
        x_mm: 2.0,
        y_mm: 5.0,
        width_mm: 46.0,
        height_mm: 8.5,
        font_size: 7,
        font_weight: "normal",
        alignment: "center",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_sku_txt",
        type: "text",
        field_key: "sku",
        label_prefix: "SKU: ",
        format_template: "{sku}",
        x_mm: 2.0,
        y_mm: 14.0,
        width_mm: 46.0,
        height_mm: 3.0,
        font_size: 6.5,
        font_weight: "normal",
        alignment: "center",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_grs",
        type: "text",
        field_key: "gross_weight",
        label_prefix: "GRSWT: ",
        format_template: "GRSWT: {gross_weight}g",
        x_mm: 2.0,
        y_mm: 17.5,
        width_mm: 23.0,
        height_mm: 3.0,
        font_size: 6.5,
        font_weight: "bold",
        alignment: "left",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_purity",
        type: "text",
        field_key: "purity",
        label_prefix: "",
        format_template: "{purity}",
        x_mm: 25.0,
        y_mm: 17.5,
        width_mm: 23.0,
        height_mm: 3.0,
        font_size: 6.5,
        font_weight: "bold",
        alignment: "right",
        is_bold: true,
        is_visible: true,
      },
      {
        id: "elem_stones",
        type: "text",
        field_key: "stone_info",
        label_prefix: "S: ",
        format_template: "S: {stone_pcs}/{stone_weight}g",
        x_mm: 2.0,
        y_mm: 21.0,
        width_mm: 23.0,
        height_mm: 3.0,
        font_size: 5.5,
        font_weight: "normal",
        alignment: "left",
        is_bold: false,
        is_visible: true,
      },
      {
        id: "elem_dmd",
        type: "text",
        field_key: "diamond_info",
        label_prefix: "D: ",
        format_template: "D: {diamond_pcs}/{diamond_weight}ct",
        x_mm: 25.0,
        y_mm: 21.0,
        width_mm: 23.0,
        height_mm: 3.0,
        font_size: 5.5,
        font_weight: "normal",
        alignment: "right",
        is_bold: false,
        is_visible: true,
      },
    ]),
  },
];

/**
 * Ensures barcode_templates table exists and seeds defaults if empty.
 */
export async function ensureBarcodeTemplatesTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`barcode_templates:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS barcode_templates (
        template_id INTEGER PRIMARY KEY AUTOINCREMENT,
        companyid TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        width_mm REAL NOT NULL DEFAULT 80.0,
        height_mm REAL NOT NULL DEFAULT 13.0,
        unit TEXT NOT NULL DEFAULT 'mm',
        labels_per_row INTEGER NOT NULL DEFAULT 2,
        gap_mm REAL DEFAULT 2.0,
        margin_top_mm REAL DEFAULT 1.0,
        margin_left_mm REAL DEFAULT 1.0,
        tag_style TEXT NOT NULL DEFAULT 'JEWELRY_BUTTERFLY',
        is_default INTEGER DEFAULT 0,
        elements_json TEXT NOT NULL DEFAULT '[]',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Seed defaults if empty
    const check = await client.execute(`SELECT COUNT(*) as count FROM barcode_templates;`);
    const count = check.rows?.[0]?.count || 0;
    if (count === 0) {
      for (const t of DEFAULT_TEMPLATES) {
        await client.execute({
          sql: `
            INSERT INTO barcode_templates (
              companyid, name, width_mm, height_mm, unit, labels_per_row,
              gap_mm, margin_top_mm, margin_left_mm, tag_style, is_default, elements_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
          `,
          args: [
            "",
            t.name,
            t.width_mm,
            t.height_mm,
            t.unit,
            t.labels_per_row,
            t.gap_mm,
            t.margin_top_mm,
            t.margin_left_mm,
            t.tag_style,
            t.is_default,
            t.elements_json,
          ],
        });
      }
    }
  });
}

/**
 * GET /api/tenant/barcode-templates
 * Returns all barcode templates for tenant.
 */
export async function getBarcodeTemplatesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBarcodeTemplatesTable(client);

    const result = await client.execute(`
      SELECT * FROM barcode_templates ORDER BY is_default DESC, template_id ASC;
    `);

    const templates = (result.rows || []).map((row) => ({
      template_id: row.template_id,
      companyid: row.companyid,
      name: row.name,
      width_mm: Number(row.width_mm || 80.0),
      height_mm: Number(row.height_mm || 13.0),
      unit: row.unit || "mm",
      labels_per_row: Number(row.labels_per_row || 1),
      gap_mm: Number(row.gap_mm || 2.0),
      margin_top_mm: Number(row.margin_top_mm || 1.0),
      margin_left_mm: Number(row.margin_left_mm || 1.0),
      tag_style: row.tag_style || "JEWELRY_BUTTERFLY",
      is_default: Number(row.is_default || 0) === 1,
      elements: (() => {
        try {
          return typeof row.elements_json === "string"
            ? JSON.parse(row.elements_json)
            : row.elements_json || [];
        } catch (_) {
          return [];
        }
      })(),
      created_at: row.created_at,
      updated_at: row.updated_at,
    }));

    return res.json({
      success: true,
      templates,
      total_count: templates.length,
    });
  } catch (error) {
    console.error("Error in getBarcodeTemplatesController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to fetch barcode templates." });
  }
}

/**
 * POST /api/tenant/barcode-templates
 * Creates a new barcode template.
 */
export async function createBarcodeTemplateController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBarcodeTemplatesTable(client);

    const {
      companyid = "",
      name,
      width_mm = 80.0,
      height_mm = 13.0,
      unit = "mm",
      labels_per_row = 1,
      gap_mm = 2.0,
      margin_top_mm = 1.0,
      margin_left_mm = 1.0,
      tag_style = "RECTANGLE",
      is_default = false,
      elements = [],
    } = req.body;

    if (!name || String(name).trim() === "") {
      return res.status(400).json({ success: false, message: "Template name is required." });
    }

    if (is_default) {
      await client.execute(`UPDATE barcode_templates SET is_default = 0;`);
    }

    const insertResult = await client.execute({
      sql: `
        INSERT INTO barcode_templates (
          companyid, name, width_mm, height_mm, unit, labels_per_row,
          gap_mm, margin_top_mm, margin_left_mm, tag_style, is_default, elements_json,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      `,
      args: [
        String(companyid || "").trim(),
        String(name).trim(),
        parseFloat(width_mm) || 80.0,
        parseFloat(height_mm) || 13.0,
        String(unit || "mm").trim(),
        parseInt(labels_per_row, 10) || 1,
        parseFloat(gap_mm) || 2.0,
        parseFloat(margin_top_mm) || 1.0,
        parseFloat(margin_left_mm) || 1.0,
        String(tag_style || "RECTANGLE").trim(),
        is_default ? 1 : 0,
        JSON.stringify(elements || []),
      ],
    });

    return res.status(201).json({
      success: true,
      message: "Barcode template created successfully.",
      template_id: Number(insertResult.lastInsertRowid),
    });
  } catch (error) {
    console.error("Error in createBarcodeTemplateController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to create barcode template." });
  }
}

/**
 * PUT /api/tenant/barcode-templates/:id
 * Updates an existing barcode template.
 */
export async function updateBarcodeTemplateController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBarcodeTemplatesTable(client);

    const { id } = req.params;
    const templateId = parseInt(id, 10);
    if (isNaN(templateId)) {
      return res.status(400).json({ success: false, message: "Invalid Template ID." });
    }

    const {
      companyid,
      name,
      width_mm,
      height_mm,
      unit,
      labels_per_row,
      gap_mm,
      margin_top_mm,
      margin_left_mm,
      tag_style,
      is_default,
      elements,
    } = req.body;

    if (is_default) {
      await client.execute(`UPDATE barcode_templates SET is_default = 0;`);
    }

    const result = await client.execute({
      sql: `
        UPDATE barcode_templates SET
          companyid = COALESCE(?, companyid),
          name = COALESCE(?, name),
          width_mm = COALESCE(?, width_mm),
          height_mm = COALESCE(?, height_mm),
          unit = COALESCE(?, unit),
          labels_per_row = COALESCE(?, labels_per_row),
          gap_mm = COALESCE(?, gap_mm),
          margin_top_mm = COALESCE(?, margin_top_mm),
          margin_left_mm = COALESCE(?, margin_left_mm),
          tag_style = COALESCE(?, tag_style),
          is_default = COALESCE(?, is_default),
          elements_json = COALESCE(?, elements_json),
          updated_at = CURRENT_TIMESTAMP
        WHERE template_id = ?;
      `,
      args: [
        companyid !== undefined ? String(companyid).trim() : null,
        name !== undefined ? String(name).trim() : null,
        width_mm !== undefined ? parseFloat(width_mm) : null,
        height_mm !== undefined ? parseFloat(height_mm) : null,
        unit !== undefined ? String(unit).trim() : null,
        labels_per_row !== undefined ? parseInt(labels_per_row, 10) : null,
        gap_mm !== undefined ? parseFloat(gap_mm) : null,
        margin_top_mm !== undefined ? parseFloat(margin_top_mm) : null,
        margin_left_mm !== undefined ? parseFloat(margin_left_mm) : null,
        tag_style !== undefined ? String(tag_style).trim() : null,
        is_default !== undefined ? (is_default ? 1 : 0) : null,
        elements !== undefined ? JSON.stringify(elements) : null,
        templateId,
      ],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "Barcode template not found." });
    }

    return res.json({ success: true, message: "Barcode template updated successfully." });
  } catch (error) {
    console.error("Error in updateBarcodeTemplateController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to update barcode template." });
  }
}

/**
 * DELETE /api/tenant/barcode-templates/:id
 */
export async function deleteBarcodeTemplateController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBarcodeTemplatesTable(client);

    const { id } = req.params;
    const templateId = parseInt(id, 10);
    if (isNaN(templateId)) {
      return res.status(400).json({ success: false, message: "Invalid Template ID." });
    }

    const result = await client.execute({
      sql: `DELETE FROM barcode_templates WHERE template_id = ?;`,
      args: [templateId],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "Barcode template not found." });
    }

    return res.json({ success: true, message: "Barcode template deleted successfully." });
  } catch (error) {
    console.error("Error in deleteBarcodeTemplateController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to delete barcode template." });
  }
}

/**
 * POST /api/tenant/barcode-templates/:id/set-default
 */
export async function setDefaultBarcodeTemplateController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureBarcodeTemplatesTable(client);

    const { id } = req.params;
    const templateId = parseInt(id, 10);
    if (isNaN(templateId)) {
      return res.status(400).json({ success: false, message: "Invalid Template ID." });
    }

    await client.execute(`UPDATE barcode_templates SET is_default = 0;`);
    const result = await client.execute({
      sql: `UPDATE barcode_templates SET is_default = 1, updated_at = CURRENT_TIMESTAMP WHERE template_id = ?;`,
      args: [templateId],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({ success: false, message: "Barcode template not found." });
    }

    return res.json({ success: true, message: "Default barcode template set successfully." });
  } catch (error) {
    console.error("Error in setDefaultBarcodeTemplateController:", error);
    return res.status(500).json({ success: false, message: error?.message || "Failed to set default barcode template." });
  }
}
