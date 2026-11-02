// test/smart_tv/storage_security_test.js
// Tests Smart TV At-Rest Encryption & Legacy Compatibility (SEC-04).

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const STORAGE_PATH = path.join(__dirname, '..', '..', 'smart_tv', 'js', 'storage.js');
const storageSource = fs.readFileSync(STORAGE_PATH, 'utf8');

console.log('--- Running Smart TV Storage Security Test (SEC-04) ---');

const dummyStorage = {};
const mockLocalStorage = {
  getItem: (k) => dummyStorage[k] || null,
  setItem: (k, v) => { dummyStorage[k] = String(v); },
  removeItem: (k) => { delete dummyStorage[k]; }
};

const dummyWindow = {
  localStorage: mockLocalStorage
};

// Evaluate storage.js in mock environment
const evalEnv = new Function('window', storageSource);
evalEnv(dummyWindow);

const TVStorage = dummyWindow.TVStorage;
assert.ok(TVStorage, 'TVStorage must be defined on window');

// Test 1: saveAccount stores encrypted password at rest
const testAcc = {
  id: 'acc_101',
  name: 'My IPTV Account',
  serverUrl: 'http://xtream.stream:8080',
  username: 'test_user_smart_tv',
  password: 'SuperSecretTvPassword999!',
  type: 'xtream'
};

TVStorage.saveAccount(testAcc);

// Verify raw content in localStorage: MUST BE ENCRYPTED (SEC-04)
const rawStored = mockLocalStorage.getItem('goat_accounts');
assert.ok(rawStored, 'goat_accounts must exist in localStorage');
const rawParsed = JSON.parse(rawStored);
assert.strictEqual(rawParsed.length, 1);
assert.ok(rawParsed[0].password.startsWith('enc:v1:'), 'Password in localStorage must be encrypted with enc:v1:');
assert.ok(!rawParsed[0].password.includes('SuperSecretTvPassword999!'), 'Plaintext password must NOT be in localStorage');
console.log('✓ Passwords are encrypted at rest in localStorage (SEC-04)');

// Test 2: getAccounts transparently returns decrypted plaintext in memory (Zero Breakage)
const loadedAccounts = TVStorage.getAccounts();
assert.strictEqual(loadedAccounts.length, 1);
assert.strictEqual(loadedAccounts[0].password, 'SuperSecretTvPassword999!', 'In-memory account must have decrypted plaintext password');
console.log('✓ In-memory account returns decrypted plaintext password (Zero Breakage)');

// Test 3: Legacy Compatibility - Plaintext accounts already in localStorage are preserved and auto-migrated
const legacyAccounts = [
  {
    id: 'acc_legacy_1',
    name: 'Old Plaintext Account',
    serverUrl: 'http://old.server.com',
    username: 'olduser',
    password: 'legacy_plain_password_123',
    type: 'xtream'
  }
];
// Write directly to localStorage to simulate legacy user update
mockLocalStorage.setItem('goat_accounts', JSON.stringify(legacyAccounts));

// Call getAccounts: must load legacy password without error
const migratedList = TVStorage.getAccounts();
assert.strictEqual(migratedList.length, 1);
assert.strictEqual(migratedList[0].password, 'legacy_plain_password_123', 'Legacy plaintext account must load successfully');

// Verify that it was auto-migrated in localStorage to enc:v1:
const upgradedRaw = JSON.parse(mockLocalStorage.getItem('goat_accounts'));
assert.ok(upgradedRaw[0].password.startsWith('enc:v1:'), 'Legacy account must be auto-migrated to enc:v1: in localStorage');
console.log('✓ Legacy plaintext accounts are seamlessly loaded and auto-migrated to enc:v1:');

// Test 4: M3U accounts with empty password work cleanly
const m3uAcc = {
  id: 'acc_m3u',
  name: 'Free M3U Playlist',
  serverUrl: 'http://free.m3u/playlist.m3u',
  username: '',
  password: '',
  type: 'm3u'
};
TVStorage.saveAccount(m3uAcc);
const allAfterM3u = TVStorage.getAccounts();
const foundM3u = allAfterM3u.find(a => a.id === 'acc_m3u');
assert.ok(foundM3u, 'M3U account must exist');
assert.strictEqual(foundM3u.password, '', 'Empty password remains empty');
console.log('✓ M3U accounts without password work cleanly');

console.log('\n--- ALL SMART TV STORAGE SECURITY TESTS PASSED ---');
