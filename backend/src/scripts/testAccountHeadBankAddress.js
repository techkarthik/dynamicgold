import {
  getAccountHeadsController,
  createAccountHeadController,
  updateAccountHeadController,
  deleteAccountHeadController,
} from "../controllers/accountHeadController.js";

async function runTest() {
  console.log("=== Testing Account Head Multiple Bank Accounts & Address Fields ===");

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
    // 1. Create an Account Head with 2 bank accounts and full address
    console.log("\n[1] Creating Account Head with 2 Bank Accounts & Complete Address...");
    fakeReq.body = {
      accountname: "Sri Meenakshi Bullion Dealer",
      accounttype: "DEALER",
      groupname: "Sundry Creditors",
      address_line1: "123 Bullion Street, 2nd Floor",
      address_line2: "Opposite Town Hall",
      city: "Madurai",
      state: "Tamil Nadu",
      country: "India",
      pincode: "625001",
      phone_no: "9876543210",
      email: "accounts@meenakshibullion.com",
      gstno: "33ABCDE1234F1Z5",
      panno: "ABCDE1234F",
      bank_details: [
        {
          bank_name: "HDFC Bank",
          account_number: "50200099887766",
          ifsc_code: "HDFC0000123",
          branch_name: "Madurai Main Branch",
          account_holder_name: "Sri Meenakshi Bullion",
        },
        {
          bank_name: "State Bank of India",
          account_number: "3001122334455",
          ifsc_code: "SBIN0001234",
          branch_name: "West Tower Street",
          account_holder_name: "Sri Meenakshi Bullion",
        },
      ],
    };

    let res = createMockRes();
    await createAccountHeadController(fakeReq, res);
    console.log("Create Response status:", res.statusCode);
    console.log("Created Account Head:", res.jsonResult?.accountHead);

    const createdId = res.jsonResult?.accountHead?.id;
    if (!createdId) throw new Error("Account Head creation failed");

    // 2. Fetch and verify
    console.log("\n[2] Fetching account heads and verifying bank accounts & address fields...");
    fakeReq.body = {};
    res = createMockRes();
    await getAccountHeadsController(fakeReq, res);
    const found = res.jsonResult?.accountHeads?.find((h) => h.id === createdId);
    console.log("Fetched record:", found);

    if (!found) throw new Error("Created record not found in fetch list");
    if (!Array.isArray(found.bank_details) || found.bank_details.length !== 2) {
      throw new Error(`Expected 2 bank accounts, found ${found.bank_details?.length}`);
    }
    if (found.city !== "Madurai" || found.address_line1 !== "123 Bullion Street, 2nd Floor") {
      throw new Error("Address fields do not match");
    }
    console.log("✓ Verification of multiple bank accounts & address fields passed!");

    // 3. Update with 3rd bank account and modified city
    console.log("\n[3] Updating Account Head (adding a 3rd bank account)...");
    fakeReq.params = { id: createdId };
    fakeReq.body = {
      city: "Madurai Central",
      bank_details: [
        ...found.bank_details,
        {
          bank_name: "ICICI Bank",
          account_number: "001122334455",
          ifsc_code: "ICIC0000011",
          branch_name: "KK Nagar Branch",
        },
      ],
    };
    res = createMockRes();
    await updateAccountHeadController(fakeReq, res);
    console.log("Update response:", res.jsonResult);

    // 4. Verify updated record
    res = createMockRes();
    await getAccountHeadsController(fakeReq, res);
    const updated = res.jsonResult?.accountHeads?.find((h) => h.id === createdId);
    console.log("Updated record bank count:", updated?.bank_details?.length, "City:", updated?.city);
    if (updated?.bank_details?.length !== 3) {
      throw new Error("Expected 3 bank accounts after update");
    }

    // 5. Cleanup
    console.log(`\n[5] Cleaning up test Account Head (ID: ${createdId})...`);
    fakeReq.params = { id: createdId };
    res = createMockRes();
    await deleteAccountHeadController(fakeReq, res);
    console.log("Delete response:", res.jsonResult);

    console.log("\n ALL MULTIPLE BANK ACCOUNTS & ADDRESS TESTS PASSED 100%! ");
  } catch (err) {
    console.error("\n❌ Test failed:", err);
    process.exit(1);
  }
}

runTest();
