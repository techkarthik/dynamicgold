import bcrypt from "bcryptjs";
import { createTenantClient, masterDb } from "../config/postgres.js";
import { sendOtp } from "../services/otpService.js";
import { ensureTableOnce } from "../utils/schemaCache.js";

/**
 * Ensures the users table exists in the tenant's PostgreSQL schema.
 */
export async function ensureUserTable(client, tenantUrl = "") {
  const key = tenantUrl || client?.schemaName || "default";
  await ensureTableOnce(`users:${key}`, async () => {
    await client.execute(`
      CREATE TABLE IF NOT EXISTS users (
        userid TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        email TEXT DEFAULT '',
        branchid TEXT DEFAULT '',
        is_active INTEGER DEFAULT 1,
        centlogin TEXT DEFAULT 'NO',
        profile_image TEXT DEFAULT '',
        allowed_menus TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);

    // Safe non-destructive column additions
    const safeColumns = [
      `ALTER TABLE users ADD COLUMN email TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN branchid TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1;`,
      `ALTER TABLE users ADD COLUMN centlogin TEXT DEFAULT 'NO';`,
      `ALTER TABLE users ADD COLUMN profile_image TEXT DEFAULT '';`,
      `ALTER TABLE users ADD COLUMN allowed_menus TEXT DEFAULT '[]';`,
    ];

    for (const sql of safeColumns) {
      try {
        await client.execute(sql);
      } catch (_) {}
    }
  });
}

/**
 * GET /api/tenant/users
 * Retrieves all user accounts for the authenticated tenant (excluding password hashes).
 */
export async function getUsersController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    const result = await client.execute(`
      SELECT 
        userid, 
        username, 
        email, 
        branchid, 
        is_active, 
        centlogin, 
        profile_image, 
        allowed_menus, 
        created_at, 
        updated_at 
      FROM users 
      ORDER BY created_at DESC;
    `);

    // Parse allowed_menus JSON string safely
    const users = (result.rows || []).map((u) => {
      let parsedMenus = [];
      try {
        if (typeof u.allowed_menus === "string" && u.allowed_menus.trim().startsWith("[")) {
          parsedMenus = JSON.parse(u.allowed_menus);
        } else if (Array.isArray(u.allowed_menus)) {
          parsedMenus = u.allowed_menus;
        }
      } catch (_) {
        parsedMenus = [];
      }

      return {
        ...u,
        is_active: Number(u.is_active) === 1,
        centlogin: String(u.centlogin || "NO").toUpperCase() === "YES" ? "YES" : "NO",
        allowed_menus: parsedMenus,
      };
    });

    return res.json({
      success: true,
      users,
    });
  } catch (error) {
    console.error("getUsersController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch users.",
    });
  }
}

/**
 * POST /api/tenant/users
 * Creates a new user record in the tenant database.
 */
export async function createUserController(req, res) {
  try {
    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    const {
      userid,
      username,
      password,
      email = "",
      branchid = "",
      is_active = 1,
      centlogin = "NO",
      profile_image = "",
      allowed_menus = [],
    } = req.body;

    if (!userid || !String(userid).trim()) {
      return res.status(400).json({
        success: false,
        message: "User ID is required.",
      });
    }

    const cleanUserId = String(userid).trim().toUpperCase();
    if (!username || !String(username).trim()) {
      return res.status(400).json({
        success: false,
        message: "Username is required.",
      });
    }

    if (!password || String(password).length < 4) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 4 characters long.",
      });
    }

    // Check global email uniqueness if email is provided
    if (email && String(email).trim().includes("@")) {
      const normalizedUserEmail = String(email).trim().toLowerCase();
      
      // Check in master tenants table
      const masterTenantCheck = await masterDb.execute({
        sql: `SELECT id FROM tenants WHERE email = ? LIMIT 1`,
        args: [normalizedUserEmail]
      });
      if (masterTenantCheck.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: `The email "${normalizedUserEmail}" is already used by a tenant administrator. Please use a different email.`
        });
      }
      
      // Check in global user lookup
      const globalLookupCheck = await masterDb.execute({
        sql: `SELECT email FROM tenant_users_lookup WHERE email = ? LIMIT 1`,
        args: [normalizedUserEmail]
      });
      if (globalLookupCheck.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: `The email "${normalizedUserEmail}" is already registered. Please use a unique email.`
        });
      }
    }

    // Check if User ID already exists
    const checkExists = await client.execute({
      sql: `SELECT userid FROM users WHERE userid = ? LIMIT 1;`,
      args: [cleanUserId],
    });

    if (checkExists.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: `User ID "${cleanUserId}" already exists. Please choose a unique User ID.`,
      });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(String(password), salt);

    const now = new Date().toISOString();
    const cleanCentLogin = String(centlogin).trim().toUpperCase() === "YES" ? "YES" : "NO";
    const cleanIsActive = is_active === true || Number(is_active) === 1 ? 1 : 0;
    const menusJson = Array.isArray(allowed_menus)
      ? JSON.stringify(allowed_menus)
      : typeof allowed_menus === "string"
      ? allowed_menus
      : "[]";

    await client.execute({
      sql: `
        INSERT INTO users (
          userid, username, password_hash, email, branchid, is_active, centlogin, profile_image, allowed_menus, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      `,
      args: [
        cleanUserId,
        String(username).trim(),
        passwordHash,
        String(email || "").trim(),
        String(branchid || "").trim(),
        cleanIsActive,
        cleanCentLogin,
        String(profile_image || "").trim(),
        menusJson,
        now,
        now,
      ],
    });

    // Sync to tenant_users_lookup in master DB
    if (email && String(email).trim().includes("@")) {
      const normalizedUserEmail = String(email).trim().toLowerCase();
      const tenantId = req.tenant.id;
      await masterDb.execute({
        sql: `INSERT INTO tenant_users_lookup (email, tenant_id, userid, username) VALUES (?, ?, ?, ?)
              ON CONFLICT (email) DO UPDATE SET tenant_id = EXCLUDED.tenant_id,
                userid = EXCLUDED.userid, username = EXCLUDED.username`,
        args: [normalizedUserEmail, tenantId, cleanUserId, String(username).trim()]
      });
    }

    return res.status(201).json({
      success: true,
      message: `User account "${cleanUserId}" created successfully!`,
      user: {
        userid: cleanUserId,
        username: String(username).trim(),
        email: String(email || "").trim(),
        branchid: String(branchid || "").trim(),
        is_active: cleanIsActive === 1,
        centlogin: cleanCentLogin,
        profile_image: String(profile_image || "").trim(),
        allowed_menus: Array.isArray(allowed_menus) ? allowed_menus : [],
        created_at: now,
        updated_at: now,
      },
    });
  } catch (error) {
    console.error("createUserController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to create user.",
    });
  }
}

/**
 * PUT /api/tenant/users/:id
 * Updates an existing user's details and menu permissions.
 */
export async function updateUserController(req, res) {
  try {
    const userId = req.params.id;
    if (!userId) {
      return res.status(400).json({ success: false, message: "User ID parameter is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    const {
      username,
      email,
      branchid,
      is_active,
      centlogin,
      profile_image,
      allowed_menus,
    } = req.body;

    const cleanUserId = String(userId).trim().toUpperCase();

    // Fetch current user details first
    const userCheck = await client.execute({
      sql: `SELECT email, username FROM users WHERE userid = ? LIMIT 1;`,
      args: [cleanUserId],
    });
    if (userCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: `User "${cleanUserId}" not found.`,
      });
    }
    const oldEmail = (userCheck.rows[0].email || "").trim().toLowerCase();
    const oldUsername = userCheck.rows[0].username || "";

    // Validate global uniqueness if email is changed
    if (email !== undefined && String(email).trim().toLowerCase() !== oldEmail) {
      const normalizedNewEmail = String(email).trim().toLowerCase();
      if (normalizedNewEmail.includes("@")) {
        // Check in master tenants table
        const masterTenantCheck = await masterDb.execute({
          sql: `SELECT id FROM tenants WHERE email = ? LIMIT 1`,
          args: [normalizedNewEmail]
        });
        if (masterTenantCheck.rows.length > 0) {
          return res.status(409).json({
            success: false,
            message: `The email "${normalizedNewEmail}" is already used by a tenant administrator. Please use a different email.`
          });
        }
        
        // Check in global user lookup
        const globalLookupCheck = await masterDb.execute({
          sql: `SELECT email FROM tenant_users_lookup WHERE email = ? LIMIT 1`,
          args: [normalizedNewEmail]
        });
        if (globalLookupCheck.rows.length > 0) {
          return res.status(409).json({
            success: false,
            message: `The email "${normalizedNewEmail}" is already registered by another user.`
          });
        }
      }
    }

    const now = new Date().toISOString();

    let menusJson = undefined;
    if (allowed_menus !== undefined) {
      menusJson = Array.isArray(allowed_menus)
        ? JSON.stringify(allowed_menus)
        : typeof allowed_menus === "string"
        ? allowed_menus
        : "[]";
    }

    let cleanActive = undefined;
    if (is_active !== undefined) {
      cleanActive = is_active === true || Number(is_active) === 1 ? 1 : 0;
    }

    let cleanCent = undefined;
    if (centlogin !== undefined) {
      cleanCent = String(centlogin).trim().toUpperCase() === "YES" ? "YES" : "NO";
    }

    await client.execute({
      sql: `
        UPDATE users
        SET username = COALESCE(?, username),
            email = COALESCE(?, email),
            branchid = COALESCE(?, branchid),
            is_active = COALESCE(?, is_active),
            centlogin = COALESCE(?, centlogin),
            profile_image = COALESCE(?, profile_image),
            allowed_menus = COALESCE(?, allowed_menus),
            updated_at = ?
        WHERE userid = ?;
      `,
      args: [
        username !== undefined ? String(username).trim() : null,
        email !== undefined ? String(email).trim() : null,
        branchid !== undefined ? String(branchid).trim() : null,
        cleanActive !== undefined ? cleanActive : null,
        cleanCent !== undefined ? cleanCent : null,
        profile_image !== undefined ? String(profile_image).trim() : null,
        menusJson !== undefined ? menusJson : null,
        now,
        cleanUserId,
      ],
    });

    // Sync lookup changes
    const updatedEmail = email !== undefined ? String(email).trim() : oldEmail;
    const updatedUsername = username !== undefined ? String(username).trim() : oldUsername;
    
    // 1. Delete old email from lookup if changed
    if (oldEmail && oldEmail !== updatedEmail.trim().toLowerCase()) {
      await masterDb.execute({
        sql: `DELETE FROM tenant_users_lookup WHERE email = ?`,
        args: [oldEmail]
      });
    }
    
    // 2. Insert or update new email lookup
    const normalizedUpdatedEmail = updatedEmail.trim().toLowerCase();
    if (normalizedUpdatedEmail.includes("@")) {
      const tenantId = req.tenant.id;
      await masterDb.execute({
        sql: `INSERT INTO tenant_users_lookup (email, tenant_id, userid, username) VALUES (?, ?, ?, ?)
              ON CONFLICT (email) DO UPDATE SET tenant_id = EXCLUDED.tenant_id,
                userid = EXCLUDED.userid, username = EXCLUDED.username`,
        args: [normalizedUpdatedEmail, tenantId, cleanUserId, updatedUsername]
      });
    }

    return res.json({
      success: true,
      message: `User "${cleanUserId}" updated successfully!`,
    });
  } catch (error) {
    console.error("updateUserController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to update user.",
    });
  }
}

/**
 * POST /api/tenant/users/:id/change-password
 * Updates the user's password.
 */
export async function changePasswordController(req, res) {
  try {
    const userId = req.params.id;
    const { new_password } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: "User ID parameter is required." });
    }

    if (!new_password || String(new_password).length < 4) {
      return res.status(400).json({
        success: false,
        message: "New password must be at least 4 characters long.",
      });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    const cleanUserId = String(userId).trim().toUpperCase();
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(String(new_password), salt);
    const now = new Date().toISOString();

    const result = await client.execute({
      sql: `UPDATE users SET password_hash = ?, updated_at = ? WHERE userid = ?;`,
      args: [passwordHash, now, cleanUserId],
    });

    if (result.rowsAffected === 0) {
      return res.status(404).json({
        success: false,
        message: `User "${cleanUserId}" not found.`,
      });
    }

    return res.json({
      success: true,
      message: `Password for user "${cleanUserId}" updated successfully!`,
    });
  } catch (error) {
    console.error("changePasswordController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to change password.",
    });
  }
}

/**
 * DELETE /api/tenant/users/:id
 * Deletes a user record by userid.
 */
export async function deleteUserController(req, res) {
  try {
    const userId = req.params.id;
    if (!userId) {
      return res.status(400).json({ success: false, message: "User ID is required." });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    const cleanUserId = String(userId).trim().toUpperCase();
    
    // Fetch user details first to get the email
    const userCheck = await client.execute({
      sql: `SELECT email FROM users WHERE userid = ? LIMIT 1;`,
      args: [cleanUserId],
    });

    const result = await client.execute({
      sql: `DELETE FROM users WHERE userid = ?;`,
      args: [cleanUserId],
    });

    if (userCheck.rows.length > 0) {
      const userEmail = (userCheck.rows[0].email || "").trim().toLowerCase();
      if (userEmail) {
        await masterDb.execute({
          sql: `DELETE FROM tenant_users_lookup WHERE email = ?`,
          args: [userEmail]
        });
      }
    }

    return res.json({
      success: true,
      message: `User "${cleanUserId}" deleted successfully!`,
      rowsAffected: result.rowsAffected,
    });
  } catch (error) {
    console.error("deleteUserController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to delete user.",
    });
  }
}

/**
 * POST /api/tenant/users/recover-password
 * Initiates password recovery by dispatching OTP to the user's registered email.
 */
export async function recoverPasswordOtpController(req, res) {
  try {
    const { userid, email } = req.body;
    if (!userid && !email) {
      return res.status(400).json({
        success: false,
        message: "User ID or registered Email is required for password recovery.",
      });
    }

    const schemaName = req.tenant.schema_name;
    const client = createTenantClient(schemaName);
    await ensureUserTable(client);

    let querySql = `SELECT userid, email, username FROM users WHERE `;
    let args = [];

    if (userid) {
      querySql += `userid = ? LIMIT 1;`;
      args.push(String(userid).trim().toUpperCase());
    } else {
      querySql += `LOWER(email) = ? LIMIT 1;`;
      args.push(String(email).trim().toLowerCase());
    }

    const result = await client.execute({ sql: querySql, args });
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No user found with the provided credentials.",
      });
    }

    const user = result.rows[0];
    if (!user.email || !user.email.includes("@")) {
      return res.status(400).json({
        success: false,
        message: "No valid email address is linked to this user account for password recovery. Please contact your store administrator.",
      });
    }

    // Send OTP to user's email
    const otpResult = await sendOtp(user.email);
    if (!otpResult.success) {
      return res.status(400).json(otpResult);
    }

    return res.json({
      success: true,
      message: `Password reset verification code dispatched to registered email ${user.email}.`,
      email: user.email,
      userid: user.userid,
      ...(otpResult.devOtp ? { devOtp: otpResult.devOtp } : {}),
    });
  } catch (error) {
    console.error("recoverPasswordOtpController error:", error);
    return res.status(500).json({
      success: false,
      message: error.message || "Failed to initiate password recovery.",
    });
  }
}
