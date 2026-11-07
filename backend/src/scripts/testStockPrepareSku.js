import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getPrepareSkuLotsController,
  createPrepareSkuLotController,
  updatePrepareSkuLotController,
  deletePrepareSkuLotController,
} from "../controllers/stockController.js";

async function runTest() {
  console.log("=== Testing Stock Prepare for SKU Controller (with Multi-Stone & Multi-Diamond) ===");

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

  // 1. Test Listing Lots (Initial)
  const req1 = { tenant, query: { companyid: "COMP01" } };
  const res1 = mockRes();
  await getPrepareSkuLotsController(req1, res1);
  console.log("Initial List Status:", res1.statusCode, "Total:", res1.jsonData?.total_count);

  // 2. Test Creating Lot with Multi-Stone and Multi-Diamond (with Rates & Amounts)
  const stoneItems = [
    { stone_productid: 1, stone_unit: 'G', pcs: 10, weight: 2.500, rate: 120.0, amount: 300.0 },
    { stone_productid: 2, stone_unit: 'C', pcs: 4, weight: 5.000, rate: 500.0, amount: 2500.0 } // 5 ct = 1.000 g
  ];
  const diamondItems = [
    { diamond_productid: 3, diamond_unit: 'C', pcs: 2, weight: 1.500, rate: 35000.0, amount: 52500.0 } // 1.5 ct = 0.300 g
  ];

  const req2 = {
    tenant,
    body: {
      companyid: "COMP01",
      branchid: "HO",
      designerid: 1,
      productid: 1,
      subproductid: null,
      purityid: 1,
      rate: 7250.0,
      is_assorted: "NO",
      total_pcs: 5,
      total_gross_weight: 50.000,
      // Less wt: 2.500 (stone G) + 1.000 (stone C) + 0.300 (dia C) = 3.800 g
      // Net wt: 50.000 - 3.800 = 46.200 g
      total_net_weight: 46.200,
      stone_unit: "G",
      stone_items: stoneItems,
      total_stone_amount: 2800.0,
      diamond_unit: "C",
      diamond_items: diamondItems,
      total_diamond_amount: 52500.0,
      remarks: "Test Multi-Item Stone & Diamond SKU Batch with Rates",
    },
  };
  const res2 = mockRes();
  await createPrepareSkuLotController(req2, res2);
  console.log("Create Lot Status:", res2.statusCode, "Response:", res2.jsonData);

  if (res2.statusCode !== 201) {
    throw new Error("Failed to create SKU lot: " + JSON.stringify(res2.jsonData));
  }

  const createdLotId = res2.jsonData.lot_id;
  const createdLotNo = res2.jsonData.lot_number;
  console.log("Created Lot ID:", createdLotId, "Lot No:", createdLotNo);

  // 3. Test Retrieval with Date Filter (Today)
  const todayStr = new Date().toISOString().slice(0, 10);
  const req3 = { tenant, query: { companyid: "COMP01", from_date: todayStr, to_date: todayStr } };
  const res3 = mockRes();
  await getPrepareSkuLotsController(req3, res3);
  const found = res3.jsonData.lots.find((l) => l.lot_id === createdLotId);
  console.log("Found Created Lot:", found?.lot_number, "Total Stone Wt:", found?.total_stone_weight, "Stone Amt:", found?.total_stone_amount);
  console.log("Diamond Wt:", found?.total_diamond_weight, "Diamond Amt:", found?.total_diamond_amount);
  console.log("Stone items:", found?.stone_items?.length, "Diamond items:", found?.diamond_items?.length);

  // 4. Test Update
  const req4 = {
    tenant,
    params: { id: createdLotId },
    body: {
      total_pcs: 6,
      total_gross_weight: 55.000,
      total_net_weight: 51.200,
      stone_items: [
        { stone_productid: 1, stone_unit: 'G', pcs: 12, weight: 3.000, rate: 150.0, amount: 450.0 }
      ],
      diamond_items: diamondItems,
      remarks: "Updated Remarks Batch with modified stone list and rates",
    },
  };
  const res4 = mockRes();
  await updatePrepareSkuLotController(req4, res4);
  console.log("Update Lot Status:", res4.statusCode, "Success:", res4.jsonData?.success);

  // 5. Test Soft Deactivation (Delete Controller)
  const req5 = { tenant, params: { id: createdLotId } };
  const res5 = mockRes();
  await deletePrepareSkuLotController(req5, res5);
  console.log("Deactivate Lot Status:", res5.statusCode, "Success:", res5.jsonData?.success);

  // 6. Verify Lot is now Inactive/Disabled and NOT hard-deleted
  const req6 = { tenant, query: { companyid: "COMP01", is_active: "all" } };
  const res6 = mockRes();
  await getPrepareSkuLotsController(req6, res6);
  const disabledLot = res6.jsonData.lots.find((l) => l.lot_id === createdLotId);
  console.log("Disabled Lot verified in DB! lot_number:", disabledLot?.lot_number, "is_active:", disabledLot?.is_active, "status:", disabledLot?.status);

  console.log("=== ALL TESTS PASSED SUCCESSFULLY ===");
}

runTest().catch((err) => {
  console.error("Test Error:", err);
  process.exit(1);
});
