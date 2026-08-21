# NextKiwi Build Patches for Chromium 140

These patches fix build errors and add Kiwi-specific features when building against Chromium 140.

## Patches

### chromium140_buildfixes.patch
Fixes BUILD.gn assertion failures for Android extensions support:
- `components/guest_view/renderer/BUILD.gn` — allow guest views on Android
- `extensions/browser/guest_view/web_view/web_ui/BUILD.gn` — allow web_ui with desktop android extensions

### http_network_transaction_cors_fix.patch
Adds CORS headers for Google News/Consent and X-NextKiwi-Processed header to response headers.
Based on Kiwi's original modification, adapted for Chromium 140 API changes (GetNormalizedHeader returns std::optional).

### kiwi_overlay_files.txt
List of 188 files that are Kiwi-specific additions/modifications to be overlaid onto the Chromium source.
These include icons, Java classes, resources, and Kiwi feature code.

## Key args.gn settings for Android extensions on Chromium 140:
```
enable_extensions = false
enable_desktop_android_extensions = true
enable_guest_view = true
is_desktop_android = true
is_official_build = false  # PGO profiles not available in --no-history sync
```

## Applying patches:
```bash
cd /path/to/chromium/src
git apply /path/to/NextKiwi/patches/chromium140_buildfixes.patch
git apply /path/to/NextKiwi/patches/http_network_transaction_cors_fix.patch
```

## Full build (in GitHub Codespace):
```bash
bash scripts/codespace_build.sh
```

## Incremental build (if Chromium source already fetched):
```bash
bash scripts/codespace_build.sh --incremental
```