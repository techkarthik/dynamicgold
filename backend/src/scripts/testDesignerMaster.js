import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getDesignersController,
  createDesignerController,
  updateDesignerController,
  deleteDesignerController,
} from "../controllers/inventoryMasterController.js";

async function runDesignerMasterTests() {
  console.log("=== STARTING DESIGNER MASTER AUTOMATED TESTS ===");

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

    // 1. Ensure test Smith & Dealer exist in account_heads
    await client.execute({
      sql: `INSERT OR REPLACE INTO account_heads (accode, groupname, accountname, accounttype, active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);`,
      args: ["DSGN_SMT_01", "KARIGAR / SMITH", "Master Artisan Ramesh", "SMITH", now, now],
    });
    await client.execute({
      sql: `INSERT OR REPLACE INTO account_heads (accode, groupname, accountname, accounttype, active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);`,
      args: ["DSGN_DLR_01", "SUNDRY CREDITORS", "Couture Design Studio", "DEALER", now, now],
    });
    await client.execute({
      sql: `INSERT OR REPLACE INTO account_heads (accode, groupname, accountname, accounttype, active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?);`,
      args: ["DSGN_CUS_01", "SUNDRY DEBTORS", "Retail Customer Sample", "CUSTOMER", now, now],
    });
    console.log(" 1. Seed accounts (SMITH, DEALER, CUSTOMER) initialized.");

    // 2. Reject invalid account type (e.g. CUSTOMER)
    const badAccReq = {
      tenant,
      body: {
        accode: "DSGN_CUS_01",
        designername: "Invalid Customer Designer",
        designershortname: "ICD",
      },
    };
    const badAccRes = mockRes();
    await createDesignerController(badAccReq, badAccRes);
    const bRes = badAccRes._getData();
    if (bRes.statusCode !== 400 || bRes.data.success) {
      throw new Error("Validation failed: CUSTOMER account was incorrectly allowed as Designer!");
    }
    console.log(" 2. Invalid account type (CUSTOMER) correctly blocked.");

    // 3. Create valid Designer linked to SMITH
    const createReq1 = {
      tenant,
      body: {
        accode: "DSGN_SMT_01",
        designername: "Artisan Heritage Collection",
        designershortname: "AHC",
      },
    };
    const createRes1 = mockRes();
    await createDesignerController(createReq1, createRes1);
    const res1 = createRes1._getData();
    if (res1.statusCode !== 201 || !res1.data.success) {
      throw new Error(`Failed to create first designer: ${JSON.stringify(res1.data)}`);
    }
    const createdId1 = res1.data.designerid;
    console.log(` 3. Created Designer 1 (ID: ${createdId1}) linked to Smith 'DSGN_SMT_01'.`);

    // 4. Test duplicate designer name rejection
    const dupReq = {
      tenant,
      body: {
        accode: "DSGN_DLR_01",
        designername: "artisan heritage collection", // case insensitive duplicate
        designershortname: "AHC2",
      },
    };
    const dupRes = mockRes();
    await createDesignerController(dupReq, dupRes);
    const dRes = dupRes._getData();
    if (dRes.statusCode !== 400 || dRes.data.success) {
      throw new Error("Duplicate designer name check failed: duplicate was allowed!");
    }
    console.log(" 4. Duplicate Designer Name (case-insensitive) correctly rejected.");

    // 5. Create second Designer linked to DEALER
    const createReq2 = {
      tenant,
      body: {
        accode: "DSGN_DLR_01",
        designername: "Bridal Couture Line",
        designershortname: "BCL",
      },
    };
    const createRes2 = mockRes();
    await createDesignerController(createReq2, createRes2);
    const res2 = createRes2._getData();
    if (res2.statusCode !== 201 || !res2.data.success) {
      throw new Error(`Failed to create second designer: ${JSON.stringify(res2.data)}`);
    }
    const createdId2 = res2.data.designerid;
    console.log(` 5. Created Designer 2 (ID: ${createdId2}) linked to Dealer 'DSGN_DLR_01'.`);

    // 6. Test getDesignersController (retrieve list with joined account names)
    const getReq = { tenant };
    const getRes = mockRes();
    await getDesignersController(getReq, getRes);
    const listData = getRes._getData().data;
    if (!listData.success || !Array.isArray(listData.designers)) {
      throw new Error("getDesignersController failed.");
    }
    const found1 = listData.designers.find((d) => d.designerid === createdId1);
    const found2 = listData.designers.find((d) => d.designerid === createdId2);
    if (!found1 || !found2) {
      throw new Error("Created designers not found in list output.");
    }
    if (found1.accountname !== "Master Artisan Ramesh" || found1.accounttype !== "SMITH") {
      throw new Error(`Joined account details mismatch on Designer 1: ${JSON.stringify(found1)}`);
    }
    if (found2.accountname !== "Couture Design Studio" || found2.accounttype !== "DEALER") {
      throw new Error(`Joined account details mismatch on Designer 2: ${JSON.stringify(found2)}`);
    }
    console.log(` 6. getDesignersController returned records with correctly joined accountname and accounttype.`);

    // 7. Test updateDesignerController
    const updateReq = {
      tenant,
      params: { id: createdId2 },
      body: {
        accode: "DSGN_DLR_01",
        designername: "Royal Bridal Couture Line",
        designershortname: "RBCL",
      },
    };
    const updateRes = mockRes();
    await updateDesignerController(updateReq, updateRes);
    const uData = updateRes._getData().data;
    if (!uData.success) {
      throw new Error(`Failed to update designer: ${JSON.stringify(uData)}`);
    }
    console.log(` 7. Successfully updated Designer 2 name to 'Royal Bridal Couture Line'.`);

    // 8. Test deleteDesignerController
    await deleteDesignerController({ tenant, params: { id: createdId1 } }, mockRes());
    await deleteDesignerController({ tenant, params: { id: createdId2 } }, mockRes());
    console.log(` 8. Cleaned up test designer records.`);

    console.log("\n ALL DESIGNER MASTER TESTS PASSED PERFECTLY! \n");
  } catch (err) {
    console.error("Test failed with error:", err);
    process.exit(1);
  }
}

runDesignerMasterTests();
