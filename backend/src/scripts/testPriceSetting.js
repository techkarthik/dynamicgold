import { masterTurso } from "../config/turso.js";
import { createTenantClient } from "../config/turso.js";

async function runTest() {
  console.log("=== STARTING PRICE SETTING MASTER AUTOMATED TESTS (WITH BRANCH LINKING) ===");

  try {
    // 1. Fetch demo tenant credentials
    const tenantRes = await masterTurso.execute(`SELECT * FROM tenants WHERE email = 'tenant_test@example.com' LIMIT 1;`);
    if (tenantRes.rows.length === 0) {
      console.error("Demo tenant not found!");
      process.exit(1);
    }
    const tenant = tenantRes.rows[0];
    const client = createTenantClient(tenant.turso_url, tenant.turso_token);

    // 2. Ensure tables exist
    await client.execute(`
      CREATE TABLE IF NOT EXISTS branches (
        branchid TEXT PRIMARY KEY NOT NULL,
        branchname TEXT NOT NULL,
        companyid TEXT NOT NULL,
        accountname TEXT DEFAULT '',
        state TEXT DEFAULT '',
        state_id INTEGER DEFAULT 0,
        country TEXT DEFAULT 'India',
        country_id INTEGER DEFAULT 1,
        address TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    await client.execute(`
      CREATE TABLE IF NOT EXISTS pricesetting (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branchid TEXT DEFAULT '',
        productid INTEGER NOT NULL,
        subproductid INTEGER DEFAULT NULL,
        accode TEXT NOT NULL,
        weight_from REAL NOT NULL DEFAULT 0.0,
        weight_to REAL NOT NULL DEFAULT 0.0,
        va_percent REAL NOT NULL DEFAULT 0.0,
        wastage REAL NOT NULL DEFAULT 0.0,
        mc_per_gram REAL NOT NULL DEFAULT 0.0,
        m_charge REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (productid) REFERENCES products(productid),
        FOREIGN KEY (subproductid) REFERENCES subproducts(subproductid)
      );
    `);

    try {
      await client.execute(`ALTER TABLE pricesetting ADD COLUMN branchid TEXT DEFAULT '';`);
    } catch (_) {}

    console.log(" 1. pricesetting and branches tables verified/migrated in Turso.");

    // Clean up previous test data
    await client.execute(`DELETE FROM pricesetting WHERE accode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM subproducts WHERE subproductname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM products WHERE productname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM categories WHERE catcode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM purities WHERE purityname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM metals WHERE metalid LIKE 'T%';`);
    await client.execute(`DELETE FROM account_heads WHERE accode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM branches WHERE branchid LIKE 'TEST_%';`);

    const now = new Date().toISOString();

    // 3. Setup test Branch
    await client.execute({
      sql: `INSERT OR IGNORE INTO branches (branchid, branchname, companyid, created_at, updated_at) VALUES ('TEST_BR_1', 'Test Branch Alpha', 'TEST_CO', ?, ?);`,
      args: [now, now],
    });

    // 4. Setup test Metal, Purity, Category, Products
    await client.execute({
      sql: `INSERT OR IGNORE INTO metals (metalid, metalname, created_at, updated_at) VALUES ('TM', 'Test Metal', ?, ?);`,
      args: [now, now],
    });

    const purRes = await client.execute({
      sql: `INSERT INTO purities (metalid, purityname, purityshortname, purity, type, created_at, updated_at) VALUES ('TM', 'Test Purity', 'TP', 91.6, 'ORNAMENT', ?, ?);`,
      args: [now, now],
    });
    const purityId = purRes.lastInsertRowid;

    const catRes = await client.execute({
      sql: `INSERT INTO categories (metalid, purityid, catcode, catname, categorytype, created_at, updated_at) VALUES ('TM', ?, 'TEST_CAT', 'Test Category', 'ORNAMENTS/STONE', ?, ?);`,
      args: [Number(purityId), now, now],
    });
    const catId = catRes.lastInsertRowid;

    const prod1Res = await client.execute({
      sql: `INSERT INTO products (categoryid, productname, havesubproduct, created_at, updated_at) VALUES (?, 'TEST_PROD_1', 'YES', ?, ?);`,
      args: [Number(catId), now, now],
    });
    const prod1Id = Number(prod1Res.lastInsertRowid);

    const prod2Res = await client.execute({
      sql: `INSERT INTO products (categoryid, productname, havesubproduct, created_at, updated_at) VALUES (?, 'TEST_PROD_2', 'NO', ?, ?);`,
      args: [Number(catId), now, now],
    });
    const prod2Id = Number(prod2Res.lastInsertRowid);

    const sub1Res = await client.execute({
      sql: `INSERT INTO subproducts (productid, subproductname, created_at, updated_at) VALUES (?, 'TEST_SUB_1', ?, ?);`,
      args: [prod1Id, now, now],
    });
    const sub1Id = Number(sub1Res.lastInsertRowid);

    // 5. Setup test Dealer and Smith account heads
    await client.execute({
      sql: `INSERT INTO account_heads (accode, groupname, accountname, accounttype, created_at, updated_at) VALUES ('TEST_DLR_1', 'SUNDRY CREDITORS', 'Test Dealer Alpha', 'DEALER', ?, ?);`,
      args: [now, now],
    });
    await client.execute({
      sql: `INSERT INTO account_heads (accode, groupname, accountname, accounttype, created_at, updated_at) VALUES ('TEST_SMT_1', 'KARIGAR / SMITH', 'Test Smith Beta', 'SMITH', ?, ?);`,
      args: [now, now],
    });
    await client.execute({
      sql: `INSERT INTO account_heads (accode, groupname, accountname, accounttype, created_at, updated_at) VALUES ('TEST_CUS_1', 'SUNDRY DEBTORS', 'Test Customer Gamma', 'CUSTOMER', ?, ?);`,
      args: [now, now],
    });
    console.log(" 2. Test master dependencies seeded successfully (Branch, Metal, Category, Products, Accounts).");

    // 6. Test Dealer filter (Only SMITH and DEALER)
    const dealersRes = await client.execute(`
      SELECT accode, accountname, accounttype 
      FROM account_heads 
      WHERE UPPER(TRIM(accounttype)) IN ('SMITH', 'DEALER') AND accode LIKE 'TEST_%';
    `);
    console.log(` 3. Dealer filter returned ${dealersRes.rows.length} rows (Expected 2, CUSTOMER excluded).`);
    if (dealersRes.rows.length !== 2) {
      throw new Error(`Dealer filter failed. Expected 2 accounts, got ${dealersRes.rows.length}`);
    }

    // 7. Insert first price setting with specific branch: Branch 'TEST_BR_1' + Prod1 + Sub1 + Dealer1 with range 0.000 - 10.000
    const ps1Res = await client.execute({
      sql: `
        INSERT INTO pricesetting (
          branchid, productid, subproductid, accode, weight_from, weight_to, va_percent, wastage, mc_per_gram, m_charge, created_at, updated_at
        ) VALUES ('TEST_BR_1', ?, ?, 'TEST_DLR_1', 0.0, 10.0, 12.5, 0.25, 450.0, 50.0, ?, ?);
      `,
      args: [prod1Id, sub1Id, now, now],
    });
    const ps1Id = Number(ps1Res.lastInsertRowid);
    console.log(` 4. Created Price Setting 1 (ID: ${ps1Id}) for Branch 'TEST_BR_1' with range 0.0 - 10.0.`);

    // 8. Insert Global / All Branches price setting for SAME Prod1 + Sub1 + Dealer1 (should be allowed because branch differs!)
    const psGlobalRes = await client.execute({
      sql: `
        INSERT INTO pricesetting (
          branchid, productid, subproductid, accode, weight_from, weight_to, va_percent, wastage, mc_per_gram, m_charge, created_at, updated_at
        ) VALUES ('', ?, ?, 'TEST_DLR_1', 0.0, 10.0, 15.0, 0.35, 500.0, 60.0, ?, ?);
      `,
      args: [prod1Id, sub1Id, now, now],
    });
    console.log(` 5. Created Global Price Setting (ID: ${psGlobalRes.lastInsertRowid}) with range 0.0 - 10.0 for SAME product/dealer (allowed due to branch scoping).`);

    // 9. Check Overlap Validation for SAME Branch 'TEST_BR_1' + Prod1 + Sub1 + Dealer1
    const overlapCheck = await client.execute({
      sql: `
        SELECT id, weight_from, weight_to 
        FROM pricesetting 
        WHERE UPPER(TRIM(COALESCE(branchid, ''))) = 'TEST_BR_1'
          AND productid = ? 
          AND subproductid = ? 
          AND accode = 'TEST_DLR_1' 
          AND weight_from < 15.0 
          AND weight_to > 5.0 
        LIMIT 1;
      `,
      args: [prod1Id, sub1Id],
    });
    if (overlapCheck.rows.length > 0) {
      console.log(` 6. Overlap detection correctly caught 5.0 - 15.0 on Branch 'TEST_BR_1' (conflicts with existing ${overlapCheck.rows[0].weight_from} - ${overlapCheck.rows[0].weight_to}).`);
    } else {
      throw new Error("Overlap detection FAILED to catch overlapping range 5.0 - 15.0 for Branch 'TEST_BR_1'!");
    }

    // 10. Insert next continuous range 10.001 - 20.000 for Branch 'TEST_BR_1'
    const ps2Res = await client.execute({
      sql: `
        INSERT INTO pricesetting (
          branchid, productid, subproductid, accode, weight_from, weight_to, va_percent, wastage, mc_per_gram, m_charge, created_at, updated_at
        ) VALUES ('TEST_BR_1', ?, ?, 'TEST_DLR_1', 10.001, 20.0, 10.0, 0.20, 400.0, 40.0, ?, ?);
      `,
      args: [prod1Id, sub1Id, now, now],
    });
    console.log(` 7. Successfully inserted continuous range 10.001 - 20.0 for Branch 'TEST_BR_1' (ID: ${ps2Res.lastInsertRowid}).`);

    // 11. Test JOIN query with Branches, Products, Subproducts, Account Heads
    const joinResult = await client.execute(`
      SELECT 
        ps.id,
        ps.branchid,
        COALESCE(b.branchname, '') AS branchname,
        ps.productid,
        COALESCE(p.productname, '') AS productname,
        ps.subproductid,
        COALESCE(sp.subproductname, '') AS subproductname,
        ps.accode,
        COALESCE(ah.accountname, '') AS dealername,
        COALESCE(ah.accounttype, '') AS accounttype,
        ps.weight_from,
        ps.weight_to,
        ps.va_percent,
        ps.wastage,
        ps.mc_per_gram,
        ps.m_charge
      FROM pricesetting ps
      LEFT JOIN branches b ON UPPER(TRIM(ps.branchid)) = UPPER(TRIM(b.branchid))
      LEFT JOIN products p ON ps.productid = p.productid
      LEFT JOIN subproducts sp ON ps.subproductid = sp.subproductid
      LEFT JOIN account_heads ah ON ps.accode = ah.accode
      WHERE ps.accode LIKE 'TEST_%'
      ORDER BY ps.branchid ASC, ps.id ASC;
    `);

    console.log(` 8. Join query successfully fetched ${joinResult.rows.length} rows with joined branch/product/dealer names:`);
    for (const r of joinResult.rows) {
      console.log(`    - ID ${r.id}: Branch '${r.branchid || 'GLOBAL'}' (${r.branchname || 'All Branches'}), Product '${r.productname}' (ID ${r.productid}), Sub '${r.subproductname || 'N/A'}', Dealer '${r.dealername}' (${r.accounttype} - ${r.accode}), Range: ${r.weight_from}g - ${r.weight_to}g, VA: ${r.va_percent}%, Wastage: ${r.wastage}g, MC/g: ₹${r.mc_per_gram}, Flat: ₹${r.m_charge}`);
    }

    // 12. Cleanup test records
    await client.execute(`DELETE FROM pricesetting WHERE accode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM subproducts WHERE subproductname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM products WHERE productname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM categories WHERE catcode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM purities WHERE purityname LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM metals WHERE metalid LIKE 'T%';`);
    await client.execute(`DELETE FROM account_heads WHERE accode LIKE 'TEST_%';`);
    await client.execute(`DELETE FROM branches WHERE branchid LIKE 'TEST_%';`);

    console.log(" 9. Cleaned up all test records.");
    console.log("\n ALL PRICE SETTING TESTS (WITH BRANCH LINKING) PASSED PERFECTLY! \n");
  } catch (err) {
    console.error("Test failed with error:", err);
    process.exit(1);
  }
}

runTest();
