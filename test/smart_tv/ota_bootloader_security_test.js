// test/smart_tv/ota_bootloader_security_test.js
// Tests Smart TV OTA Bootloader and Updater cryptographic SHA-256 integrity verification (SEC-05).

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const assert = require('assert');

const SMART_TV_DIR = path.join(__dirname, '..', '..', 'smart_tv');
const MANIFEST_PATH = path.join(SMART_TV_DIR, 'manifest.json');
const BOOTLOADER_PATH = path.join(SMART_TV_DIR, 'js', 'bootloader.js');

console.log('--- Running Smart TV OTA Bootloader Security Test (SEC-05) ---');

// 1. Read manifest and verify manifest exists and format is valid
assert.ok(fs.existsSync(MANIFEST_PATH), 'manifest.json must exist');
const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
assert.ok(manifest.version, 'Manifest must have version');
assert.ok(manifest.files && typeof manifest.files === 'object', 'Manifest must have files map');

// 2. Extract computeSha256 from bootloader.js and test directly
const bootloaderSource = fs.readFileSync(BOOTLOADER_PATH, 'utf8');
const dummyWindow = { location: { reload: () => {} } };
const dummyDocument = {
  write: () => {},
  createElement: () => ({ id: '', textContent: '' }),
  head: { appendChild: () => {} }
};
const dummyStorage = {};
const mockLocalStorage = {
  getItem: (k) => dummyStorage[k] || null,
  setItem: (k, v) => { dummyStorage[k] = v; },
  removeItem: (k) => { delete dummyStorage[k]; }
};

// Evaluate bootloader in mock environment
const evalEnv = new Function(
  'window', 'document', 'localStorage', 'sessionStorage',
  bootloaderSource
);
evalEnv(dummyWindow, dummyDocument, mockLocalStorage, mockLocalStorage);

assert.ok(dummyWindow.TVBootloader, 'window.TVBootloader must be initialized');
assert.strictEqual(typeof dummyWindow.TVBootloader.computeSha256, 'function', 'computeSha256 must be exposed');

// 3. Verify that computeSha256 matches Node.js crypto for all manifest files
const files = [
  'style.css', 'icons.js', 'i18n.js', 'm3u.js', 'storage.js',
  'api.js', 'sync.js', 'spatial_nav.js', 'virtual_list.js',
  'diagnostics.js', 'subtitles.js', 'player.js', 'updater.js', 'app.js'
];

for (const name of files) {
  const filePath = path.join(SMART_TV_DIR, name.endsWith('.css') ? 'css' : 'js', name);
  const content = fs.readFileSync(filePath, 'utf8');
  const expectedHash = crypto.createHash('sha256').update(content, 'utf8').digest('hex');
  const actualHash = dummyWindow.TVBootloader.computeSha256(content);

  assert.strictEqual(actualHash, expectedHash, `Hash mismatch in computeSha256 for ${name}`);
  assert.strictEqual(manifest.files[name], expectedHash, `Manifest hash mismatch for ${name}`);
}
console.log('✓ All 14 bundle files verified against manifest SHA-256');

// 4. Test Tamper Resistance: Simulated malicious code injection into localStorage
const testBundle = {
  version: '2.9.9',
  hashes: Object.assign({}, manifest.files),
  files: {}
};
for (const name of files) {
  const filePath = path.join(SMART_TV_DIR, name.endsWith('.css') ? 'css' : 'js', name);
  testBundle.files[name] = fs.readFileSync(filePath, 'utf8');
}

// Case A: Valid bundle boots successfully
mockLocalStorage.setItem('goat_tv_ota_bundle', JSON.stringify(testBundle));
let evaluatedScripts = [];
const testWinA = {
  eval: (code) => { evaluatedScripts.push(code); },
  location: { reload: () => {} }
};
evalEnv(testWinA, dummyDocument, mockLocalStorage, mockLocalStorage);
assert.ok(evaluatedScripts.length >= 13, 'Valid bundle should evaluate application scripts');
console.log('✓ Valid bundle successfully verified and evaluated');

// Case B: Tampered script (code injection) in bundle
const tamperedBundle = JSON.parse(JSON.stringify(testBundle));
tamperedBundle.files['app.js'] += '\n/* MALICIOUS_INJECTION */';
mockLocalStorage.setItem('goat_tv_ota_bundle', JSON.stringify(tamperedBundle));

let evalCalledOnTampered = false;
let reloadCalled = false;
const testWinB = {
  eval: (code) => {
    if (code.includes('MALICIOUS_INJECTION')) {
      evalCalledOnTampered = true;
    }
  },
  location: { reload: () => { reloadCalled = true; } }
};

evalEnv(testWinB, dummyDocument, mockLocalStorage, mockLocalStorage);
assert.strictEqual(evalCalledOnTampered, false, 'Tampered script MUST NOT be evaluated!');
assert.strictEqual(mockLocalStorage.getItem('goat_tv_ota_bundle'), null, 'Tampered bundle must be purged from localStorage');
console.log('✓ Tampered script was BLOCKED and localStorage was safely purged');

// Case C: Missing hash entry (unsigned script)
const unsignedBundle = JSON.parse(JSON.stringify(testBundle));
delete unsignedBundle.hashes['app.js'];
mockLocalStorage.setItem('goat_tv_ota_bundle', JSON.stringify(unsignedBundle));

let evalCalledOnUnsigned = false;
const testWinC = {
  eval: () => { evalCalledOnUnsigned = true; },
  location: { reload: () => {} }
};
evalEnv(testWinC, dummyDocument, mockLocalStorage, mockLocalStorage);
assert.strictEqual(evalCalledOnUnsigned, false, 'Unsigned bundle MUST NOT be evaluated!');
assert.strictEqual(mockLocalStorage.getItem('goat_tv_ota_bundle'), null, 'Unsigned bundle must be purged');
console.log('✓ Unsigned bundle was rejected before execution');

console.log('\n--- ALL SEC-05 BOOTLOADER INTEGRITY TESTS PASSED ---');
