import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { randomUUID } from "crypto";
import { masterDb, createTenantClient, createTenantSchema, dropTenantSchema } from "../config/postgres.js";
import { sendOtp, verifyOtp, isEmailVerified } from "../services/otpService.js";
import { syncTenantDatabaseSchema } from "../services/tenantSchemaService.js";

const JWT_SECRET = process.env.JWT_SECRET || "progold_super_secure_jwt_secret_key_2026_turso_multitenant";

/**
 * Send OTP to email for registration
 */
export async function sendOtpController(req, res) {
  try {
    const { email } = req.body;
    if (!email || !email.includes("@")) {
      return res.status(400).json({ success: false, message: "Valid email is required." });
    }

    const result = await sendOtp(email);
    if (!result.success) {
      return res.status(400).json(result);
    }
    return res.json(result);
  } catch (error) {
    console.error("sendOtpController error:", error);
    return res.status(500).json({ success: false, message: `Failed to send verification code: ${error.message}` });
  }
}

/**
 * Verify OTP entered by user
 */
export async function verifyOtpController(req, res) {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ success: false, message: "Email and OTP code are required." });
    }

    const result = await verifyOtp(email, code);
    if (!result.valid) {
      return res.status(400).json({ success: false, message: result.message });
    }

    return res.json({ success: true, message: result.message });
  } catch (error) {
    console.error("verifyOtpController error:", error);
    return res.status(500).json({ success: false, message: "Failed to verify OTP." });
  }
}

/**
 * Register a new multi-tenant account
 */
