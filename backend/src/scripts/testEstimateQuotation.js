import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getEstimatesController,
  getBarcodeForEstimateController,
  createEstimateController,
  updateEstimateController,
  deleteEstimateController,
  bulkDeleteEstimatesByDateController,
} from "../controllers/estimateController.js";

async function runEstimateTests() {
  console.log("=== STARTING ESTIMATE / QUOTATION AUTOMATED TESTS ===");

  const tenantRes = await masterTurso.execute(`SELECT * FROM tenants LIMIT 1;`);
  if (tenantRes.rows.length === 0) {
    console.error("No tenant found!");
    process.exit(1);
  }
  const tenant = tenantRes.rows[0];
  const client = createTenantClient(tenant.turso_url, tenant.turso_token);

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
        return { statusCode, data: responseData };
      },
      _getData() {
        return { statusCode, data: responseData };
      },
    };
  }

  try {
    const now = new Date().toISOString();

    // Fetch existing company, branch, purity, product, designer
    const branchRes = await client.execute(`SELECT branchid FROM branches LIMIT 1;`);
    const validBranchId = branchRes.rows[0]?.branchid || "MAIN";

    const compRes = await client.execute(`SELECT companyid FROM company LIMIT 1;`);
    const validCompId = compRes.rows[0]?.companyid || "COMP1";

    const prodRes = await client.execute(`SELECT productid FROM products LIMIT 1;`);
    const validProdId = Number(prodRes.rows[0]?.productid || 1);

    const purityRes = await client.execute(`SELECT purityid FROM purities LIMIT 1;`);
    const validPurityId = Number(purityRes.rows[0]?.purityid || 1);

    const designerRes = await client.execute(`SELECT designerid FROM designers LIMIT 1;`);
    const validDesignerId = Number(designerRes.rows[0]?.designerid || 1);

    // 1. Ensure test employee exists
    await client.execute({
      sql: `INSERT OR REPLACE INTO employees (empid, empname, branchid, mobile, active, created_at, updated_at)
            VALUES (999, 'Karthik Sales Lead', ?, '+91 9876543210', 1, ?, ?);`,
      args: [validBranchId, now, now],
    });
    console.log(" 1. Test employee seeded successfully.");

    // 2. Ensure test parent lot exists in prepare_sku_lots
    const lotRes = await client.execute({
      sql: `
        INSERT OR REPLACE INTO prepare_sku_lots (
          lot_id, lot_number, companyid, branchid, designerid, productid, purityid,
          total_pcs, total_gross_weight, total_net_weight, is_active, status
        ) VALUES (9999, 'LOT-TEST-EST', ?, ?, ?, ?, ?, 1, 12.500, 11.800, 1, 'OPEN');
      `,
      args: [validCompId, validBranchId, validDesignerId, validProdId, validPurityId],
    });

    // 3. Ensure test tagged barcode item exists
    const testSku = "TEST-SKU-EST-001";
    await client.execute({
      sql: `
        INSERT OR REPLACE INTO stock_tagged_items (
          sku_code, lot_id, lot_number, companyid, branchid, designerid, productid,
          purityid, pcs, gross_weight, net_weight, stone_pcs, stone_weight, stone_amt,
          diamond_pcs, diamond_weight, diamond_amt, board_rate, sales_va_percent, sales_m_charge,
          sales_total_amt, status
        ) VALUES (?, 9999, 'LOT-TEST-EST', ?, ?, ?, ?, ?, 1, 12.500, 11.800, 2, 0.700, 1500.0, 1, 0.15, 6500.0, 6800.0, 8.5, 450.0, 95000.0, 'IN_STOCK');
      `,
      args: [testSku, validCompId, validBranchId, validDesignerId, validProdId, validPurityId],
    });
    console.log(" 2. Test tagged stock barcode item seeded.");

    // 3. Test Barcode Lookup for Estimate
    const lookupReq = { tenant, params: { sku: testSku } };
    const lookupRes = mockRes();
    await getBarcodeForEstimateController(lookupReq, lookupRes);
    const lookupData = lookupRes._getData().data;

    if (!lookupData.success || !lookupData.data) {
      throw new Error(`Barcode lookup failed: ${JSON.stringify(lookupData)}`);
    }
    console.log(` 3. Barcode Lookup succeeded for '${testSku}': Product='${lookupData.data.productname}', NetWt=${lookupData.data.net_weight}g, VA=${lookupData.data.va_percent}%, Total=${lookupData.data.total_amount}`);

    // 4. Test Create Estimate Quotation with Barcode item and Employee Code
    const createReq = {
      tenant,
      body: {
        customer_name: "Mrs. Meena Sundaram",
        customer_mobile: "+91 9444123456",
        customer_address: "124 Gold Palace Street, Chennai",
        employee_id: 999,
        employee_code: "EMP-999",
        employee_name: "Karthik Sales Lead",
        gross_weight: 12.500,
        net_weight: 11.800,
        total_metal_value: lookupData.data.metal_value,
        total_making_charges: lookupData.data.mc,
        total_stone_charges: lookupData.data.stone_selling_price,
        total_diamond_charges: lookupData.data.diamond_selling_price,
        total_va_charges: lookupData.data.va_charges,
        taxable_amount: lookupData.data.taxable_amount,
        gst_rate: lookupData.data.gst_rate,
        tax_amount: lookupData.data.gst_amount,
        net_amount: lookupData.data.total_amount,
        status: "OPEN",
        notes: "Festive discount requested on MC.",
        items_json: [
          {
            sku_code: testSku,
            productname: lookupData.data.productname,
            purityname: lookupData.data.purityname,
            gross_weight: lookupData.data.gross_weight,
            net_weight: lookupData.data.net_weight,
            stone_selling_price: lookupData.data.stone_selling_price,
            diamond_selling_price: lookupData.data.diamond_selling_price,
            va_percent: lookupData.data.va_percent,
            mc: lookupData.data.mc,
            board_rate: lookupData.data.board_rate,
            gst_rate: lookupData.data.gst_rate,
            gst_amount: lookupData.data.gst_amount,
            total_amount: lookupData.data.total_amount,
          },
        ],
      },
    };

    const createRes = mockRes();
    await createEstimateController(createReq, createRes);
    const createdData = createRes._getData().data;

    if (!createdData.success || !createdData.estimate_id) {
      throw new Error(`Create estimate failed: ${JSON.stringify(createdData)}`);
    }

    const createdId = createdData.estimate_id;
    const estNo = createdData.estimate_no;
    console.log(` 4. Created Estimate '${estNo}' (ID: ${createdId}) with employee 'EMP-999'.`);

    // 5. Test Get Estimates List
    const getReq = { tenant, query: { search: "Meena" } };
    const getRes = mockRes();
    await getEstimatesController(getReq, getRes);
    const listData = getRes._getData().data;

    if (!listData.success || !listData.estimates || listData.estimates.length === 0) {
      throw new Error(`getEstimates failed to find created estimate: ${JSON.stringify(listData)}`);
    }
    console.log(` 5. getEstimatesController successfully returned records with stats (Total Count: ${listData.total_count}, Today: ${listData.today_count}).`);

    // 6. Test Update Estimate
    const updateReq = {
      tenant,
      params: { id: createdId },
      body: {
        customer_name: "Mrs. Meena Sundaram - VIP",
        customer_mobile: "+91 9444123456",
        customer_address: "124 Gold Palace Street, Chennai",
        employee_id: 999,
        employee_code: "EMP-999",
        employee_name: "Karthik Sales Lead",
        gross_weight: 12.500,
        net_weight: 11.800,
        taxable_amount: lookupData.data.taxable_amount,
        gst_rate: 3.0,
        tax_amount: lookupData.data.gst_amount,
        net_amount: lookupData.data.total_amount,
        status: "OPEN",
        items_json: createReq.body.items_json,
        notes: "Updated to VIP status.",
      },
    };
    const updateRes = mockRes();
    await updateEstimateController(updateReq, updateRes);
    const updateData = updateRes._getData().data;
    if (!updateData.success) {
      throw new Error(`Update estimate failed: ${JSON.stringify(updateData)}`);
    }
    console.log(" 6. updateEstimateController succeeded.");

    // 7. Test Bulk Delete Date-wise
    const todayStr = new Date().toISOString().slice(0, 10);
    const bulkDelReq = {
      tenant,
      query: { from_date: todayStr, to_date: todayStr },
      body: {},
    };
    const bulkDelRes = mockRes();
    await bulkDeleteEstimatesByDateController(bulkDelReq, bulkDelRes);
    const bulkDelData = bulkDelRes._getData().data;

    if (!bulkDelData.success) {
      throw new Error(`bulkDeleteEstimatesByDate failed: ${JSON.stringify(bulkDelData)}`);
    }
    console.log(` 7. bulkDeleteEstimatesByDateController successfully purged ${bulkDelData.deleted_count} estimate(s) for date '${todayStr}'.`);

    // Cleanup test fixtures
    await client.execute({ sql: `DELETE FROM stock_tagged_items WHERE sku_code = ?;`, args: [testSku] });
    await client.execute({ sql: `DELETE FROM employees WHERE empid = 999;`, args: [] });

    console.log("\n ALL ESTIMATE & BARCODE QUOTATION TESTS PASSED PERFECTLY! \n");
  } catch (err) {
    console.error("Test execution failed:", err);
    process.exit(1);
  }
}

runEstimateTests();
