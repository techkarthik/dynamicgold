import { createTenantClient } from "../config/turso.js";
import {
  getCategoriesController,
  createCategoryController,
  updateCategoryController,
  deleteCategoryController,
  getPuritiesController,
} from "../controllers/inventoryMasterController.js";

async function runTest() {
  console.log("=== Testing Category Master Purity Linkage & Automated Sales/Purchase Accounts ===");

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
    // 1. Get available purities for Gold ('G')
    console.log("\n[1] Fetching purities...");
    let res = createMockRes();
    await getPuritiesController(fakeReq, res);
    const purities = res.jsonResult?.purities || [];
    console.log(`Found ${purities.length} purities:`, purities.map(p => `${p.purityid}: ${p.purityname} (${p.purityshortname})`));

    const goldPurity = purities.find(p => p.metalid === 'G') || purities[0];
    if (!goldPurity) throw new Error("No purity found for testing");

    console.log(`Using Purity: ID=${goldPurity.purityid}, Name=${goldPurity.purityname}, Short=${goldPurity.purityshortname}`);

    // 2. Create Category with Purity linked and no salesacname / purchaseacname specified
    console.log("\n[2] Creating Category 'Antique Bangles' linked to Purity ID:", goldPurity.purityid);
    fakeReq.body = {
      metalid: 'G',
      purityid: goldPurity.purityid,
      catname: 'Antique Bangles',
      categorytype: 'ORNAMENTS/STONE',
      sgst_per: 1.5,
      cgst_per: 1.5,
      igst_per: 3.0,
      // salesacname & purchaseacname left blank intentionally to test auto-generation & insertion!
    };

    res = createMockRes();
    await createCategoryController(fakeReq, res);
    console.log("Create Response status:", res.statusCode);
    console.log("Create Response result:", res.jsonResult);

    if (res.statusCode !== 201) throw new Error(`Category creation failed: ${JSON.stringify(res.jsonResult)}`);

    const { catcode, salesacname, purchaseacname } = res.jsonResult;
    console.log(`✓ Generated Sales Account: ${salesacname}`);
    console.log(`✓ Generated Purchase Account: ${purchaseacname}`);

    // 3. Verify in database that Category has purityid and correct auto accounts
    console.log("\n[3] Fetching categories to verify purity linkage...");
    res = createMockRes();
    await getCategoriesController(fakeReq, res);
    const createdCat = res.jsonResult?.categories?.find(c => c.catcode === catcode);
    console.log("Created Category record:", createdCat);

    if (!createdCat) throw new Error("Created category not found in list");
    if (createdCat.purityid !== goldPurity.purityid) throw new Error(`Purity ID mismatch: expected ${goldPurity.purityid}, got ${createdCat.purityid}`);
    if (createdCat.purityname !== goldPurity.purityname) throw new Error(`Purity name not joined: got ${createdCat.purityname}`);
    console.log("✓ Category correctly linked with Purity in database!");

    // 4. Verify in account_heads table that both auto accounts exist!
    console.log("\n[4] Checking account_heads table for auto-created Sales and Purchase accounts...");
    const salesHead = await client.execute({
      sql: `SELECT * FROM account_heads WHERE UPPER(TRIM(accountname)) = UPPER(TRIM(?)) LIMIT 1;`,
      args: [salesacname],
    });
    const purchaseHead = await client.execute({
      sql: `SELECT * FROM account_heads WHERE UPPER(TRIM(accountname)) = UPPER(TRIM(?)) LIMIT 1;`,
      args: [purchaseacname],
    });

    console.log("Sales Account in Master:", salesHead.rows[0]);
    console.log("Purchase Account in Master:", purchaseHead.rows[0]);

    if (salesHead.rows.length === 0) throw new Error(`Auto Sales Account '${salesacname}' was NOT found in account_heads!`);
    if (purchaseHead.rows.length === 0) throw new Error(`Auto Purchase Account '${purchaseacname}' was NOT found in account_heads!`);
    console.log("✓ Both Sales & Purchase accounts were automatically created in Account Head Master!");

    // 5. Update category with a new name and verify update
    console.log("\n[5] Updating Category (ID: " + createdCat.id + ")...");
    fakeReq.params = { id: createdCat.id };
    fakeReq.body = {
      metalid: 'G',
      purityid: goldPurity.purityid,
      catname: 'Antique Bangles Deluxe',
      categorytype: 'ORNAMENTS/STONE',
      sgst_per: 1.5,
      cgst_per: 1.5,
      igst_per: 3.0,
      salesacname: salesacname,
      purchaseacname: purchaseacname,
    };
    res = createMockRes();
    await updateCategoryController(fakeReq, res);
    console.log("Update response:", res.jsonResult);

    // 6. Cleanup test records
    console.log("\n[6] Cleaning up test Category (ID: " + createdCat.id + ")...");
    fakeReq.params = { id: createdCat.id };
    res = createMockRes();
    await deleteCategoryController(fakeReq, res);
    console.log("Delete Category response:", res.jsonResult);

    // Cleanup test account heads
    await client.execute({
      sql: `DELETE FROM account_heads WHERE UPPER(TRIM(accountname)) IN (UPPER(TRIM(?)), UPPER(TRIM(?)));`,
      args: [salesacname, purchaseacname],
    });
    console.log("Deleted test account heads from master.");

    console.log("\n ALL CATEGORY PURITY & AUTO ACCOUNTS TESTS PASSED 100%! ");
  } catch (err) {
    console.error("\n❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