export async function registerController(req, res) {
  let schemaName;
  try {
    const {
      email,
      password,
      contact_number,
      valid_from,
      valid_to,
    } = req.body;

    // Basic Validations
    if (!email || !password || !contact_number || !valid_from || !valid_to) {
      return res.status(400).json({
        success: false,
        message: "All fields are required (Email, Password, Contact, Valid From, Valid To).",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Verify OTP was completed
    const verified = await isEmailVerified(normalizedEmail);
    if (!verified) {
      return res.status(400).json({
        success: false,
        message: "Email has not been verified with OTP. Please complete OTP verification first.",
      });
    }

    // 2. Check if email already exists
    const existing = await masterDb.execute({
      sql: `SELECT id FROM tenants WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });
    if (existing.rows.length > 0) {
      return res.status(409).json({
        success: false,
        message: "An account with this email is already registered.",
      });
    }

    // Hash password and provision an isolated PostgreSQL schema for the tenant.
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);
    const now = new Date().toISOString();
    schemaName = `tenant_${randomUUID().replace(/-/g, "")}`;
    await createTenantSchema(schemaName);
    try {
      await syncTenantDatabaseSchema(schemaName);
      const insertResult = await masterDb.execute({
        sql: `INSERT INTO tenants (
                email, password_hash, contact_number, schema_name,
                valid_from, valid_to, status, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE', ?, ?)`,
        args: [
          normalizedEmail,
          passwordHash,
          contact_number.trim(),
          schemaName,
          valid_from.trim(),
          valid_to.trim(),
          now,
          now,
        ],
      });

      const tenantId = Number(insertResult.lastInsertRowid);

      const token = jwt.sign(
        { id: tenantId, email: normalizedEmail },
        JWT_SECRET,
        { expiresIn: "7d" }
      );

      return res.status(201).json({
        success: true,
        message: "Tenant registered successfully!",
        token,
        tenant: {
          id: tenantId,
          email: normalizedEmail,
          contact_number: contact_number.trim(),
          schema_name: schemaName,
          valid_from: valid_from.trim(),
          valid_to: valid_to.trim(),
          status: "ACTIVE",
          created_at: now,
        },
      });
    } catch (provisionError) {
      await dropTenantSchema(schemaName).catch((cleanupError) => {
        console.error("Failed to clean up tenant schema after registration error:", cleanupError);
      });
      throw provisionError;
    }
  } catch (error) {
    console.error("registerController error:", error);
    return res.status(500).json({
      success: false,
      message: `Registration failed: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}

/**
 * Verify if email exists globally (either as admin tenant or limited user)
 * POST /api/auth/verify-email
 */
export async function verifyEmailController(req, res) {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required." });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Check in tenants table (Admin)
    const adminCheck = await masterDb.execute({
      sql: `SELECT id, email, business_name FROM tenants WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });

    if (adminCheck.rows.length > 0) {
      const admin = adminCheck.rows[0];
      return res.json({
        success: true,
        exists: true,
        role: "ADMIN",
        username: admin.business_name || "Admin",
        email: admin.email
      });
    }

    // 2. Check in tenant_users_lookup table (Limited User)
    const userCheck = await masterDb.execute({
      sql: `SELECT email, tenant_id, userid, username FROM tenant_users_lookup WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });

    if (userCheck.rows.length > 0) {
      const user = userCheck.rows[0];
      return res.json({
        success: true,
        exists: true,
        role: "USER",
        username: user.username,
        email: user.email
      });
    }

    return res.json({
      success: false,
      exists: false,
      message: "Email address not registered."
    });
  } catch (error) {
    console.error("verifyEmailController error:", error);
    return res.status(500).json({
      success: false,
      message: `Verification failed: ${error?.message || "Internal server error"}`
    });
  }
}

/**
 * Tenant login handler
 */
export async function loginController(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Email and password are required." });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Fetch tenant from master first (to see if it's admin)
    const tenantResult = await masterDb.execute({
      sql: `SELECT * FROM tenants WHERE email = ? LIMIT 1`,
      args: [normalizedEmail],
    });

    let tenant = null;
    let role = "ADMIN";
    let userId = "ADMIN";
    let username = "";
    let isMatch = false;
    let dbUser = null;

    if (tenantResult.rows.length > 0) {
      tenant = tenantResult.rows[0];
      role = "ADMIN";
      userId = "ADMIN";
      username = tenant.business_name || "Admin";

      // Compare password using tenants.password_hash
      isMatch = await bcrypt.compare(password, tenant.password_hash);
    } else {
      // 2. Not found in tenants, check global lookup
      const lookupResult = await masterDb.execute({
        sql: `SELECT email, tenant_id, userid, username FROM tenant_users_lookup WHERE email = ? LIMIT 1`,
        args: [normalizedEmail],
      });

      if (lookupResult.rows.length === 0) {
        return res.status(401).json({ success: false, message: "Invalid email or password." });
      }

      const lookupRow = lookupResult.rows[0];
      
      // Load tenant information
      const tenantInfoResult = await masterDb.execute({
        sql: `SELECT * FROM tenants WHERE id = ? LIMIT 1`,
        args: [lookupRow.tenant_id],
      });

      if (tenantInfoResult.rows.length === 0) {
        return res.status(401).json({ success: false, message: "Tenant account not found." });
      }

      tenant = tenantInfoResult.rows[0];
      role = "USER";
      userId = lookupRow.userid;
      username = lookupRow.username;

      // Connect to tenant database to verify password and status
      const tenantClient = createTenantClient(tenant.schema_name);
      
      const userResult = await tenantClient.execute({
        sql: `SELECT * FROM users WHERE userid = ? LIMIT 1`,
        args: [userId],
      });

      if (userResult.rows.length === 0) {
        return res.status(401).json({ success: false, message: "User account not found." });
      }

      dbUser = userResult.rows[0];
      if (Number(dbUser.is_active) !== 1) {
        return res.status(403).json({ success: false, message: "Your user account is inactive." });
      }

      // Compare password against tenant user's password_hash
      isMatch = await bcrypt.compare(password, dbUser.password_hash);
    }

    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid email or password." });
    }

    // 3. Check status of tenant
    if (tenant.status !== "ACTIVE") {
      return res.status(403).json({ success: false, message: "Your tenant account is inactive or suspended." });
    }

    // 4. Check validity period of tenant subscription
    const today = new Date().toISOString().split("T")[0];
    const isExpired = today < tenant.valid_from || today > tenant.valid_to;

    if (isExpired) {
      return res.status(403).json({
        success: false,
        message: `Your account subscription has expired (Validity period: ${tenant.valid_from} to ${tenant.valid_to}). Please contact support.`,
        isExpired: true,
        validFrom: tenant.valid_from,
        validTo: tenant.valid_to,
      });
    }

    // 5. Generate JWT token with tenant id, email, role, userId, and username
    const token = jwt.sign(
      {
        id: tenant.id,
        email: normalizedEmail,
        role: role,
        userId: userId,
        username: username
      },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    // Prepare response payload
    const responseData = {
      success: true,
      message: "Login successful!",
      token,
      role: role,
      tenant: {
        id: tenant.id,
        email: tenant.email,
        contact_number: tenant.contact_number,
        schema_name: tenant.schema_name,
        valid_from: tenant.valid_from,
        valid_to: tenant.valid_to,
        status: tenant.status,
        created_at: tenant.created_at,
        business_name: tenant.business_name || "ProGold Business",
        business_logo: tenant.business_logo || "",
        username: username, // For UI display
      }
    };

    if (role === "USER" && dbUser) {
      responseData.user = {
        userid: dbUser.userid,
        username: dbUser.username,
        email: dbUser.email,
        branchid: dbUser.branchid,
        centlogin: dbUser.centlogin,
        allowed_menus: typeof dbUser.allowed_menus === "string" ? JSON.parse(dbUser.allowed_menus || "[]") : dbUser.allowed_menus,
      };
    }

    return res.json(responseData);
  } catch (error) {
    console.error("loginController error:", error);
    return res.status(500).json({
      success: false,
      message: `Login failed: ${error?.message || "Internal server error"}`,
      error: error?.message,
    });
  }
}
