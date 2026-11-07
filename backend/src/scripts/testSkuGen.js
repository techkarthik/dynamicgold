export function getFinancialYearEndYY(now = new Date()) {
  const month = now.getMonth() + 1;
  const fullYear = now.getFullYear();
  let startYear = fullYear;
  if (month < 4) {
    startYear = fullYear - 1;
  }
  const endYear = startYear + 1;
  return String(endYear).slice(-2);
}

export function getAlphaFromIndex(index) {
  let s = "";
  let n = index;
  while (n >= 0) {
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26) - 1;
  }
  return s || "A";
}

export function getIndexFromAlpha(str) {
  let res = 0;
  const upper = str.toUpperCase();
  for (let i = 0; i < upper.length; i++) {
    res = res * 26 + (upper.charCodeAt(i) - 64);
  }
  return res - 1;
}

const yearYY = getFinancialYearEndYY();
console.log("Year YY:", yearYY);

for (const idx of [1, 2, 3, 999, 1000, 1001, 1998, 1999, 25974, 25975]) {
  const zeroBased = idx - 1;
  const letterIndex = Math.floor(zeroBased / 999);
  const numInSeries = (zeroBased % 999) + 1;
  const letterStr = getAlphaFromIndex(letterIndex);
  const numStr = String(numInSeries).padStart(3, "0");
  const sku = `${yearYY}${letterStr}${numStr}`;

  const match = sku.match(new RegExp(`^${yearYY}([A-Z]+)(\\d{3,})$`));
  const parsedLetterIdx = getIndexFromAlpha(match[1]);
  const parsedNum = parseInt(match[2], 10);
  const recoveredIdx = parsedLetterIdx * 999 + parsedNum;

  console.log(`idx: ${idx} -> SKU: ${sku} -> recovered: ${recoveredIdx}`);
}
