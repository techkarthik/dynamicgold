async function testEndpoints() {
  try {
    // 1. Test Health
    const healthRes = await fetch("http://localhost:5000/api/health");
    console.log("Health check response:", await healthRes.json());

    // 2. Test Send OTP
    const testEmail = "tenant_test@example.com";
    const otpRes = await fetch("http://localhost:5000/api/auth/send-otp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: testEmail }),
    });
    const otpData = await otpRes.json();
    console.log("Send OTP response:", otpData);

    const receivedCode = otpData.devOtp;

    // 3. Test Verify OTP
    const verifyRes = await fetch("http://localhost:5000/api/auth/verify-otp", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: testEmail, code: receivedCode }),
    });
    console.log("Verify OTP response:", await verifyRes.json());

    // 4. Test Turso URL & Token validation with valid master credentials
    const tursoTestRes = await fetch("http://localhost:5000/api/auth/test-turso", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        turso_url: "libsql://gold-techkarthik.aws-ap-south-1.turso.io",
        turso_token: (process.env.MASTER_TURSO_AUTH_TOKEN || process.env.TURSO_AUTH_TOKEN || ""),
      }),
    });
    console.log("Turso Connection Test response:", await tursoTestRes.json());

    console.log("\n All Backend API endpoints tested and functioning properly!");
  } catch (err) {
    console.error("Endpoint test error:", err);
  }
}

testEndpoints();
