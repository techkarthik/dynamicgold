import crypto from "crypto";
import nodemailer from "nodemailer";
import { masterDb } from "../config/postgres.js";

/**
 * Returns a configured Nodemailer transporter
 */
function getTransporter() {
  const host = process.env.SMTP_HOST || "smtp.gmail.com";
  const user = (process.env.SMTP_USER || "").trim();
  // Auto-strip spaces if user pasted a 16-char Google App Password with spaces (e.g. "abcd efgh ijkl mnop")
  const pass = process.env.SMTP_PASS ? process.env.SMTP_PASS.replace(/\s+/g, "").trim() : "";
  const port = parseInt(process.env.SMTP_PORT || "465", 10);

  if (user && pass) {
    // If using Gmail SMTP, service: 'gmail' is much more reliable across AWS/Vercel serverless nodes
    if (host.includes("gmail") || process.env.SMTP_SERVICE === "gmail") {
      return nodemailer.createTransport({
        service: "gmail",
        auth: {
          user,
          pass,
        },
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 15000,
      });
    }

    return nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: {
        user,
        pass,
      },
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      socketTimeout: 15000,
    });
  }
  return null;
}

/**
 * Generates and sends a 6-digit OTP to the specified email.
 * @param {string} email
 * @returns {Promise<{success: boolean, message: string, devOtp?: string, emailSent?: boolean}>}
 */
export async function sendOtp(email) {
  const normalizedEmail = email.trim().toLowerCase();
  const isProduction = process.env.NODE_ENV === "production";

  // Generate secure 6-digit OTP
  const otpCode = crypto.randomInt(100000, 999999).toString();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 10 * 60 * 1000); // 10 minutes validity

  // Invalidate previous unverified OTPs for this email
  await masterDb.execute({
    sql: `DELETE FROM email_otps WHERE email = ? AND is_verified = 0`,
    args: [normalizedEmail],
  });

  // Save the OTP in the PostgreSQL master schema.
  await masterDb.execute({
    sql: `INSERT INTO email_otps (email, otp_code, expires_at, is_verified, created_at)
          VALUES (?, ?, ?, 0, ?)`,
    args: [normalizedEmail, otpCode, expiresAt.toISOString(), now.toISOString()],
  });

  if (isProduction) {
    console.log(`[OTP SERVICE] Verification code generated for ${normalizedEmail} (Expires: ${expiresAt.toISOString()})`);
  } else {
    console.log(`[OTP SERVICE] Generated code for ${normalizedEmail} (Development Mode: ${otpCode})`);
  }

  const transporter = getTransporter();
  let emailSent = false;
  let emailError = null;

  if (transporter) {
    try {
      const fromAddress = process.env.SMTP_FROM || `"ProGold Platform" <${process.env.SMTP_USER}>`;
      const info = await transporter.sendMail({
        from: fromAddress,
        to: normalizedEmail,
        subject: `Your ProGold Verification Code: ${otpCode}`,
        html: `
          <div style="background-color: #090D16; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 580px; margin: 20px auto; padding: 36px 28px; border-radius: 16px; border: 1px solid rgba(255, 255, 255, 0.12); color: #F8FAFC; box-shadow: 0 20px 40px rgba(0,0,0,0.5);">
            <div style="text-align: center; margin-bottom: 24px;">
              <div style="display: inline-block; background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 50%, #EC4899 100%); padding: 10px 18px; border-radius: 12px; font-weight: 800; font-size: 22px; color: #ffffff; letter-spacing: 0.5px;">
                ProGold
              </div>
              <p style="color: #94A3B8; font-size: 13px; margin-top: 8px; letter-spacing: 0.5px;">Multi-Tenant Cloud Platform</p>
            </div>
            
            <div style="background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 14px; padding: 24px; text-align: center; margin-bottom: 24px;">
              <h3 style="color: #ffffff; margin-top: 0; font-size: 18px; font-weight: 600;">Tenant Email Verification</h3>
              <p style="color: #94A3B8; font-size: 14px; line-height: 1.5; margin-bottom: 20px;">
                Please enter the following 6-digit verification code to confirm your email and activate your tenant database workspace:
              </p>
              
              <div style="font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #10B981; background: rgba(16, 185, 129, 0.1); padding: 18px; border-radius: 12px; border: 1px solid rgba(16, 185, 129, 0.3); display: inline-block; min-width: 220px;">
                ${otpCode}
              </div>
              
              <p style="color: #64748B; font-size: 12px; margin-top: 18px; margin-bottom: 0;">
                ⏱️ This code expires in <strong>10 minutes</strong>.
              </p>
            </div>
            
            <p style="color: #475569; font-size: 12px; text-align: center; line-height: 1.5; margin: 0;">
              If you did not request this code, you can safely disregard this message.<br>
              © 2026 ProGold Platform. Powered by PostgreSQL.
            </p>
          </div>
        `,
      });
      console.log(`[OTP SERVICE] Verification email sent to ${normalizedEmail} (MessageId: ${info.messageId})`);
      emailSent = true;
    } catch (err) {
      console.error("[OTP SERVICE] SMTP delivery error:", err.message);
      emailError = err.message;
    }
  } else {
    console.warn("[OTP SERVICE] SMTP not configured. OTP stored in database.");
  }

  // If email was successfully sent
  if (emailSent) {
    return {
      success: true,
      message: `Verification code has been sent to ${normalizedEmail}. Please check your inbox.`,
      emailSent: true,
    };
  }

  // If SMTP is not configured
  if (!transporter) {
    if (isProduction) {
      return {
        success: false,
        message: "Email service (SMTP) is not configured in Vercel environment variables. Please set SMTP_USER and SMTP_PASS in Vercel Project Settings.",
        emailSent: false,
      };
    }
    // In local development mode without SMTP, allow devOtp for convenience
    return {
      success: true,
      message: `Development mode: OTP generated (${otpCode})`,
      devOtp: otpCode,
      emailSent: false,
    };
  }

  // Transporter was configured but sending failed (e.g. invalid app password, timeout, or auth error)
  return {
    success: false,
    message: `Failed to deliver email: ${emailError || "SMTP connection failed"}. Please verify your Google App Password and SMTP settings on Vercel.`,
    emailSent: false,
  };
}

