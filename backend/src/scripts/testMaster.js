import { masterTurso } from "../config/turso.js";
import { initMasterSchema } from "../config/schema.js";

async function runTest() {
  console.log("Testing Master Turso DB connection...");
  try {
    const ping = await masterTurso.execute("SELECT 1 AS ping, datetime('now') AS currentTime;");
    console.log(" Ping successful! Result:", ping.rows[0]);

    await initMasterSchema();

    const tables = await masterTurso.execute("SELECT name FROM sqlite_master WHERE type='table';");
    console.log(" Existing tables in Master Turso DB:", tables.rows.map(r => r.name));
    console.log(" Master Turso connection test passed 100%!");
  } catch (err) {
    console.error(" Master Turso test failed:", err);
  }
}

runTest();
