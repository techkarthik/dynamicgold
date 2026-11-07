import { createTenantClient } from "../config/turso.js";
import {
  createCompanyController,
  getCompaniesController,
  deleteCompanyController,
} from "../controllers/companyController.js";
import {
  createBranchController,
  getBranchesController,
  deleteBranchController,
} from "../controllers/branchController.js";

async function runTest() {
  console.log("=== Testing Multi-Company Branch Isolation ===");

  const TURSO_URL = "libsql://gold-techkarthik.aws-ap-south-1.turso.io";
  const TURSO_TOKEN = (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || "");

  const fakeReq = {
    tenant: {
      turso_url: TURSO_URL,
      turso_token: TURSO_TOKEN,
    },
    body: {},
    params: {},
    query: {},
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

  const COMP_A = "CMPA1";
  const COMP_B = "CMPB1";
  const BR_A1 = "BRA01";
  const BR_A2 = "BRA02";
  const BR_B1 = "BRB01";

  try {
    // 1. Create Company A & Company B
    console.log("\n[1] Creating test companies CMPA1 and CMPB1...");
    let reqA = { ...fakeReq, body: { companyid: COMP_A, companyname: "Company Alpha Jewellers", city: "Chennai", state: "Tamil Nadu", mobilenumber: "9876543210" } };
    let resA = createMockRes();
    await createCompanyController(reqA, resA);
    console.log("Created Company A:", resA.jsonResult.success, resA.jsonResult.company?.companyname);

    let reqB = { ...fakeReq, body: { companyid: COMP_B, companyname: "Company Beta Bullion", city: "Mumbai", state: "Maharashtra", mobilenumber: "9123456780" } };
    let resB = createMockRes();
    await createCompanyController(reqB, resB);
    console.log("Created Company B:", resB.jsonResult.success, resB.jsonResult.company?.companyname);

    // 2. Create Branches under Company A and Company B
    console.log("\n[2] Creating branches under Company A (BRA01, BRA02) and Company B (BRB01)...");
    let reqBrA1 = { ...fakeReq, body: { branchid: BR_A1, branchname: "Alpha T-Nagar", companyid: COMP_A, mobile: "9876500001" } };
    let resBrA1 = createMockRes();
    await createBranchController(reqBrA1, resBrA1);

    let reqBrA2 = { ...fakeReq, body: { branchid: BR_A2, branchname: "Alpha Anna Nagar", companyid: COMP_A, mobile: "9876500002" } };
    let resBrA2 = createMockRes();
    await createBranchController(reqBrA2, resBrA2);

    let reqBrB1 = { ...fakeReq, body: { branchid: BR_B1, branchname: "Beta Zaveri Bazar", companyid: COMP_B, mobile: "9123400001" } };
    let resBrB1 = createMockRes();
    await createBranchController(reqBrB1, resBrB1);
    console.log("Branches created successfully.");

    // 3. Query All Branches (No filter)
    console.log("\n[3] Querying all branches (no filter)...");
    let reqAll = { ...fakeReq, query: {} };
    let resAll = createMockRes();
    await getBranchesController(reqAll, resAll);
    const allBranches = resAll.jsonResult.branches || [];
    console.log(`Found total ${allBranches.length} branches across all companies.`);

    // 4. Query Branches filtered by Company A
    console.log("\n[4] Querying branches filtered by companyid = CMPA1...");
    let reqFilterA = { ...fakeReq, query: { companyid: COMP_A } };
    let resFilterA = createMockRes();
    await getBranchesController(reqFilterA, resFilterA);
    const branchesA = resFilterA.jsonResult.branches || [];
    console.log(`Company A branches count: ${branchesA.length}`);
    const branchIdsA = branchesA.map(b => b.branchid);
    if (!branchIdsA.includes(BR_A1) || !branchIdsA.includes(BR_A2) || branchIdsA.includes(BR_B1)) {
      throw new Error(`Company A branch filter failed! Returned: ${JSON.stringify(branchIdsA)}`);
    }
    console.log("✅ Company A branch isolation verified (only BRA01 and BRA02 returned).");

    // 5. Query Branches filtered by Company B
    console.log("\n[5] Querying branches filtered by companyid = CMPB1...");
    let reqFilterB = { ...fakeReq, query: { companyid: COMP_B } };
    let resFilterB = createMockRes();
    await getBranchesController(reqFilterB, resFilterB);
    const branchesB = resFilterB.jsonResult.branches || [];
    console.log(`Company B branches count: ${branchesB.length}`);
    const branchIdsB = branchesB.map(b => b.branchid);
    if (!branchIdsB.includes(BR_B1) || branchIdsB.includes(BR_A1) || branchIdsB.includes(BR_A2)) {
      throw new Error(`Company B branch filter failed! Returned: ${JSON.stringify(branchIdsB)}`);
    }
    console.log("✅ Company B branch isolation verified (only BRB01 returned).");

    // 6. Cleanup
    console.log("\n[6] Cleaning up test records...");
    await deleteBranchController({ ...fakeReq, params: { id: BR_A1 } }, createMockRes());
    await deleteBranchController({ ...fakeReq, params: { id: BR_A2 } }, createMockRes());
    await deleteBranchController({ ...fakeReq, params: { id: BR_B1 } }, createMockRes());
    await deleteCompanyController({ ...fakeReq, params: { id: COMP_A } }, createMockRes());
    await deleteCompanyController({ ...fakeReq, params: { id: COMP_B } }, createMockRes());
    console.log("Cleanup complete.");

    console.log("\n✨ ALL MULTI-COMPANY BRANCH ISOLATION TESTS PASSED PERFECTLY!");
  } catch (err) {
    console.error("❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
