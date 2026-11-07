import { sendOtp } from "../services/otpService.js";

async function testGmailOtp() {
  console.log("Testing live OTP email delivery via Gmail SMTP to techkarthikmahalingam@gmail.com...");
  try {
    const res = await sendOtp("techkarthikmahalingam@gmail.com");
    console.log("sendOtp Response:", res);
    if (res.emailSent) {
      console.log("\n Real email delivered successfully to techkarthikmahalingam@gmail.com!");
    } else {
      console.log("\n Email sending did not complete:", res.message);
    }
  } catch (err) {
    console.error("Test email error:", err);
  }
}

testGmailOtp();
