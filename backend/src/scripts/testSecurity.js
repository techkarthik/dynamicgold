async function testSecurity() {
  const res = await fetch("http://localhost:5000/api/auth/send-otp", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: "techkarthikmahalingam@gmail.com" }),
  });
  const data = await res.json();
  console.log("API Response:", data);
  if (data.devOtp) {
    console.error("WARNING: devOtp is still present in response!");
  } else {
    console.log("SUCCESS: OTP is strictly protected and not leaked in API response!");
  }
}
testSecurity();
