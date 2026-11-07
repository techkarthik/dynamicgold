import { createTenantClient } from "../config/turso.js";
import {
  getAccountHeadsController,
  getAccountHeadOptionsController,
  createAccountHeadOptionController,
  createAccountHeadController,
  updateAccountHeadController,
  deleteAccountHeadController,
} from "../controllers/accountHeadController.js";

async function runTest() {
  console.log("=== Starting Account Head Master Backend Test ===");

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
    // 1. Create a custom option
    console.log("\n[1] Creating a custom account type option 'TEST_TYPE'...");
    fakeReq.body = { option_type: "ACCOUNT_TYPE", option_value: "TEST_TYPE" };
    let res = createMockRes();
    await createAccountHeadOptionController(fakeReq, res);
    console.log("Response:", res.jsonResult);

    // 2. Create an Account Head with CASH type
    console.log("\n[2] Creating an Account Head with CASH type...");
    fakeReq.body = {
      accountname: "Main Cash Drawer",
      accounttype: "CASH",
      groupname: "Current Assets",
      state: "Tamil Nadu",
      country: "India",
      pincode: "600001",
    };
    res = createMockRes();
    await createAccountHeadController(fakeReq, res);
    console.log("Response:", res.jsonResult);
    const createdId = res.jsonResult?.accountHead?.id;
    if (!createdId) throw new Error("Account Head creation failed");

    // 3. Create an Account Head with SMITH type
    console.log("\n[3] Creating an Account Head with SMITH type...");
    fakeReq.body = {
      accountname: "Ramesh Goldsmith",
      accounttype: "SMITH",
      groupname: "Sundry Creditors",
      state: "Tamil Nadu",
      country: "India",
    };
    res = createMockRes();
    await createAccountHeadController(fakeReq, res);
    console.log("Response:", res.jsonResult);
    const smithId = res.jsonResult?.accountHead?.id;

    // 4. Fetch all Account Heads & Options
    console.log("\n[4] Fetching all Account Heads & custom options...");
    fakeReq.body = {};
    res = createMockRes();
    await getAccountHeadsController(fakeReq, res);
    console.log("Account Heads count:", res.jsonResult?.accountHeads?.length);
    console.log("Custom Account Types:", res.jsonResult?.customAccountTypes);
    console.log("Custom Financial Groups:", res.jsonResult?.customFinancialGroups);

    // 5. Update Account Head
    console.log(`\n[5] Updating Account Head ID ${createdId} to BANK type...`);
    fakeReq.params = { id: createdId };
    fakeReq.body = {
      accountname: "Main Petty Cash / Bank Drawer",
      accounttype: "BANK",
    };
    res = createMockRes();
    await updateAccountHeadController(fakeReq, res);
    console.log("Response:", res.jsonResult);

    // 6. Cleanup / Delete test records
    console.log(`\n[6] Cleaning up test Account Heads (IDs: ${createdId}, ${smithId})...`);
    fakeReq.params = { id: createdId };
    res = createMockRes();
    await deleteAccountHeadController(fakeReq, res);
    console.log("Delete 1 Response:", res.jsonResult);

    if (smithId) {
      fakeReq.params = { id: smithId };
      res = createMockRes();
      await deleteAccountHeadController(fakeReq, res);
      console.log("Delete 2 Response:", res.jsonResult);
    }

    console.log("\n ALL ACCOUNT HEAD TESTS PASSED SUCCESSFULLY! ");
  } catch (err) {
    console.error("\n❌ Account Head test failed:", err);
    process.exit(1);
  }
}

runTest();
