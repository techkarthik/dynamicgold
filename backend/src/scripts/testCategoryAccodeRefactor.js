import { createTenantClient } from "../config/turso.js";
import {
  getCategoriesController,
  createCategoryController,
  updateCategoryController,
  deleteCategoryController,
  getPuritiesController,
} from "../controllers/inventoryMasterController.js";

async function runTest() {
  console.log("=== Testing Category Master Relational accode Storage Refactor ===");

  const TURSO_URL = "libsql://gold-techkarthik.aws-ap-south-1.turso.io";
  const TURSO_TOKEN = (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || "");

  const fakeReq = {
    tenant: {
      turso_url: TURSO_URL,
      turso_token: TURSO_TOKEN,
    },
    body: {},
    params: {},
  };

  const createMockRes = () => {
    const res = {
      statusCode: 200,
      jsonResult: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.jsonResult = data;
        return this;
      },
    };
    return res;
  };

  const client = createTenantClient(TURSO_URL, TURSO_TOKEN);

  try {
    // 1. Fetch Purities
    console.log("\n[1] Fetching purities...");
    let res = createMockRes();
    await getPuritiesController(fakeReq, res);
    const purities = res.jsonResult?.purities || [];
    const goldPurity = purities.find(p => p.metalid === 'G') || purities[0];
    console.log(`Using Purity: ID=${goldPurity.purityid} (${goldPurity.purityshortname})`);

    // 2. Create Category 'Temple Necklaces' without selecting sales/purchase accounts (auto-generate & link accode)
    console.log("\n[2] Creating Category 'Temple Necklaces' with auto-generated accounts...");
    fakeReq.body = {
      metalid: 'G',
      purityid: goldPurity.purityid,
      catname: 'Temple Necklaces',
      categorytype: 'ORNAMENTS/STONE',
      sgst_per: 1.5,
      cgst_per: 1.5,
      igst_per: 3.0,
    };

    res = createMockRes();
    await createCategoryController(fakeReq, res);
    console.log("Create Response status:", res.statusCode);
    console.log("Create Response result:", res.jsonResult);

    if (res.statusCode !== 201) throw new Error(`Category creation failed: ${JSON.stringify(res.jsonResult)}`);

    const { catcode, sales_accode, purchase_accode, salesacname, purchaseacname } = res.jsonResult;
    console.log(`✓ Stored sales_accode: ${sales_accode} (Name: ${salesacname})`);
    console.log(`✓ Stored purchase_accode: ${purchase_accode} (Name: ${purchaseacname})`);

    if (!sales_accode || sales_accode.length < 5) throw new Error("Invalid sales_accode returned");
    if (!purchase_accode || purchase_accode.length < 5) throw new Error("Invalid purchase_accode returned");

    // 3. Directly inspect categories table raw row in database to verify accode is stored in columns
    console.log("\n[3] Checking database categories table directly for accode columns...");
    const rawCat = await client.execute({
      sql: `SELECT id, catcode, catname, sales_accode, purchase_accode FROM categories WHERE catcode = ? LIMIT 1;`,
      args: [catcode],
    });
    console.log("Direct DB categories row:", rawCat.rows[0]);
    if (rawCat.rows[0].sales_accode !== sales_accode) throw new Error("sales_accode not stored in categories table");
    if (rawCat.rows[0].purchase_accode !== purchase_accode) throw new Error("purchase_accode not stored in categories table");
    console.log("✓ Verified: accode is stored directly in categories table!");

    // 4. Verify getCategoriesController joins account_heads
    console.log("\n[4] Calling getCategoriesController to verify JOIN with account_heads...");
    fakeReq.body = {};
    res = createMockRes();
    await getCategoriesController(fakeReq, res);
    const fetched = res.jsonResult?.categories?.find(c => c.catcode === catcode);
    console.log("Fetched joined record:", fetched);

    if (!fetched) throw new Error("Category not found in fetched list");
    if (fetched.sales_accode !== sales_accode || fetched.salesacname !== salesacname) {
      throw new Error(`Joined sales account mismatch: expected code ${sales_accode} & name ${salesacname}, got ${fetched.sales_accode} & ${fetched.salesacname}`);
    }
    console.log("✓ Verified: getCategoriesController successfully resolved account names via JOIN on accode!");

    // 5. Cleanup test Category & Account heads
    console.log("\n[5] Cleaning up test records...");
    fakeReq.params = { id: fetched.id };
    res = createMockRes();
    await deleteCategoryController(fakeReq, res);
    console.log("Delete response:", res.jsonResult);

    await client.execute({
      sql: `DELETE FROM account_heads WHERE accode IN (?, ?);`,
      args: [sales_accode, purchase_accode],
    });
    console.log("Deleted test account heads from master.");

    console.log("\n ALL ACCODE STORAGE REFACTOR TESTS PASSED 100%! ");
  } catch (err) {
    console.error("\n❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
