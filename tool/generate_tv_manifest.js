// tool/generate_tv_manifest.js
// Generates smart_tv/manifest.json containing SHA-256 integrity checksums for all OTA bundle files.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const SMART_TV_DIR = path.join(__dirname, '..', 'smart_tv');
const MANIFEST_PATH = path.join(SMART_TV_DIR, 'manifest.json');

const FILES = [
  { name: 'style.css', path: path.join(SMART_TV_DIR, 'css', 'style.css') },
  { name: 'icons.js', path: path.join(SMART_TV_DIR, 'js', 'icons.js') },
  { name: 'i18n.js', path: path.join(SMART_TV_DIR, 'js', 'i18n.js') },
  { name: 'm3u.js', path: path.join(SMART_TV_DIR, 'js', 'm3u.js') },
  { name: 'storage.js', path: path.join(SMART_TV_DIR, 'js', 'storage.js') },
  { name: 'api.js', path: path.join(SMART_TV_DIR, 'js', 'api.js') },
  { name: 'sync.js', path: path.join(SMART_TV_DIR, 'js', 'sync.js') },
  { name: 'spatial_nav.js', path: path.join(SMART_TV_DIR, 'js', 'spatial_nav.js') },
  { name: 'virtual_list.js', path: path.join(SMART_TV_DIR, 'js', 'virtual_list.js') },
  { name: 'diagnostics.js', path: path.join(SMART_TV_DIR, 'js', 'diagnostics.js') },
  { name: 'subtitles.js', path: path.join(SMART_TV_DIR, 'js', 'subtitles.js') },
  { name: 'player.js', path: path.join(SMART_TV_DIR, 'js', 'player.js') },
  { name: 'updater.js', path: path.join(SMART_TV_DIR, 'js', 'updater.js') },
  { name: 'app.js', path: path.join(SMART_TV_DIR, 'js', 'app.js') }
];

function getVersion() {
  if (process.env.VERSION) {
    return process.env.VERSION.replace(/^v/, '');
  }
  const appinfoPath = path.join(SMART_TV_DIR, 'appinfo.json');
  if (fs.existsSync(appinfoPath)) {
    const data = JSON.parse(fs.readFileSync(appinfoPath, 'utf8'));
    if (data.version) return data.version;
  }
  return '2.0.3';
}

function generateManifest() {
  const version = getVersion();
  const manifest = {
    version: version,
    generatedAt: new Date().toISOString(),
    files: {}
  };

  for (const file of FILES) {
    if (!fs.existsSync(file.path)) {
      console.error(`[Error] File not found: ${file.path}`);
      process.exit(1);
    }
    const content = fs.readFileSync(file.path, 'utf8');
    const hash = crypto.createHash('sha256').update(content, 'utf8').digest('hex');
    manifest.files[file.name] = hash;
    console.log(`  [SHA256] ${file.name.padEnd(16)} = ${hash}`);
  }

  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
  console.log(`\nManifest written to ${MANIFEST_PATH} (v${version})`);
}

generateManifest();
