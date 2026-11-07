import { createTenantClient } from "../config/postgres.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures the employees table exists in the tenant's PostgreSQL schema.
 */
async function ensureEmployeesTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`employees:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS employees (
        empid INTEGER PRIMARY KEY AUTOINCREMENT,
        empname TEXT NOT NULL,
        branchid TEXT NOT NULL,
        dateofjoin TEXT DEFAULT '',
        active INTEGER DEFAULT 1,
        bloodgroup TEXT DEFAULT '',
        mobile TEXT DEFAULT '',
        email TEXT DEFAULT '',
        address TEXT DEFAULT '',
        image TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe non-destructive column additions in case table was created with an older schema
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN dateofjoin TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN active INTEGER DEFAULT 1;`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN bloodgroup TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN mobile TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN email TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN address TEXT DEFAULT '';`);
    } catch (_) {}
    try {
      await client.execute(`ALTER TABLE employees ADD COLUMN image TEXT DEFAULT '';`);
    } catch (_) {}
  });
}

/**
 * GET /api/tenant/employees
 * Retrieves all employees joined with branch name, along with summary counts and next empid.
 */
export async function getEmployeesController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureEmployeesTable(client);

    // Fetch employees joined with branches
    const result = await client.execute(`
      SELECT 
        e.*,
        COALESCE(b.branchname, '') AS branchname
      FROM employees e
      LEFT JOIN branches b ON UPPER(TRIM(e.branchid)) = UPPER(TRIM(b.branchid))
      ORDER BY e.empid ASC;
    `);

    const employees = result.rows || [];

    // Calculate metadata
    let lastEmpId = 0;
    let activeCount = 0;
    for (const emp of employees) {
      const id = Number(emp.empid);
      if (!isNaN(id) && id > lastEmpId) {
        lastEmpId = id;
      }
      if (emp.active === 1 || emp.active === "1" || emp.active === true) {
        activeCount++;
      }
    }

    const nextEmpId = lastEmpId > 0 ? lastEmpId + 1 : 1001;

    return res.json({
      success: true,
      employees,
      last_empid: lastEmpId,
      next_empid: nextEmpId,
      total_count: employees.length,
      active_count: activeCount,
      inactive_count: employees.length - activeCount,
    });
  } catch (error) {
    console.error("getEmployeesController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch employees.",
    });
  }
}

/**
 * POST /api/tenant/employees
 * Creates a new employee record.
 */
export async function createEmployeeController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureEmployeesTable(client);

    const {
      empid,
      empname,
      branchid,
      dateofjoin = "",
      active = 1,
      bloodgroup = "",
      mobile = "",
      email = "",
      address = "",
      image = "",
    } = req.body;

    if (!empname || !empname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Employee name is required.",
      });
    }

    if (!branchid || !branchid.trim()) {
      return res.status(400).json({
        success: false,
        message: "Branch assignment is required.",
      });
    }

    const now = new Date().toISOString();
    const cleanActive = active === 0 || active === false || active === "0" ? 0 : 1;
    const cleanBloodGroup = (bloodgroup || "").trim().toUpperCase();
    const cleanBranchId = branchid.trim().toUpperCase();
    const cleanMobile = (mobile || "").trim();
    const cleanEmail = (email || "").trim();
    const cleanAddress = (address || "").trim();
    const cleanImage = (image || "").trim();
    const cleanDateOfJoin = (dateofjoin || "").trim();

    let insertResult;

    if (empid !== undefined && empid !== null && empid !== "") {
      const explicitId = parseInt(empid, 10);
      if (isNaN(explicitId) || explicitId <= 0) {
        return res.status(400).json({
          success: false,
          message: "Employee ID must be a valid positive integer.",
        });
      }

      // Check if employee ID already exists
      const existing = await client.execute({
        sql: `SELECT empid FROM employees WHERE empid = ? LIMIT 1;`,
        args: [explicitId],
      });

      if (existing.rows.length > 0) {
        return res.status(400).json({
          success: false,
          message: `Employee ID ${explicitId} already exists. Please choose another ID.`,
        });
      }

      insertResult = await client.execute({
        sql: `
          INSERT INTO employees (
            empid, empname, branchid, dateofjoin, active, 
            bloodgroup, mobile, email, address, image, 
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        `,
        args: [
          explicitId,
          empname.trim(),
          cleanBranchId,
          cleanDateOfJoin,
          cleanActive,
          cleanBloodGroup,
          cleanMobile,
          cleanEmail,
          cleanAddress,
          cleanImage,
          now,
          now,
        ],
      });
    } else {
      insertResult = await client.execute({
        sql: `
          INSERT INTO employees (
            empname, branchid, dateofjoin, active, 
            bloodgroup, mobile, email, address, image, 
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        `,
        args: [
          empname.trim(),
          cleanBranchId,
          cleanDateOfJoin,
          cleanActive,
          cleanBloodGroup,
          cleanMobile,
          cleanEmail,
          cleanAddress,
          cleanImage,
          now,
          now,
        ],
      });
    }

    const assignedId = empid ? parseInt(empid, 10) : Number(insertResult.lastInsertRowid);

    // Fetch newly created employee record with branch name
    const fetchResult = await client.execute({
      sql: `
        SELECT 
          e.*,
          COALESCE(b.branchname, '') AS branchname
        FROM employees e
        LEFT JOIN branches b ON UPPER(TRIM(e.branchid)) = UPPER(TRIM(b.branchid))
        WHERE e.empid = ?;
      `,
      args: [assignedId],
    });

    const newEmployee = fetchResult.rows?.[0] || {
      empid: assignedId,
      empname: empname.trim(),
      branchid: cleanBranchId,
      dateofjoin: cleanDateOfJoin,
      active: cleanActive,
      bloodgroup: cleanBloodGroup,
      mobile: cleanMobile,
      email: cleanEmail,
      address: cleanAddress,
      image: cleanImage,
      created_at: now,
      updated_at: now,
    };

    return res.status(201).json({
      success: true,
      message: `Employee "${empname.trim()}" (ID: ${assignedId}) created successfully.`,
      employee: newEmployee,
    });
  } catch (error) {
    console.error("createEmployeeController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create employee.",
    });
  }
}

/**
 * PUT /api/tenant/employees/:id
 * Updates an existing employee record by empid.
 */
export async function updateEmployeeController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureEmployeesTable(client);

    const { id } = req.params;
    const empid = parseInt(id, 10);
    if (isNaN(empid)) {
      return res.status(400).json({
        success: false,
        message: "Invalid employee ID specified.",
      });
    }

    const {
      empname,
      branchid,
      dateofjoin = "",
      active = 1,
      bloodgroup = "",
      mobile = "",
      email = "",
      address = "",
      image = "",
    } = req.body;

    if (!empname || !empname.trim()) {
      return res.status(400).json({
        success: false,
        message: "Employee name cannot be empty.",
      });
    }

    if (!branchid || !branchid.trim()) {
      return res.status(400).json({
        success: false,
        message: "Branch assignment is required.",
      });
    }

    const checkExists = await client.execute({
      sql: `SELECT empid FROM employees WHERE empid = ? LIMIT 1;`,
      args: [empid],
    });

    if (checkExists.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Employee with ID ${empid} not found.`,
      });
    }

    const now = new Date().toISOString();
    const cleanActive = active === 0 || active === false || active === "0" ? 0 : 1;
    const cleanBloodGroup = (bloodgroup || "").trim().toUpperCase();
    const cleanBranchId = branchid.trim().toUpperCase();

    await client.execute({
      sql: `
        UPDATE employees SET
          empname = ?,
          branchid = ?,
          dateofjoin = ?,
          active = ?,
          bloodgroup = ?,
          mobile = ?,
          email = ?,
          address = ?,
          image = ?,
          updated_at = ?
        WHERE empid = ?;
      `,
      args: [
        empname.trim(),
        cleanBranchId,
        (dateofjoin || "").trim(),
        cleanActive,
        cleanBloodGroup,
        (mobile || "").trim(),
        (email || "").trim(),
        (address || "").trim(),
        (image || "").trim(),
        now,
        empid,
      ],
    });

    // Fetch updated record
    const fetchResult = await client.execute({
      sql: `
        SELECT 
          e.*,
          COALESCE(b.branchname, '') AS branchname
        FROM employees e
        LEFT JOIN branches b ON UPPER(TRIM(e.branchid)) = UPPER(TRIM(b.branchid))
        WHERE e.empid = ?;
      `,
      args: [empid],
    });

    return res.json({
      success: true,
      message: `Employee #${empid} updated successfully.`,
      employee: fetchResult.rows?.[0],
    });
  } catch (error) {
    console.error("updateEmployeeController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update employee.",
    });
  }
}

/**
 * DELETE /api/tenant/employees/:id
 * Deletes an employee record by empid.
 */
export async function deleteEmployeeController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureEmployeesTable(client);

    const { id } = req.params;
    const empid = parseInt(id, 10);
    if (isNaN(empid)) {
      return res.status(400).json({
        success: false,
        message: "Invalid employee ID specified.",
      });
    }

    const checkExists = await client.execute({
      sql: `SELECT empid, empname FROM employees WHERE empid = ? LIMIT 1;`,
      args: [empid],
    });

    if (checkExists.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `Employee with ID ${empid} not found.`,
      });
    }

    const empName = checkExists.rows[0].empname;

    await client.execute({
      sql: `DELETE FROM employees WHERE empid = ?;`,
      args: [empid],
    });

    return res.json({
      success: true,
      message: `Employee "${empName}" (ID: ${empid}) deleted successfully.`,
    });
  } catch (error) {
    console.error("deleteEmployeeController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete employee.",
    });
  }
}
