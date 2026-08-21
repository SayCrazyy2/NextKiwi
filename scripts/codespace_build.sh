#!/bin/bash
set -ex

# NextKiwi automated build script for GitHub Codespaces
# Usage: bash scripts/codespace_build.sh [--incremental]
#   --incremental: skip Chromium fetch if source already exists

export PATH="$PATH:/workspaces/depot_tools"
export GCLIENT_SUPPRESS_GIT_VERSION_WARNING=1

CHROMIUM_VERSION="140.0.7339.264"
WORKSPACE="/workspaces"
REPO_DIR="$WORKSPACE/NextKiwi"
CHROMIUM_DIR="$WORKSPACE/chromium"
SRC_DIR="$CHROMIUM_DIR/src"
OUT_DIR="$SRC_DIR/out/android_arm64"

INCREMENTAL=false
if [ "$1" == "--incremental" ]; then
  INCREMENTAL=true
fi

echo "=== NextKiwi Build Script ==="
echo "Chromium version: $CHROMIUM_VERSION"
echo "Incremental: $INCREMENTAL"
echo "Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""

# Step 1: Fetch Chromium source (skip if incremental and source exists)
if [ "$INCREMENTAL" = true ] && [ -d "$SRC_DIR/.git" ]; then
  echo "[1/6] Chromium source already exists, skipping fetch (incremental mode)"
else
  echo "[1/6] Fetching Chromium $CHROMIUM_VERSION source..."
  mkdir -p $CHROMIUM_DIR
  cd $CHROMIUM_DIR
  
  cat > .gclient << 'GCLIENT'
solutions = [
  { "name"        : 'src',
    "url"         : 'https://chromium.googlesource.com/chromium/src.git',
    "deps_file"   : 'DEPS',
    "managed"     : False,
    "custom_deps" : {},
    "custom_vars": {},
  },
]
target_os = ["android"]
GCLIENT
  
  gclient sync --revision $CHROMIUM_VERSION --no-history --nohooks
  gclient runhooks
  echo "Chromium source fetched: $(du -sh $SRC_DIR)"
fi

# Step 2: Apply NextKiwi patches
echo ""
echo "[2/6] Applying NextKiwi patches..."
cd $SRC_DIR
git checkout . 2>/dev/null || true
git clean -fd 2>/dev/null || true

# Apply the BUILD.gn assertion fix patch
if [ -f "$REPO_DIR/patches/chromium140_buildfixes.patch" ]; then
  git apply "$REPO_DIR/patches/chromium140_buildfixes.patch" || true
fi

