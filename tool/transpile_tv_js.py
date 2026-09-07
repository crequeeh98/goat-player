import os
import sys
import subprocess
import re

def transpile_directory(staging_dir, target='chrome68'):
    if not os.path.exists(staging_dir):
        print(f"Directory not found: {staging_dir}")
        return 1

    # 1. Transform CanvasKit JS files into standard IIFE bundles (removes ES module syntax)
    canvaskit_dir = os.path.join(staging_dir, 'canvaskit')
    if os.path.exists(canvaskit_dir):
        print("Transforming CanvasKit scripts into standard non-module IIFE bundles...")
        for root, _, files in os.walk(canvaskit_dir):
            for f in files:
                if f.endswith('.js'):
                    ck_path = os.path.join(root, f)
                    cmd = f'npx -y esbuild "{ck_path}" --format=iife --global-name=CanvasKitInit --target={target} --allow-overwrite --outfile="{ck_path}"'
                    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                    if res.returncode != 0:
                        print(f"Warning on {ck_path}: {res.stderr.strip()}", file=sys.stderr)
                    else:
                        print(f"  [CanvasKit IIFE OK] {os.path.relpath(ck_path, staging_dir)}")
                        with open(ck_path, 'r', encoding='utf-8') as fh:
                            content = fh.read()
                        
                        content = content.replace(
                            'const import_meta = {};',
                            'const import_meta = { url: (typeof document !== "undefined" && document.baseURI) || "" };'
                        )
                        append_str = """
if (typeof window !== "undefined") {
    window.CanvasKitInit = CanvasKitInit;
    if (window.CanvasKitInit && window.CanvasKitInit.default) {
        window.CanvasKitInit.default.default = window.CanvasKitInit.default;
    }
}
if (typeof self !== "undefined") {
    self.CanvasKitInit = CanvasKitInit;
}
"""
                        content += append_str
                        with open(ck_path, 'w', encoding='utf-8') as fh:
                            fh.write(content)

    # 2. Down-level all other JS files (loaders, plugins, service workers, etc.)
    js_files = []
    for root, _, files in os.walk(staging_dir):
        if 'canvaskit' in root:
            continue
        for f in files:
            if f.endswith('.js') and not f.startswith('main.dart'):
                js_files.append(os.path.join(root, f))

    print(f"Down-leveling {len(js_files)} JS loader & plugin files for TV compatibility (target={target})...")
    for js_path in js_files:
        cmd = f'npx -y esbuild "{js_path}" --target={target} --allow-overwrite --outfile="{js_path}"'
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Warning on {js_path}: {res.stderr.strip()}", file=sys.stderr)
        else:
            print(f"  [OK] {os.path.relpath(js_path, staging_dir)}")

    # 3. Patch dynamic module import & WebAssembly streaming compilation in flutter_bootstrap.js and flutter.js
    for fname in ['flutter_bootstrap.js', 'flutter.js']:
        fpath = os.path.join(staging_dir, fname)
        if os.path.exists(fpath):
            with open(fpath, 'r', encoding='utf-8') as fh:
                code = fh.read()
            
            # Replace dynamic import(a)
            code = code.replace(
                'await import(a)',
                'await (window.CanvasKitInit ? Promise.resolve(window.CanvasKitInit.default ? window.CanvasKitInit : {default: window.CanvasKitInit}) : window._tvImportModule(a))'
            )
            # Replace WebAssembly.compileStreaming(o()) with fallback to compile(arrayBuffer)
            code = code.replace(
                'WebAssembly.compileStreaming(o())',
                '(async () => { try { if (WebAssembly.compileStreaming) return await WebAssembly.compileStreaming(o()); } catch(e){} let _r = await o(); let _b = await _r.arrayBuffer(); return await WebAssembly.compile(_b); })()'
            )
            # Add bootstrap diagnostic logs
            code = code.replace(
                'a.initializeEngine(t).then((l) => l.runApp());',
                '(console.log("Initializing Flutter engine..."), a.initializeEngine(t).then((l) => (console.log("Engine ready, launching runApp()..."), l.runApp())));'
            )
            with open(fpath, 'w', encoding='utf-8') as fh:
                fh.write(code)
            print(f"  [Patched dynamic import & WASM fallback & logs] {fname}")

    # 4. Patch dynamic import in main.dart.js
    main_dart_path = os.path.join(staging_dir, 'main.dart.js')
    if os.path.exists(main_dart_path):
        with open(main_dart_path, 'r', encoding='utf-8') as fh:
            dart_code = fh.read()
        
        replacement = '(window.CanvasKitInit ? Promise.resolve(window.CanvasKitInit.default ? window.CanvasKitInit : {default: window.CanvasKitInit}) : window._tvImportModule(A.bPF(p.toString())))'
        if 'import(A.bPF(p.toString()))' in dart_code:
            dart_code = dart_code.replace('import(A.bPF(p.toString()))', replacement)
            print("  [Patched import(A.bPF(p.toString())) in main.dart.js]")
        else:
            # Fallback regex pattern
            dart_code, count = re.subn(
                r'\bimport\((.*?p\.toString\(\))\)',
                r'(window.CanvasKitInit ? Promise.resolve(window.CanvasKitInit.default ? window.CanvasKitInit : {default: window.CanvasKitInit}) : window._tvImportModule(\1))',
                dart_code
            )
        # Patch Chromium < 72 Node.prototype.contains(a1) where a1 is window or non-Node
        if 'd.e.contains(a1)' in dart_code:
            dart_code = dart_code.replace('d.e.contains(a1)', '(a1 && a1.nodeType && d.e.contains(a1))')
            print("  [Patched d.e.contains(a1) in main.dart.js]")

        with open(main_dart_path, 'w', encoding='utf-8') as fh:
            fh.write(dart_code)

    # 5. Inject <script src="canvaskit/canvaskit.js"></script> in staging index.html
    index_path = os.path.join(staging_dir, 'index.html')
    if os.path.exists(index_path):
        with open(index_path, 'r', encoding='utf-8') as fh:
            index_code = fh.read()
        
        if 'canvaskit/canvaskit.js' not in index_code:
            index_code = index_code.replace(
                '<script src="flutter_bootstrap.js" async></script>',
                '<script src="canvaskit/canvaskit.js"></script>\n  <script src="flutter_bootstrap.js" async></script>'
            )
            with open(index_path, 'w', encoding='utf-8') as fh:
                fh.write(index_code)
            print("  [Injected canvaskit/canvaskit.js script tag in staging index.html]")

    print("All TV JS scripts and modules successfully prepared for file:// execution!")
    return 0

if __name__ == '__main__':
    target_dir = sys.argv[1] if len(sys.argv) > 1 else 'build/webos_staging'
    sys.exit(transpile_directory(target_dir))
