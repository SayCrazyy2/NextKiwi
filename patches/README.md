# NextKiwi Build Patches for Chromium 140

These patches fix build assertion errors when enabling extensions on Android (via `enable_desktop_android_extensions` and `is_desktop_android`).

## Patches

### chromium140_buildfixes.patch
Fixes BUILD.gn assertion failures in:
- `components/guest_view/renderer/BUILD.gn` — allow guest views on Android for extension support
- `extensions/browser/guest_view/web_view/web_ui/BUILD.gn` — allow web_ui when `enable_desktop_android_extensions` is true

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
```