import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getDiamondPriceSettingsController,
  getDiamondProductsController,
  createDiamondPriceSettingController,
  updateDiamondPriceSettingController,
  deleteDiamondPriceSettingController,
} from "../controllers/inventoryMasterController.js";

async function runDiamondPriceSettingTests() {
  console.log("=== STARTING DIAMOND PRICE SETTING MASTER AUTOMATED TESTS ===");

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
    // 1. Ensure prerequisite tables & seed data
    const now = new Date().toISOString();

    // Create companies & branches
    await client.execute(`
      CREATE TABLE IF NOT EXISTS company (
        companyid TEXT PRIMARY KEY,
        companyname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    await client.execute({
      sql: `INSERT OR IGNORE INTO company (companyid, companyname, created_at, updated_at) VALUES (?, ?, ?, ?);`,
      args: ["COMP_DIA_1", "Diamond Test Company 1", now, now],
    });

    await client.execute(`
      CREATE TABLE IF NOT EXISTS branches (
        branchid TEXT PRIMARY KEY,
        branchname TEXT NOT NULL,
        companyid TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    await client.execute({
      sql: `INSERT OR IGNORE INTO branches (branchid, branchname, companyid, created_at, updated_at) VALUES (?, ?, ?, ?, ?);`,
      args: ["BR_DIA_1", "Diamond Test Branch Alpha", "COMP_DIA_1", now, now],
    });

    // Seed metals and category
    await client.execute(`
      CREATE TABLE IF NOT EXISTS metals (
        metalid TEXT PRIMARY KEY,
        metalname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    await client.execute({
      sql: `INSERT OR IGNORE INTO metals (metalid, metalname, created_at, updated_at) VALUES (?, ?, ?, ?);`,
      args: ["G", "Gold", now, now],
    });

    await client.execute(`
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metalid TEXT NOT NULL,
        catcode TEXT NOT NULL,
        catname TEXT NOT NULL,
        categorytype TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    let catRes = await client.execute({
      sql: `SELECT id FROM categories WHERE catcode = ? LIMIT 1;`,
      args: ["CAT_DIA_1"],
    });
    let catId;
    if (catRes.rows.length === 0) {
      const insertedCat = await client.execute({
        sql: `INSERT INTO categories (metalid, catcode, catname, categorytype, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?);`,
        args: ["G", "CAT_DIA_1", "Diamond Jewellery", "ORNAMENTS/STONE", now, now],
      });
      catId = Number(insertedCat.lastInsertRowid);
    } else {
      catId = Number(catRes.rows[0].id);
    }

    // Seed products: 1 with diastone='D', 1 with diastone='S', 1 with diastone=''
    await client.execute(`
      CREATE TABLE IF NOT EXISTS products (
        productid INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryid INTEGER NOT NULL,
        productname TEXT NOT NULL,
        diastone TEXT NOT NULL DEFAULT '',
        havestone_diamond TEXT NOT NULL DEFAULT 'NO',
        havesubproduct TEXT NOT NULL DEFAULT 'NO',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    async function getOrCreateProd(pName, diaStone) {
      const p = await client.execute({
        sql: `SELECT productid FROM products WHERE productname = ? LIMIT 1;`,
        args: [pName],
      });
      if (p.rows.length > 0) return Number(p.rows[0].productid);
      const ins = await client.execute({
        sql: `INSERT INTO products (categoryid, productname, diastone, havestone_diamond, havesubproduct, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?);`,
        args: [catId, pName, diaStone, diaStone ? "YES" : "NO", "YES", now, now],
      });
      return Number(ins.lastInsertRowid);
    }

    const prodDiaId = await getOrCreateProd("DIA_PROD_DIAMOND_RING", "D");
    const prodStoneId = await getOrCreateProd("DIA_PROD_STONE_STUD", "S");
    const prodPlainId = await getOrCreateProd("DIA_PROD_PLAIN_BAND", "");

    // Seed subproducts
    await client.execute(`
      CREATE TABLE IF NOT EXISTS subproducts (
        subproductid INTEGER PRIMARY KEY AUTOINCREMENT,
        productid INTEGER NOT NULL,
        subproductname TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    let subRes = await client.execute({
      sql: `SELECT subproductid FROM subproducts WHERE productid = ? AND subproductname = ? LIMIT 1;`,
      args: [prodDiaId, "VVS Round Cut"],
    });
    let subId;
    if (subRes.rows.length === 0) {
      const insSub = await client.execute({
        sql: `INSERT INTO subproducts (productid, subproductname, created_at, updated_at) VALUES (?, ?, ?, ?);`,
        args: [prodDiaId, "VVS Round Cut", now, now],
      });
      subId = Number(insSub.lastInsertRowid);
    } else {
      subId = Number(subRes.rows[0].subproductid);
    }

    // Seed Dealer account head
    await client.execute({
      sql: `INSERT OR REPLACE INTO account_heads (accode, groupname, accountname, accounttype, active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);`,
      args: ["DIA_DLR_01", "SUNDRY CREDITORS", "Solitaire Diamond Suppliers", "DEALER", now, now],
    });

    console.log(" 1. Prerequisite tables & seed data initialized successfully.");

    // 2. Test getDiamondProductsController (must return diastone in ('D', 'S') and exclude plain)
    const prodRes = mockRes();
    await getDiamondProductsController({ tenant }, prodRes);
    const prodData = prodRes._getData().data;
    if (!prodData.success || !Array.isArray(prodData.products)) {
      throw new Error("getDiamondProductsController failed.");
    }
    const diaProducts = prodData.products;
    const hasDia = diaProducts.some((p) => p.productid === prodDiaId);
    const hasStone = diaProducts.some((p) => p.productid === prodStoneId);
    const hasPlain = diaProducts.some((p) => p.productid === prodPlainId);
    if (!hasDia || !hasStone || hasPlain) {
      throw new Error("getDiamondProductsController did not correctly filter products by diastone in ('D', 'S').");
    }
    console.log(` 2. getDiamondProductsController correctly returned diamond/stone products and excluded plain items.`);

    // 3. Test createDiamondPriceSettingController (Create initial range 0.0 - 10.0)
    const createReq1 = {
      tenant,
      body: {
        companyid: "COMP_DIA_1",
        branchid: "BR_DIA_1",
        productid: prodDiaId,
        subproductid: subId,
        accode: "DIA_DLR_01",
        from_cent: 0.0,
        to_cent: 10.0,
        cent_rate: 1500.0,
      },
    };
    const createRes1 = mockRes();
    await createDiamondPriceSettingController(createReq1, createRes1);
    const res1 = createRes1._getData();
    if (res1.statusCode !== 201 || !res1.data.success) {
      throw new Error(`Failed to create first diamond price setting: ${JSON.stringify(res1.data)}`);
    }
    const createdId1 = res1.data.id;
    console.log(` 3. Created Diamond Price Setting 1 (ID: ${createdId1}) for range 0.0 - 10.0 @ ₹1500/cent.`);

    // 4. Test Overlap Rejection (try range 5.0 - 15.0)
    const overlapReq = {
      tenant,
      body: {
        companyid: "COMP_DIA_1",
        branchid: "BR_DIA_1",
        productid: prodDiaId,
        subproductid: subId,
        accode: "DIA_DLR_01",
        from_cent: 5.0,
        to_cent: 15.0,
        cent_rate: 1800.0,
      },
    };
    const overlapRes = mockRes();
    await createDiamondPriceSettingController(overlapReq, overlapRes);
    const overRes = overlapRes._getData();
    if (overRes.statusCode !== 400 || overRes.data.success) {
      throw new Error("Overlap detection failed: Overlapping range was incorrectly permitted.");
    }
    console.log(` 4. Overlap detection successfully blocked conflicting range (5.0 - 15.0).`);

    // 5. Test Continuous Range (10.001 - 20.0)
    const createReq2 = {
      tenant,
      body: {
        companyid: "COMP_DIA_1",
        branchid: "BR_DIA_1",
        productid: prodDiaId,
        subproductid: subId,
        accode: "DIA_DLR_01",
        from_cent: 10.001,
        to_cent: 20.0,
        cent_rate: 2200.0,
      },
    };
    const createRes2 = mockRes();
    await createDiamondPriceSettingController(createReq2, createRes2);
    const res2 = createRes2._getData();
    if (res2.statusCode !== 201 || !res2.data.success) {
      throw new Error(`Failed to create second continuous range: ${JSON.stringify(res2.data)}`);
    }
    const createdId2 = res2.data.id;
    console.log(` 5. Created continuous Diamond Price Setting 2 (ID: ${createdId2}) for range 10.001 - 20.0 @ ₹2200/cent.`);

    // 6. Test getDiamondPriceSettingsController with company isolation
    const getReq = {
      tenant,
      query: { companyid: "COMP_DIA_1" },
    };
    const getRes = mockRes();
    await getDiamondPriceSettingsController(getReq, getRes);
    const listData = getRes._getData().data;
    if (!listData.success || listData.diamond_price_settings.length < 2) {
      throw new Error(`getDiamondPriceSettingsController failed to return created settings for COMP_DIA_1.`);
    }
    const found1 = listData.diamond_price_settings.find((s) => s.id === createdId1);
    const found2 = listData.diamond_price_settings.find((s) => s.id === createdId2);
    if (!found1 || !found2) {
      throw new Error("Joined diamond price setting records missing expected properties.");
    }
    if (found1.productname !== "DIA_PROD_DIAMOND_RING" || found1.dealername !== "Solitaire Diamond Suppliers") {
      throw new Error("Joined product or dealer names do not match expected values.");
    }
    console.log(` 6. getDiamondPriceSettingsController successfully retrieved scoped records with joined names.`);

    // 7. Test getDiamondPriceSettingsController for different company (should return 0)
    const getOtherReq = {
      tenant,
      query: { companyid: "COMP_OTHER_99" },
    };
    const getOtherRes = mockRes();
    await getDiamondPriceSettingsController(getOtherReq, getOtherRes);
    const otherData = getOtherRes._getData().data;
    const foundOther = otherData.diamond_price_settings.filter((s) => s.id === createdId1 || s.id === createdId2);
    if (foundOther.length > 0) {
      throw new Error("Company isolation failed: records from COMP_DIA_1 leaked into COMP_OTHER_99.");
    }
    console.log(` 7. Company isolation verified: Records from COMP_DIA_1 are not visible to other companies.`);

    // 8. Test updateDiamondPriceSettingController
    const updateReq = {
      tenant,
      params: { id: createdId2 },
      body: {
        companyid: "COMP_DIA_1",
        branchid: "BR_DIA_1",
        productid: prodDiaId,
        subproductid: subId,
        accode: "DIA_DLR_01",
        from_cent: 10.001,
        to_cent: 25.0,
        cent_rate: 2500.0,
      },
    };
    const updateRes = mockRes();
    await updateDiamondPriceSettingController(updateReq, updateRes);
    const uData = updateRes._getData();
    if (!uData.data.success) {
      throw new Error(`Failed to update diamond price setting: ${JSON.stringify(uData.data)}`);
    }
    console.log(` 8. Successfully updated Diamond Price Setting 2 range to 10.001 - 25.0 @ ₹2500/cent.`);

    // 9. Clean up test records
    await deleteDiamondPriceSettingController({ tenant, params: { id: createdId1 } }, mockRes());
    await deleteDiamondPriceSettingController({ tenant, params: { id: createdId2 } }, mockRes());
    console.log(` 9. Test records cleaned up successfully.`);

    console.log("\n ALL DIAMOND PRICE SETTING TESTS PASSED PERFECTLY! \n");
  } catch (err) {
    console.error("Test failed with error:", err);
    process.exit(1);
  }
}

runDiamondPriceSettingTests();