# Copy Kiwi-specific overlay files
OVERLAY_FILE="$REPO_DIR/patches/kiwi_overlay_files.txt"
if [ -f "$OVERLAY_FILE" ]; then
  while IFS= read -r file; do
    src="$REPO_DIR/$file"
    dst="$SRC_DIR/$file"
    if [ -f "$src" ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
  done < "$OVERLAY_FILE"
else
  # If no overlay list, copy all Kiwi-specific files from the repo
  rsync -avz --exclude='.git' --exclude='.github' --exclude='.build' \
    --exclude='.devcontainer' --exclude='BUILDING.md' --exclude='NEXTKIWI_VERSION' \
    --exclude='CHROMIUM_VERSION' --exclude='fetch_from_upstream.sh' \
    --exclude='kiwi_logo_circle.svg' --exclude='LICENSE' --exclude='VERSION' \
    --exclude='.gitignore' --exclude='patches' --exclude='scripts' \
    --exclude='README.md' --exclude='CODESPACES' \
    $REPO_DIR/ $SRC_DIR/
fi

# Fix deprecated includes for Chromium 140
for f in $(find $SRC_DIR/net/http/http_network_transaction.cc $SRC_DIR/components/search/search_url_fetcher.cc $SRC_DIR/components/search/search_url_fetcher.h 2>/dev/null); do
  if [ -f "$f" ]; then
    sed -i 's#include "base/bind.h"#include "base/functional/bind.h"#' "$f" 2>/dev/null || true
    sed -i 's#include "base/callback.h"#include "base/functional/callback.h"#' "$f" 2>/dev/null || true
    sed -i 's#include "base/callback_helpers.h"#include "base/functional/callback_helpers.h"#' "$f" 2>/dev/null || true
  fi
done

echo "Patches applied"

# Step 3: Apply the http_network_transaction.cc fix
echo ""
echo "[3/6] Applying API compatibility fixes..."
HTTP_NT="$SRC_DIR/net/http/http_network_transaction.cc"

# Check if the GetResponseHeaders function needs the Kiwi CORS fix
if grep -q "return response_.headers.get();" "$HTTP_NT" && ! grep -q "X-NextKiwi-Processed" "$HTTP_NT"; then
  python3 -c "
import re
with open('$HTTP_NT', 'r') as f:
    content = f.read()
old = '''HttpResponseHeaders* HttpNetworkTransaction::GetResponseHeaders() const {
  return response_.headers.get();
}'''
new = '''HttpResponseHeaders* HttpNetworkTransaction::GetResponseHeaders() const {
  if (request_ != NULL
      && (GetHostAndOptionalPort(request_->url) == \"news.google.com\" || GetHostAndOptionalPort(request_->url) == \"consent.google.com\" || GetHostAndOptionalPort(request_->url) == \"d3ward.github.io\"))
  {
     if (response_.headers && !response_.headers->GetNormalizedHeader(\"Access-Control-Allow-Origin\").has_value())
       response_.headers->AddHeader(\"Access-Control-Allow-Origin\", \"chrome-search://local-ntp\");
     if (response_.headers && !response_.headers->GetNormalizedHeader(\"Access-Control-Expose-Headers\").has_value())
       response_.headers->AddHeader(\"Access-Control-Expose-Headers\", \"chrome-search://local-ntp\");
     if (response_.headers && !response_.headers->GetNormalizedHeader(\"Access-Control-Allow-Credentials\").has_value())
       response_.headers->AddHeader(\"Access-Control-Allow-Credentials\", \"true\");
     if (response_.headers && !response_.headers->GetNormalizedHeader(\"X-NextKiwi-Processed\").has_value())
       response_.headers->AddHeader(\"X-NextKiwi-Processed\", \"Yes\");
  }
  return response_.headers.get();
}'''
content = content.replace(old, new)
with open('$HTTP_NT', 'w') as f:
    f.write(content)
print('Applied CORS fix to http_network_transaction.cc')
"
fi

echo "API fixes applied"

# Step 4: Configure build
echo ""
echo "[4/6] Configuring build (gn gen)..."
mkdir -p $OUT_DIR

cat > $OUT_DIR/args.gn << 'ARGS'
target_os = "android"
target_cpu = "arm64"
is_debug = false
is_java_debug = false

android_channel = "dev"
is_official_build = false
is_component_build = false
is_chrome_branded = false
is_clang = true
symbol_level = 1
exclude_unwind_tables = false

use_unofficial_version_number = false
android_default_version_code = "2608212"
android_keystore_name = "dev"
android_keystore_password = "public_password"
android_keystore_path = "../../keystore.jks"
android_default_version_name = "140.0.7339.264"

fieldtrial_testing_like_official_build = true
icu_use_data_file = false
enable_iterator_debugging = false

google_api_key = "NEXTKIWI"
google_default_client_id = "42.apps.nextkiwi.com"
google_default_client_secret = "NEXTKIWI_NOT_SO_SECRET"
use_official_google_api_keys = false

ffmpeg_branding = "Chrome"
proprietary_codecs = true
enable_widevine = true
enable_mse_mpeg2ts_stream_parser = true
enable_remoting = false
rtc_use_h264 = false

v8_use_external_startup_data = true
update_android_aar_prebuilts = true

enable_extensions = false
enable_desktop_android_extensions = true
enable_guest_view = true
is_desktop_android = true
enable_pdf = false
enable_plugins = false

disable_android_lint = true
treat_warnings_as_errors = false

cc_wrapper = "ccache"
ARGS

# Generate signing keystore
if [ ! -f "$CHROMIUM_DIR/keystore.jks" ]; then
  keytool -genkey -v -keystore $CHROMIUM_DIR/keystore.jks -alias dev \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass public_password -keypass public_password \
    -dname "cn=NextKiwi, ou=Build, o=NextKiwi, c=GitHub"
fi
cp $CHROMIUM_DIR/keystore.jks $SRC_DIR/keystore.jks 2>/dev/null || true

gn gen $OUT_DIR

# Step 5: Build
echo ""
echo "[5/6] Building NextKiwi APK (this will take 2-4 hours on 16 cores)..."
echo "Started at: $(date)"
START_TIME=$SECONDS

autoninja -C $OUT_DIR -j$(nproc) chrome_public_apk 2>&1 | tail -50

ELAPSED=$(($SECONDS - $START_TIME))
echo "Build completed in $((ELAPSED/60)) minutes"

# Step 6: Verify and copy APK
echo ""
echo "[6/6] Locating built APK..."
APK=$(find $OUT_DIR -name "ChromePublic.apk" -o -name "*.apk" 2>/dev/null | head -1)
if [ -n "$APK" ]; then
  echo "SUCCESS! APK found at: $APK"
  cp "$APK" "$REPO_DIR/NextKiwi-arm64.apk"
  echo "Copied to: $REPO_DIR/NextKiwi-arm64.apk"
  ls -lh "$REPO_DIR/NextKiwi-arm64.apk"
else
  echo "ERROR: APK not found. Check build logs."
  exit 1
fi