import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const frontendDir = path.resolve(rootDir, 'frontend');

// Helper to format date in IST (or system locale)
function getFormattedBuildInfo() {
  const now = new Date();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  
  // Format day, month, year, hours, minutes
  const day = String(now.getDate()).padStart(2, '0');
  const month = months[now.getMonth()];
  const year = now.getFullYear();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  
  const buildDateStr = `${day}-${month}-${year} ${hours}:${minutes} IST`;
  const buildNum = `${year}${String(now.getMonth() + 1).padStart(2, '0')}${day}${hours}${minutes}`;
  return { buildDateStr, buildNum, year, month, day, hours, minutes };
}

// 1. Read current version from pubspec.yaml
const pubspecPath = path.join(frontendDir, 'pubspec.yaml');
let pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
const versionMatch = pubspecContent.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m);
const currentVersion = versionMatch ? versionMatch[1] : '2.5.0';

const { buildDateStr, buildNum } = getFormattedBuildInfo();
console.log('========================================================');
console.log(`🔨 Building ProGold Desktop Release (Windows x64)`);
console.log(`📦 Version:    v${currentVersion}`);
console.log(`🕒 Build Date: ${buildDateStr}`);
console.log(`🔢 Build Num:  ${buildNum}`);
console.log('========================================================\n');

// 2. Update frontend/lib/constants/app_version.dart with current timestamp
const appVersionDartPath = path.join(frontendDir, 'lib', 'constants', 'app_version.dart');
const appVersionContent = `/// Centralized App Version & Build Metadata for ProGold ERP.
/// This file is automatically updated on each release build.
class AppVersion {
  static const String appName = "ProGold";
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '${currentVersion}',
  );
  static const String buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: '${buildDateStr}',
  );
  static const String channel = "Cloud Active";

  /// Format: "ProGold v${currentVersion} • Build: ${buildDateStr}"
  static String get drawerVersion => "$appName v$version • Build: $buildDate";

  /// Format: "ProGold v${currentVersion} • Build: ${buildDateStr} • Cloud Active"
  static String get badgeVersion => "$appName v$version • Build: $buildDate • $channel";

  /// Full title: "ProGold v${currentVersion} (${buildDateStr})"
  static String get fullTitle => "$appName v$version ($buildDate)";
}
`;
fs.writeFileSync(appVersionDartPath, appVersionContent, 'utf8');
console.log(`✅ Updated app_version.dart with Build Date: ${buildDateStr}`);

// 3. Update pubspec.yaml version
pubspecContent = pubspecContent.replace(/^version:.*$/m, `version: ${currentVersion}+${buildNum}`);
fs.writeFileSync(pubspecPath, pubspecContent, 'utf8');
console.log(`✅ Updated pubspec.yaml version: ${currentVersion}+${buildNum}`);

// 4. Terminate any running frontend.exe to avoid file lock (LNK1104)
try {
  execSync('powershell -Command "Get-Process frontend -ErrorAction SilentlyContinue | Stop-Process -Force"', { stdio: 'ignore' });
} catch (_) {}

// 5. Run Flutter build
console.log('\n🚀 Running flutter build windows --release...');
const buildCmd = `flutter build windows --release --dart-define=APP_VERSION="${currentVersion}" --dart-define=BUILD_DATE="${buildDateStr}"`;
execSync(buildCmd, { cwd: frontendDir, stdio: 'inherit', shell: true });

// 5. Verify build output
const releaseDir = path.join(frontendDir, 'build', 'windows', 'x64', 'runner', 'Release');
const exePath = path.join(releaseDir, 'frontend.exe');

if (!fs.existsSync(exePath)) {
  console.error(`❌ Build error: ${exePath} does not exist!`);
  process.exit(1);
}

const exeStats = fs.statSync(exePath);
console.log(`\n🎉 Build Successful!`);
console.log(`📁 Executable: ${exePath}`);
console.log(`📊 Size:       ${(exeStats.size / 1024).toFixed(2)} KB`);

// 6. Automatically compress release directory into ProGold-Windows-x64.zip
const zipPath = path.join(rootDir, 'ProGold-Windows-x64.zip');
console.log(`\n📦 Packaging into ${zipPath}...`);
try {
  // Use PowerShell Compress-Archive for reliable native Windows zipping
  const zipCmd = `powershell -Command "if (Test-Path '${zipPath}') { Remove-Item '${zipPath}' -Force }; Compress-Archive -Path '${releaseDir}\\*' -DestinationPath '${zipPath}' -Force"`;
  execSync(zipCmd, { cwd: rootDir, stdio: 'inherit' });
  const zipStats = fs.statSync(zipPath);
  console.log(`✅ Release Package Created: ${zipPath} (${(zipStats.size / (1024 * 1024)).toFixed(2)} MB)`);
} catch (err) {
  console.warn(`⚠️ Warning: Could not create zip archive automatically:`, err.message);
}

console.log('\n========================================================');
console.log(`✨ ProGold Desktop Release v${currentVersion} (${buildDateStr}) Ready!`);
console.log('========================================================\n');
