import jwt from "jsonwebtoken";
import { masterDb } from "../config/postgres.js";

const JWT_SECRET = process.env.JWT_SECRET || "progold_super_secure_jwt_secret_key_2026_turso_multitenant";

const _tenantAuthCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export function invalidateTenantAuthCache(tenantId) {
  if (tenantId) {
    _tenantAuthCache.delete(Number(tenantId));
    _tenantAuthCache.delete(String(tenantId));
  } else {
    _tenantAuthCache.clear();
  }
}

export async function requireAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ success: false, message: "Authorization token required." });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, JWT_SECRET);

    let tenant = null;
    const cached = _tenantAuthCache.get(decoded.id);
    if (cached && Date.now() < cached.expiresAt) {
      tenant = cached.tenant;
    } else {
      // Fetch tenant from master database
      const result = await masterDb.execute({
        sql: `SELECT id, email, contact_number, schema_name, valid_from, valid_to, status, created_at, business_name, business_logo
              FROM tenants WHERE id = ? LIMIT 1`,
        args: [decoded.id],
      });

      if (result.rows.length === 0) {
        return res.status(401).json({ success: false, message: "Tenant account not found." });
      }

      tenant = result.rows[0];
      _tenantAuthCache.set(decoded.id, {
        tenant,
        expiresAt: Date.now() + CACHE_TTL_MS,
      });
    }

    // Check status
    if (tenant.status !== "ACTIVE") {
      return res.status(403).json({ success: false, message: "Your tenant account is inactive or suspended." });
    }

    // Check validity period
    const today = new Date().toISOString().split("T")[0];
    if (tenant.valid_from && tenant.valid_to) {
      if (today < tenant.valid_from || today > tenant.valid_to) {
        return res.status(403).json({
          success: false,
          message: `Your access subscription expired on ${tenant.valid_to}. (Valid range: ${tenant.valid_from} to ${tenant.valid_to})`,
          isExpired: true,
          validFrom: tenant.valid_from,
          validTo: tenant.valid_to,
        });
      }
    }

    req.tenant = tenant;
    req.user = {
      role: decoded.role || "ADMIN",
      userId: decoded.userId || "ADMIN",
      username: decoded.username || tenant.business_name || "Admin",
      email: decoded.email || tenant.email,
    };
    next();
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({ success: false, message: "Session expired. Please log in again." });
    }
    return res.status(401).json({ success: false, message: "Invalid or malformed authorization token." });
  }
}
