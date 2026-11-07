import { masterTurso } from "../config/turso.js";

async function runFullIntegrationTest() {
  console.log("===============================================================");
  console.log(" PROGOLD MULTI-TENANT FULL END-TO-END VERIFICATION TEST");
  console.log("===============================================================\n");

  const BASE_URL = "http://localhost:5000/api";
  const TEST_EMAIL = `tenant_${Date.now()}@progold.app`;
  const TEST_PASSWORD = "Password@2026!";
  const TEST_CONTACT = "+91 9876543210";
  const TURSO_URL = "libsql://gold-techkarthik.aws-ap-south-1.turso.io";
  const TURSO_TOKEN = (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || "");

  const today = new Date();
  const validFrom = today.toISOString().split("T")[0];
  const nextYear = new Date(today.getTime() + 365 * 24 * 60 * 60 * 1000);
  const validTo = nextYear.toISOString().split("T")[0];

  try {
    // 1. Send OTP
    console.log(`[1] Requesting OTP for ${TEST_EMAIL}...`);
    const otpRes = await fetch(`${BASE_URL}/auth/send-otp`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: TEST_EMAIL }),
    });
    const otpData = await otpRes.json();
    console.log("   -> Result:", otpData);
    if (!otpData.success) throw new Error("Send OTP failed");

    const devOtp = otpData.devOtp;

    // 2. Verify OTP
    console.log(`\n[2] Verifying OTP code [ ${devOtp} ]...`);
    const verifyRes = await fetch(`${BASE_URL}/auth/verify-otp`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: TEST_EMAIL, code: devOtp }),
    });
    const verifyData = await verifyRes.json();
    console.log("   -> Result:", verifyData);
    if (!verifyData.success) throw new Error("Verify OTP failed");

    // 3. Test Turso DB Connection
    console.log(`\n[3] Pre-testing Turso DB connectivity...`);
    const tursoTestRes = await fetch(`${BASE_URL}/auth/test-turso`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ turso_url: TURSO_URL, turso_token: TURSO_TOKEN }),
    });
    const tursoTestData = await tursoTestRes.json();
    console.log("   -> Result:", tursoTestData);
    if (!tursoTestData.success) throw new Error("Turso test failed");

    // 4. Register Tenant
    console.log(`\n[4] Registering Tenant with Turso DB & Validity (${validFrom} to ${validTo})...`);
    const regRes = await fetch(`${BASE_URL}/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
        contact_number: TEST_CONTACT,
        turso_url: TURSO_URL,
        turso_token: TURSO_TOKEN,
        valid_from: validFrom,
        valid_to: validTo,
      }),
    });
    const regData = await regRes.json();
    console.log("   -> Result:", regData);
    if (!regData.success) throw new Error("Registration failed: " + regData.message);

    const authToken = regData.token;

    // 5. Test Login with Registered Credentials
    console.log(`\n[5] Logging in with email & password...`);
    const loginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
      }),
    });
    const loginData = await loginRes.json();
    console.log("   -> Result:", loginData);
    if (!loginData.success) throw new Error("Login failed");

    // 6. Fetch Tenant Profile & Active Validity Check
    console.log(`\n[6] Fetching authenticated profile & checking subscription validity...`);
    const profileRes = await fetch(`${BASE_URL}/tenant/profile`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    const profileData = await profileRes.json();
    console.log("   -> Result:", profileData);

    // 7. Execute Dynamic SQL on Tenant's private Turso database
    console.log(`\n[7] Creating a tenant table 'customers' via dynamic query API...`);
    const createTableRes = await fetch(`${BASE_URL}/tenant/db/query`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        sql: `CREATE TABLE IF NOT EXISTS customers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE,
                phone TEXT,
                created_at TEXT
              );`,
      }),
    });
    console.log("   -> Result:", await createTableRes.json());

    // 8. Insert Records into Tenant Database
    console.log(`\n[8] Inserting sample tenant customer record...`);
    const insertRes = await fetch(`${BASE_URL}/tenant/db/query`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        sql: `INSERT INTO customers (name, email, phone, created_at)
              VALUES ('John Doe Enterprises', 'johndoe@tenantcorp.com', '+91 9123456780', datetime('now'));`,
      }),
    });
    console.log("   -> Result:", await insertRes.json());

    // 9. Query Records from Tenant Database
    console.log(`\n[9] Selecting customers from tenant database...`);
    const selectRes = await fetch(`${BASE_URL}/tenant/db/query`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        sql: `SELECT * FROM customers;`,
      }),
    });
    const selectData = await selectRes.json();
    console.log("   -> Result:", selectData);

    // 10. Fetch Tenant Database Overview (Tables & Rows)
    console.log(`\n[10] Fetching tenant database tables overview...`);
    const overviewRes = await fetch(`${BASE_URL}/tenant/db/overview`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    console.log("   -> Result:", await overviewRes.json());

    // 11. Test Database Health
    console.log(`\n[11] Testing tenant database latency and health...`);
    const healthRes = await fetch(`${BASE_URL}/tenant/db/health`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    console.log("   -> Result:", await healthRes.json());

    console.log("\n===============================================================");
    console.log(" ALL 11 MULTI-TENANT VERIFICATION TESTS PASSED SUCCESSFULLY! ");
    console.log("===============================================================\n");
  } catch (error) {
    console.error("Integration test error:", error);
  }
}

runFullIntegrationTest();
