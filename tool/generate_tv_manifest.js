#!/usr/bin/env node
/**
 * tool/generate_tv_manifest.js
 * Generates smart_tv/manifest.json (Schema v2) with deterministic SHA-256 hashes
 * for HTML, CSS, Vendor Scripts, App Scripts, and In-App Assets, and synchronizes
 * version strings & FACTORY_HASHES into smart_tv/js/bootloader.js.
 *
 * Usage:
 *   node tool/generate_tv_manifest.js
 *   node tool/generate_tv_manifest.js --set-version 2.1.4
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT_DIR = path.resolve(__dirname, '..');
const SMART_TV_DIR = path.join(ROOT_DIR, 'smart_tv');
const APPINFO_PATH = path.join(SMART_TV_DIR, 'appinfo.json');
const CONFIG_XML_PATH = path.join(SMART_TV_DIR, 'config.xml');
const INDEX_HTML_PATH = path.join(SMART_TV_DIR, 'index.html');
const BOOTLOADER_PATH = path.join(SMART_TV_DIR, 'js', 'bootloader.js');
const UPDATER_PATH = path.join(SMART_TV_DIR, 'js', 'updater.js');
const MANIFEST_PATH = path.join(SMART_TV_DIR, 'manifest.json');

const CORE_VENDOR_ORDER = ['hls.min.js', 'qrcode.min.js'];
const CORE_SCRIPT_ORDER = [
  'icons.js',
  'i18n.js',
  'm3u.js',
  'storage.js',
  'api.js',
  'sync.js',
  'spatial_nav.js',
  'virtual_list.js',
  'diagnostics.js',
  'subtitles.js',
  'player.js',
  'updater.js'
];

function parseCliVersion() {
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if ((args[i] === '--set-version' || args[i] === '-v') && args[i + 1]) {
      return args[i + 1].replace(/^v/, '').trim();
    }
  }
  return null;
}

function getTargetVersion() {
  const cliVer = parseCliVersion();
  if (cliVer) return cliVer;
  const appInfo = JSON.parse(fs.readFileSync(APPINFO_PATH, 'utf8'));
  return String(appInfo.version || '2.1.3').replace(/^v/, '').trim();
}

function syncVersionStrings(version) {
  // 1. smart_tv/appinfo.json
  const appInfoRaw = fs.readFileSync(APPINFO_PATH, 'utf8');
  const appInfoUpdated = appInfoRaw.replace(/"version"\s*:\s*"[^"]+"/, `"version": "${version}"`);
  if (appInfoUpdated !== appInfoRaw) fs.writeFileSync(APPINFO_PATH, appInfoUpdated, 'utf8');

  // 2. smart_tv/config.xml
  const configXmlRaw = fs.readFileSync(CONFIG_XML_PATH, 'utf8');
  const configXmlUpdated = configXmlRaw.replace(/(<widget[\s\S]*?\bversion=")[^"]+(")/, `$1${version}$2`);
  if (configXmlUpdated !== configXmlRaw) fs.writeFileSync(CONFIG_XML_PATH, configXmlUpdated, 'utf8');

  // 3. smart_tv/index.html (?v=...)
  const indexRaw = fs.readFileSync(INDEX_HTML_PATH, 'utf8');
  const indexUpdated = indexRaw
    .replace(/href="css\/style\.css(?:\?v=[^"]*)?"/g, `href="css/style.css?v=${version}"`)
    .replace(/src="js\/bootloader\.js(?:\?v=[^"]*)?"/g, `src="js/bootloader.js?v=${version}"`);
  if (indexUpdated !== indexRaw) fs.writeFileSync(INDEX_HTML_PATH, indexUpdated, 'utf8');

  // 4. smart_tv/js/updater.js (var APP_VERSION = '...')
  const updaterRaw = fs.readFileSync(UPDATER_PATH, 'utf8');
  const updaterUpdated = updaterRaw.replace(/var\s+APP_VERSION\s*=\s*'[^']+';/, `var APP_VERSION = '${version}';`);
  if (updaterUpdated !== updaterRaw) fs.writeFileSync(UPDATER_PATH, updaterUpdated, 'utf8');
}

function sha256TextNormalized(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const normalized = raw.replace(/\r\n/g, '\n');
  return crypto.createHash('sha256').update(normalized, 'utf8').digest('hex').toLowerCase();
}

function sha256Binary(filePath) {
  const buf = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(buf).digest('hex').toLowerCase();
}

function getMimeType(fileName) {
  const ext = path.extname(fileName).toLowerCase();
  if (ext === '.svg') return 'image/svg+xml';
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.webp') return 'image/webp';
  if (ext === '.gif') return 'image/gif';
  return 'image/png';
}

function discoverFiles() {
  // Stylesheets in smart_tv/css/
  const cssDir = path.join(SMART_TV_DIR, 'css');
  const allCss = fs.readdirSync(cssDir).filter(f => f.endsWith('.css')).sort();
  const orderedCss = [];
  if (allCss.includes('style.css')) orderedCss.push('style.css');
  for (const c of allCss) {
    if (!orderedCss.includes(c)) orderedCss.push(c);
  }

  // JS in smart_tv/js/
  const jsDir = path.join(SMART_TV_DIR, 'js');
  const allJs = fs.readdirSync(jsDir).filter(f => f.endsWith('.js') && f !== 'bootloader.js').sort();

  const vendorScripts = [];
  for (const v of CORE_VENDOR_ORDER) {
    if (allJs.includes(v)) vendorScripts.push(v);
  }
  for (const f of allJs) {
    if (f.endsWith('.min.js') && !vendorScripts.includes(f)) {
      vendorScripts.push(f);
    }
  }

  const appScripts = [];
  for (const s of CORE_SCRIPT_ORDER) {
    if (allJs.includes(s) && !vendorScripts.includes(s)) {
      appScripts.push(s);
    }
  }
  for (const f of allJs) {
    if (f !== 'app.js' && !vendorScripts.includes(f) && !appScripts.includes(f)) {
      appScripts.push(f);
    }
  }
  if (allJs.includes('app.js')) {
    appScripts.push('app.js');
  }

  // In-app assets in smart_tv/assets/
  const assetsDir = path.join(SMART_TV_DIR, 'assets');
  const assets = fs.existsSync(assetsDir)
    ? fs.readdirSync(assetsDir).filter(f => /\.(png|svg|jpg|jpeg|webp|gif)$/i.test(f)).sort()
    : [];

  return { orderedCss, vendorScripts, appScripts, assets };
}

function main() {
  const version = getTargetVersion();
  syncVersionStrings(version);

  const { orderedCss, vendorScripts, appScripts, assets } = discoverFiles();

  const flatFiles = {};

  // 1. HTML
  const htmlHash = sha256TextNormalized(INDEX_HTML_PATH);
  const htmlEntry = {
    name: 'index.html',
    path: 'smart_tv/index.html',
    sha256: htmlHash
  };
  flatFiles['index.html'] = htmlHash;

  // 2. Styles
  const styleEntries = orderedCss.map(name => {
    const full = path.join(SMART_TV_DIR, 'css', name);
    const hash = sha256TextNormalized(full);
    flatFiles[name] = hash;
    return {
      name,
      path: `smart_tv/css/${name}`,
      sha256: hash
    };
  });

  // 3. Vendor Scripts
  const vendorEntries = vendorScripts.map(name => {
    const full = path.join(SMART_TV_DIR, 'js', name);
    const hash = sha256TextNormalized(full);
    flatFiles[name] = hash;
    return {
      name,
      path: `smart_tv/js/${name}`,
      sha256: hash
    };
  });

  // 4. App Scripts
  const scriptEntries = appScripts.map(name => {
    const full = path.join(SMART_TV_DIR, 'js', name);
    const hash = sha256TextNormalized(full);
    flatFiles[name] = hash;
    return {
      name,
      path: `smart_tv/js/${name}`,
      sha256: hash
    };
  });

  // 5. In-App Assets
  const assetEntries = assets.map(fileName => {
    const relName = `assets/${fileName}`;
    const full = path.join(SMART_TV_DIR, 'assets', fileName);
    const hash = sha256Binary(full);
    flatFiles[relName] = hash;
    return {
      name: relName,
      path: `smart_tv/assets/${fileName}`,
      sha256: hash,
      mime: getMimeType(fileName)
    };
  });

  // 6. Embed BASE_VERSION, EMBEDDED_VERSION, and FACTORY_HASHES into smart_tv/js/bootloader.js
  let bootloaderRaw = fs.readFileSync(BOOTLOADER_PATH, 'utf8');
  bootloaderRaw = bootloaderRaw
    .replace(/var\s+BASE_VERSION\s*=\s*'[^']+';/, `var BASE_VERSION = '${version}';`)
    .replace(/var\s+EMBEDDED_VERSION\s*=\s*'[^']+';/, `var EMBEDDED_VERSION = '${version}';`);

  const hashesFormatted = JSON.stringify(flatFiles, null, 4).replace(/\n/g, '\n  ');
  const factoryBlock = `/* __FACTORY_HASHES_START__ */\n  var FACTORY_HASHES = ${hashesFormatted};\n  /* __FACTORY_HASHES_END__ */`;
  bootloaderRaw = bootloaderRaw.replace(
    /\/\* __FACTORY_HASHES_START__ \*\/[\s\S]*?\/\* __FACTORY_HASHES_END__ \*\//,
    factoryBlock
  );
  fs.writeFileSync(BOOTLOADER_PATH, bootloaderRaw.replace(/\r\n/g, '\n'), 'utf8');

  // 7. Write smart_tv/manifest.json
  const manifest = {
    schemaVersion: 2,
    bootloaderProtocol: 2,
    minBootloaderProtocol: 2,
    version,
    tag: `v${version}`,
    generatedAt: new Date().toISOString(),
    html: htmlEntry,
    styles: styleEntries,
    vendorScripts: vendorEntries,
    scripts: scriptEntries,
    assets: assetEntries,
    files: flatFiles
  };

  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
  console.log(
    `[Manifest v2] Generated smart_tv/manifest.json for v${version} ` +
      `(1 HTML, ${styleEntries.length} CSS, ${vendorEntries.length} vendor JS, ${scriptEntries.length} app JS, ${assetEntries.length} assets).`
  );
}

main();
