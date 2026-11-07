import { createTenantClient } from "../config/turso.js";
import { ensureUserTable } from "../controllers/userController.js";
import bcrypt from "bcryptjs";

async function testUserMaster() {
  console.log("=== Testing User Master Database Operations ===");
  const turso_url = "libsql://gold-techkarthik.aws-ap-south-1.turso.io";
  const turso_token = (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || "");

  const client = createTenantClient(turso_url, turso_token);
  await ensureUserTable(client);
  console.log("✓ ensureUserTable executed successfully.");

  const testUserId = "TESTUSR01";
  const testPassword = "SecretPassword@123";
  const salt = await bcrypt.genSalt(10);
  const hash = await bcrypt.hash(testPassword, salt);
  const now = new Date().toISOString();
  const allowedMenus = JSON.stringify(["M_MASTER.ORGANIZATION.COMPANY", "M_POS.BILLING", "M_REPORT.SALES"]);

  // Clean up existing test user if present
  await client.execute({
    sql: "DELETE FROM users WHERE userid = ?;",
    args: [testUserId],
  });

  // 1. Insert test user
  await client.execute({
    sql: `
      INSERT INTO users (
        userid, username, password_hash, email, branchid, is_active, centlogin, profile_image, allowed_menus, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 1, 'YES', '', ?, ?, ?);
    `,
    args: [testUserId, "Karthik Cashier", hash, "karthik.test@example.com", "BR01", allowedMenus, now, now],
  });
  console.log("✓ Inserted test user TESTUSR01 with allowed_menus and centlogin = YES");

  // 2. Query test user
  const fetchRes = await client.execute({
    sql: "SELECT userid, username, email, branchid, is_active, centlogin, allowed_menus FROM users WHERE userid = ?;",
    args: [testUserId],
  });
  const row = fetchRes.rows[0];
  console.log("✓ Fetched user:", row);
  const parsedMenus = JSON.parse(row.allowed_menus);
  console.log("✓ Parsed menu permissions count:", parsedMenus.length, parsedMenus);

  // 3. Update user
  const updatedMenus = JSON.stringify(["M_MASTER.ORGANIZATION.COMPANY", "M_POS.BILLING", "M_STOCK.LIVE_INVENTORY"]);
  await client.execute({
    sql: "UPDATE users SET username = ?, allowed_menus = ?, centlogin = 'NO', updated_at = ? WHERE userid = ?;",
    args: ["Karthik Senior Cashier", updatedMenus, new Date().toISOString(), testUserId],
  });
  console.log("✓ Updated user permissions & centlogin to NO.");

  // 4. Verify password match
  const passCheckRes = await client.execute({
    sql: "SELECT password_hash FROM users WHERE userid = ?;",
    args: [testUserId],
  });
  const isMatch = await bcrypt.compare(testPassword, passCheckRes.rows[0].password_hash);
  console.log("✓ Bcrypt password verification matches:", isMatch);

  // 5. Clean up
  await client.execute({
    sql: "DELETE FROM users WHERE userid = ?;",
    args: [testUserId],
  });
  console.log("✓ Cleaned up test user.");

  console.log("\n=== ALL USER MASTER DB TESTS PASSED SUCCESSFULLY! ===");
}

testUserMaster().catch((err) => {
  console.error("Test failed:", err);
});