/**
 * Validates the entered OTP code for an email.
 * @param {string} email
 * @param {string} code
 * @returns {Promise<{valid: boolean, message: string}>}
 */
export async function verifyOtp(email, code) {
  const normalizedEmail = email.trim().toLowerCase();
  const trimmedCode = (code || "").trim();

  const result = await masterDb.execute({
    sql: `SELECT * FROM email_otps WHERE email = ? AND is_verified = 0 ORDER BY id DESC LIMIT 1`,
    args: [normalizedEmail],
  });

  if (result.rows.length === 0) {
    return { valid: false, message: "No active verification code found for this email. Please request a new OTP." };
  }

  const record = result.rows[0];
  const expiresAt = new Date(record.expires_at);

  if (new Date() > expiresAt) {
    return { valid: false, message: "Verification code has expired. Please request a new one." };
  }

  if (record.otp_code !== trimmedCode) {
    return { valid: false, message: "Invalid verification code. Please check your inbox and try again." };
  }

  // Mark as verified
  await masterDb.execute({
    sql: `UPDATE email_otps SET is_verified = 1 WHERE id = ?`,
    args: [record.id],
  });

  return { valid: true, message: "Email verified successfully!" };
}

/**
 * Checks if the email was recently verified (within last 30 minutes).
 * @param {string} email
 * @returns {Promise<boolean>}
 */
export async function isEmailVerified(email) {
  const normalizedEmail = email.trim().toLowerCase();
  const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();

  const result = await masterDb.execute({
    sql: `SELECT id FROM email_otps 
          WHERE email = ? AND is_verified = 1 AND created_at >= ?
          ORDER BY id DESC LIMIT 1`,
    args: [normalizedEmail, thirtyMinutesAgo],
  });

  return result.rows.length > 0;
}
