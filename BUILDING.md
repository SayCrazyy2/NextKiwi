# Building NextKiwi

This document describes how to build NextKiwi Browser from source.

## Prerequisites

### Build machine requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU      | 4 cores | 16+ cores   |
| RAM      | 16 GB + 32 GB swap | 64 GB       |
| Disk     | 200 GB  | 500 GB SSD  |
| OS       | Ubuntu 22.04+ | Ubuntu 24.04 |

> **Note**: Building Chromium on a 4-core/16 GB machine is possible but very slow (1–2 days per build). The 32 GB swap file is critical to avoid OOM during linking.

### Software dependencies

```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk-headless ninja-build ccache pkg-config \
    git-lfs curl ca-certificates python3 dh-python lsb-release tzdata \
    build-essential
```

### depot_tools

```bash
git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PATH:$(pwd)/depot_tools"
```

Add the PATH export to your `~/.bashrc` or `/etc/profile.d/depot_tools.sh` for persistence.

## Building

### 1. Fetch Chromium source

NextKiwi uses a patch overlay on top of the Chromium source. The full Chromium source (~100 GB) must be fetched separately:

```bash
# Create the build directory structure
mkdir -p /root/nkiwi/chromium
cd /root/nkiwi/chromium

# Configure gclient
gclient config https://chromium.googlesource.com/chromium/src.git

# Fetch the source (this takes 4-8 hours)
# Replace the version with your target Chromium version
gclient sync --revision 140.0.0.0 --no-history --no-hooks
gclient runhooks
```

### 2. Apply NextKiwi patches

```bash
# Copy the NextKiwi patch overlay onto the Chromium source
rsync -avz --exclude='.git' --exclude='.github' --exclude='.build' \
    /root/nkiwi/src.next/ /root/nkiwi/chromium/src/

# Resolve any conflicts manually
cd /root/nkiwi/chromium/src
git add -A
git commit -m "Apply NextKiwi patches"
```

### 3. Configure the build

```bash
cd /root/nkiwi/chromium/src

# Create build output directory
mkdir -p out/android_arm64

# Copy and modify args.gn
cp .build/production_build_reference/args.gn out/android_arm64/args.gn

# Update version code (format: YYMMDDx where x is arch index)
sed -i "s/android_default_version_code = \"1\"/android_default_version_code = \"$(date '+%y%m%d')2\"/" out/android_arm64/args.gn
sed -i "s/android_default_version_name = \"Git\"/android_default_version_name = \"140.0.0.1\"/" out/android_arm64/args.gn
```

### 4. Generate and build

```bash
# Generate build files
gn gen out/android_arm64

# Build the APK (this takes 1-2 days on a 4-core machine)
ninja -C out/android_arm64 chrome_public_apk

# The output APK will be at:
# out/android_arm64/apks/ChromePublic.apk
```

### 5. Sign the APK

```bash
# Generate a keystore (one-time)
keytool -genkey -v -keystore nextkiwi.jks -alias nextkiwi \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass nextkiwi_password -keypass nextkiwi_password \
    -dname "cn=NextKiwi, ou=Build, o=NextKiwi, c=GitHub"

# Sign the APK
cd out/android_arm64/apks
zipalign -p 4 ChromePublic.apk NextKiwi-aligned.apk
apksigner sign --ks /path/to/nextkiwi.jks \
    --ks-key-alias nextkiwi \
    --ks-pass pass:nextkiwi_password \
    --key-pass pass:nextkiwi_password \
    --out NextKiwi-arm64.apk \
    NextKiwi-aligned.apk
```

## Self-hosted GitHub Actions runner

NextKiwi uses a self-hosted runner for CI builds. To set up:

1. Go to **Settings → Actions → Runners → New self-hosted runner** in the repository.
2. Follow the instructions to install the runner on your build machine.
3. Install as a systemd service:
   ```bash
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```
4. Label the runner with `self-hosted` and `linux` (done by default).

## Architecture targets

| Target | Command | Notes |
|--------|---------|-------|
| arm64  | `target_cpu = "arm64"` | Modern devices, best performance |
| arm    | `target_cpu = "arm"` | Older devices, lower memory |
| x86    | `target_cpu = "x86"` | Emulators |
| x64    | `target_cpu = "x64"` | Intel tablets, emulators |

## Troubleshooting

### Out of memory during linking
- Increase swap: `sudo fallocate -l 64G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
- Build with `link_script_launcher.py` to reduce peak memory
- Use `target_cpu = "arm"` (smaller binary, less memory)

### Disk space
- Cap ccache: `ccache --max-size 20G`
- Clean build artifacts: `ninja -C out/android_arm64 -t clean`
- Use `--no-history` when fetching Chromium source