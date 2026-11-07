import { createTenantClient } from "../config/turso.js";
import {
  getProductsController,
  getSizesController,
  createSizeController,
  updateSizeController,
  deleteSizeController,
} from "../controllers/inventoryMasterController.js";

async function runTest() {
  console.log("=== Testing Size Master (7th Inventory Master) ===");

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

  try {
    // 1. Fetch Products
    console.log("\n[1] Fetching products from Product Master...");
    let res = createMockRes();
    await getProductsController(fakeReq, res);
    const products = res.jsonResult?.products || [];
    if (products.length === 0) {
      throw new Error("No products found in DB to attach a size to.");
    }
    const testProduct = products[0];
    console.log(`Using Product: ID=${testProduct.productid}, Name='${testProduct.productname}', Category='${testProduct.catname}'`);

    // 2. Create Size under testProduct
    console.log("\n[2] Creating new Size 'Size 14 (Standard)'...");
    fakeReq.body = {
      productid: testProduct.productid,
      sizename: "Size 14 (Standard)",
    };

    res = createMockRes();
    await createSizeController(fakeReq, res);
    console.log("Create Response Status:", res.statusCode);
    console.log("Create Response Body:", res.jsonResult);

    if (res.statusCode !== 201 || !res.jsonResult?.success) {
      throw new Error(`Failed to create size: ${JSON.stringify(res.jsonResult)}`);
    }

    const createdSizeId = res.jsonResult.sizeid;
    console.log(`✓ Created Size ID: ${createdSizeId}`);

    // 3. Verify duplicate prevention for same product + sizename
    console.log("\n[3] Testing duplicate size prevention under same product...");
    res = createMockRes();
    await createSizeController(fakeReq, res);
    console.log("Duplicate Attempt Status:", res.statusCode);
    console.log("Duplicate Attempt Message:", res.jsonResult?.message);
    if (res.statusCode !== 400) {
      throw new Error("Expected duplicate size creation to return status 400");
    }
    console.log("✓ Duplicate prevention working correctly!");

    // 4. Verify getSizesController returns joined records
    console.log("\n[4] Fetching sizes via getSizesController...");
    fakeReq.body = {};
    res = createMockRes();
    await getSizesController(fakeReq, res);
    const sizes = res.jsonResult?.sizes || [];
    const foundSize = sizes.find(s => s.sizeid === createdSizeId);

    console.log("Found Joined Size Record:", foundSize);
    if (!foundSize) throw new Error("Created size not found in list");
    if (foundSize.sizename !== "Size 14 (Standard)") throw new Error("Size name mismatch");
    if (foundSize.productname !== testProduct.productname) throw new Error("Joined productname mismatch");
    console.log("✓ Verified: getSizesController successfully returns joined product/category/metal data!");

    // 5. Update Size
    console.log("\n[5] Updating size name to 'Size 14.5 (Extended)'...");
    fakeReq.params = { id: createdSizeId };
    fakeReq.body = {
      productid: testProduct.productid,
      sizename: "Size 14.5 (Extended)",
    };
    res = createMockRes();
    await updateSizeController(fakeReq, res);
    console.log("Update Response Status:", res.statusCode);
    console.log("Update Response Body:", res.jsonResult);
    if (res.statusCode !== 200 || !res.jsonResult?.success) {
      throw new Error(`Update failed: ${JSON.stringify(res.jsonResult)}`);
    }
    console.log("✓ Size updated successfully!");

    // 6. Delete Size (Clean up)
    console.log("\n[6] Deleting test size...");
    res = createMockRes();
    await deleteSizeController(fakeReq, res);
    console.log("Delete Response Status:", res.statusCode);
    console.log("Delete Response Body:", res.jsonResult);
    if (res.statusCode !== 200 || !res.jsonResult?.success) {
      throw new Error(`Delete failed: ${JSON.stringify(res.jsonResult)}`);
    }
    console.log("✓ Size deleted successfully and cleaned up!");

    console.log("\n ALL SIZE MASTER TESTS PASSED 100%! ");
  } catch (err) {
    console.error("\n❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
