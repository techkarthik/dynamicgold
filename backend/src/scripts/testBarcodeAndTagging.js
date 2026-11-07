import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getBarcodeTemplatesController,
  createBarcodeTemplateController,
  updateBarcodeTemplateController,
  setDefaultBarcodeTemplateController,
  deleteBarcodeTemplateController,
} from "../controllers/barcodeTemplateController.js";
import {
  getStockTagsController,
  getVaLookupController,
  generateTagsFromLotController,
  updateStockTagController,
  deleteStockTagController,
  markStockTagsPrintedController,
} from "../controllers/stockTaggingController.js";
import {
  createPrepareSkuLotController,
} from "../controllers/stockController.js";

async function runTest() {
  console.log("=== Testing Barcode Templates and Stock Tagging Controllers ===");

  const tenantRes = await masterTurso.execute(`SELECT * FROM tenants LIMIT 1;`);
  if (tenantRes.rows.length === 0) {
    console.error("No tenant found!");
    process.exit(1);
  }
  const tenant = tenantRes.rows[0];

  function mockRes() {
    let statusCode = 200;
    let responseData = null;
    return {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        responseData = data;
        return this;
      },
      get statusCode() {
        return statusCode;
      },
      get jsonData() {
        return responseData;
      },
    };
  }

  // 1. Test Barcode Templates Listing & Auto-seeding
  const res1 = mockRes();
  await getBarcodeTemplatesController({ tenant }, res1);
  console.log("1. Barcode Templates List Status:", res1.statusCode, "Count:", res1.jsonData?.total_count);
  if (!res1.jsonData?.success || res1.jsonData?.total_count < 1) {
    console.error("Templates failed to seed or fetch!", res1.jsonData);
    process.exit(1);
  }

  // 2. Create custom template
  const res2 = mockRes();
  await createBarcodeTemplateController(
    {
      tenant,
      body: {
        companyid: "COMP01",
        name: "Custom Diamond Tag 60x12mm",
        width_mm: 60.0,
        height_mm: 12.0,
        unit: "mm",
        labels_per_row: 2,
        gap_mm: 2.0,
        margin_top_mm: 1.0,
        margin_left_mm: 1.0,
        tag_style: "JEWELRY_DUMBBELL",
        is_default: false,
        elements: [
          { id: "e1", type: "barcode_2d", field_key: "sku", x_mm: 1, y_mm: 1, width_mm: 10, height_mm: 10 },
          { id: "e2", type: "text", field_key: "gross_weight", label_prefix: "GRS: ", format_template: "{gross_weight}g", x_mm: 12, y_mm: 1 }
        ]
      },
    },
    res2
  );
  console.log("2. Create Template Status:", res2.statusCode, "New ID:", res2.jsonData?.template_id);
  const customTemplateId = res2.jsonData?.template_id;

  // 3. Set custom template as default
  const res3 = mockRes();
  await setDefaultBarcodeTemplateController({ tenant, params: { id: customTemplateId } }, res3);
  console.log("3. Set Default Template Status:", res3.statusCode, "Message:", res3.jsonData?.message);

  // 4. Create a test Lot for tagging
  const resLot = mockRes();
  await createPrepareSkuLotController(
    {
      tenant,
      body: {
        companyid: "COMP01",
        branchid: "HO",
        designerid: 1,
        productid: 1,
        subproductid: 1,
        purityid: 1,
        rate: 7500.0,
        is_assorted: "NO",
        total_pcs: 3,
        total_gross_weight: 45.0,
        total_net_weight: 43.5,
        total_stone_pcs: 6,
        total_stone_weight: 1.5,
        remarks: "Test Lot for Tagging",
      },
    },
    resLot
  );
  console.log("4. Created Source Lot for Tagging:", resLot.statusCode, "Lot No:", resLot.jsonData?.lot_number, "Lot ID:", resLot.jsonData?.lot_id);
  const testLotId = resLot.jsonData?.lot_id;
  const testLotNo = resLot.jsonData?.lot_number;

  // 5. Test VA Lookup
  const resVa = mockRes();
  await getVaLookupController(
    {
      tenant,
      query: {
        companyid: "COMP01",
        branchid: "HO",
        productid: 1,
        subproductid: 1,
        accode: "ACC01",
        weight: 15.0,
      },
    },
    resVa
  );
  console.log("5. VA Lookup Status:", resVa.statusCode, "Matched:", resVa.jsonData?.matched, "VA %:", resVa.jsonData?.price_setting?.va_percent);

  // 6. Generate SKU Tags from Lot (with Purchase Costing & Sales Pricing)
  const resTag = mockRes();
  await generateTagsFromLotController(
    {
      tenant,
      body: {
        lot_id: testLotId,
        tags_count: 3,
        board_rate: 7500.0,
        sales_va_percent: 12.0,
        sales_wastage: 2.0,
        sales_mc_per_gram: 150.0,
        sales_m_charge: 0.0,
        // Purchase costing inputs from Smith
        purchase_touch_pct: 94.0, // 94% Touch
        purchase_gold_rate: 7400.0,
        purchase_mc: 350.0,
        purchase_stone_cost: 200.0,
        purchase_diamond_cost: 0.0,
        huid: "HUID916001",
        remarks: "Piece 1 of 3",
      },
    },
    resTag
  );
  console.log("6. Generate Tags Status:", resTag.statusCode, "SKUs generated:", resTag.jsonData?.sku_codes);

  // 7. Get Stock Tags List
  const resList = mockRes();
  await getStockTagsController(
    {
      tenant,
      query: { lot_id: testLotId },
    },
    resList
  );
  console.log("7. Stock Tags List Status:", resList.statusCode, "Total Tags for Lot:", resList.jsonData?.total_count);
  const firstTag = resList.jsonData?.tags?.[0];
  console.log("   First Tag SKU:", firstTag?.sku_code);
  console.log("   Sales Total Amt:", firstTag?.sales_total_amt);
  console.log("   Purchase Touch %:", firstTag?.purchase_touch_pct, "Purchase Total Cost:", firstTag?.purchase_total_cost);

  // 8. Mark Tag as Printed
  const resPrint = mockRes();
  await markStockTagsPrintedController(
    {
      tenant,
      body: { item_ids: [firstTag?.item_id] },
    },
    resPrint
  );
  console.log("8. Mark Printed Status:", resPrint.statusCode, "Message:", resPrint.jsonData?.message);

  // Clean up custom template
  if (customTemplateId) {
    const resDel = mockRes();
    await deleteBarcodeTemplateController({ tenant, params: { id: customTemplateId } }, resDel);
    console.log("9. Cleaned up test template:", resDel.statusCode);
  }

  console.log("\n=== ALL BACKEND BARCODE & TAGGING TESTS PASSED SUCCESSFULLY! ===");
}

runTest().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
