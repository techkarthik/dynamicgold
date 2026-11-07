import { masterTurso, createTenantClient } from "../config/turso.js";

async function main() {
  const tenants = await masterTurso.execute(
    "SELECT email, turso_url, turso_token FROM tenants WHERE email IN ('techkarthikmahalingam@gmail.com', 'onlyintamil@gmail.com')"
  );

  for (const t of tenants.rows) {
    console.log("\n================ Tenant:", t.email);
    const client = createTenantClient(t.turso_url, t.turso_token);
    try {
      const res = await client.execute("SELECT item_id, sku_code, productid, purityid, gross_weight, net_weight, status FROM stock_tagged_items");
      console.log("Total rows:", res.rows.length);
      console.table(res.rows);

      // Test the exact lookup query used in estimateController
      const testSku = "sku-2627-6-001";
      console.log(`\nTesting lookup for SKU: '${testSku}'`);
      const tagResult = await client.execute({
        sql: `
          SELECT 
            t.*,
            p.productname,
            p.hsncode,
            p.categoryid,
            c.catname,
            c.categorytype,
            c.sgst_per,
            c.cgst_per,
            c.igst_per,
            pu.purityname,
            pu.purityshortname,
            pu.purity,
            pu.metalid,
            d.designername,
            d.designershortname,
            COALESCE(dr.rate, 0.0) AS live_board_rate
          FROM stock_tagged_items t
          LEFT JOIN products p ON t.productid = p.productid
          LEFT JOIN categories c ON p.categoryid = c.id
          LEFT JOIN purities pu ON t.purityid = pu.purityid
          LEFT JOIN designers d ON t.designerid = d.designerid
          LEFT JOIN (
            SELECT dr1.purityid, dr1.rate
            FROM daily_rates dr1
            WHERE dr1.id = (
              SELECT MAX(dr2.id) FROM daily_rates dr2 WHERE dr2.purityid = dr1.purityid
            )
          ) dr ON t.purityid = dr.purityid
          WHERE UPPER(TRIM(t.sku_code)) = UPPER(?)
          LIMIT 1;
        `,
        args: [testSku.trim()],
      });

      if (tagResult.rows.length > 0) {
        console.log("Lookup SUCCESS! Found item:");
        console.log(tagResult.rows[0]);
      } else {
        console.log("Lookup FAILED: Item not found in query.");
      }
    } catch (e) {
      console.error("Error for tenant:", t.email, e);
    }
  }
}

main().catch(console.error);
