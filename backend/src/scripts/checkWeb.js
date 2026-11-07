async function check() {
  try {
    const res = await fetch("http://localhost:3000");
    console.log("Flutter web response status:", res.status);
  } catch (e) {
    console.log("Not ready yet:", e.message);
  }
}
check();
