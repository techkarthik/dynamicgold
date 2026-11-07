import { createTenantClient } from "../config/turso.js";
import {
  getProductsController,
  getStylesController,
  createStyleController,
  updateStyleController,
  deleteStyleController,
} from "../controllers/inventoryMasterController.js";

async function runTest() {
  console.log("=== Testing Style Master (6th Inventory Master) ===");

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
    // 1. Fetch Products
    console.log("\n[1] Fetching products from Product Master...");
    let res = createMockRes();
    await getProductsController(fakeReq, res);
    const products = res.jsonResult?.products || [];
    if (products.length === 0) {
      throw new Error("No products found in DB to attach a style to. Please ensure products exist.");
    }
    const testProduct = products[0];
    console.log(`Using Product: ID=${testProduct.productid}, Name='${testProduct.productname}', Category='${testProduct.catname}'`);

    // 2. Create Style under testProduct
    console.log("\n[2] Creating new Style 'Antique Temple Filigree'...");
    fakeReq.body = {
      productid: testProduct.productid,
      stylename: "Antique Temple Filigree",
    };

    res = createMockRes();
    await createStyleController(fakeReq, res);
    console.log("Create Response Status:", res.statusCode);
    console.log("Create Response Body:", res.jsonResult);

    if (res.statusCode !== 201 || !res.jsonResult?.success) {
      throw new Error(`Failed to create style: ${JSON.stringify(res.jsonResult)}`);
    }

    const createdStyleId = res.jsonResult.styleid;
    console.log(`✓ Created Style ID: ${createdStyleId}`);

    // 3. Verify duplicate prevention for same product + stylename
    console.log("\n[3] Testing duplicate style prevention...");
    res = createMockRes();
    await createStyleController(fakeReq, res);
    console.log("Duplicate Attempt Status:", res.statusCode);
    console.log("Duplicate Attempt Message:", res.jsonResult?.message);
    if (res.statusCode !== 400) {
      throw new Error("Expected duplicate style creation to return status 400");
    }
    console.log("✓ Duplicate prevention working correctly!");

    // 4. Verify getStylesController returns joined records
    console.log("\n[4] Fetching styles via getStylesController...");
    fakeReq.body = {};
    res = createMockRes();
    await getStylesController(fakeReq, res);
    const styles = res.jsonResult?.styles || [];
    const foundStyle = styles.find(s => s.styleid === createdStyleId);

    console.log("Found Joined Style Record:", foundStyle);
    if (!foundStyle) throw new Error("Created style not found in list");
    if (foundStyle.stylename !== "Antique Temple Filigree") throw new Error("Style name mismatch");
    if (foundStyle.productname !== testProduct.productname) throw new Error("Joined productname mismatch");
    console.log("✓ Verified: getStylesController successfully returns joined product/category/metal data!");

    // 5. Update Style
    console.log("\n[5] Updating style name to 'Antique Royal Temple Filigree'...");
    fakeReq.params = { id: createdStyleId };
    fakeReq.body = {
      productid: testProduct.productid,
      stylename: "Antique Royal Temple Filigree",
    };
    res = createMockRes();
    await updateStyleController(fakeReq, res);
    console.log("Update Response Status:", res.statusCode);
    console.log("Update Response Body:", res.jsonResult);
    if (res.statusCode !== 200 || !res.jsonResult?.success) {
      throw new Error(`Update failed: ${JSON.stringify(res.jsonResult)}`);
    }
    console.log("✓ Style updated successfully!");

    // 6. Delete Style (Clean up)
    console.log("\n[6] Deleting test style...");
    res = createMockRes();
    await deleteStyleController(fakeReq, res);
    console.log("Delete Response Status:", res.statusCode);
    console.log("Delete Response Body:", res.jsonResult);
    if (res.statusCode !== 200 || !res.jsonResult?.success) {
      throw new Error(`Delete failed: ${JSON.stringify(res.jsonResult)}`);
    }
    console.log("✓ Style deleted successfully and cleaned up!");

    console.log("\n ALL STYLE MASTER TESTS PASSED 100%! ");
  } catch (err) {
    console.error("\n❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
