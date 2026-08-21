# Building NextKiwi in GitHub Codespaces

## Prerequisites

Your GitHub account needs:
- **GitHub Pro** ($4/month) for 180 core-hours and more storage, OR
- **GitHub Free** (120 core-hours) — but you'll need to pay for extra storage

A 16-core Codespace uses 16 core-hours/hour, so the free 120 hours = ~7.5 hours of build time.

## Storage requirements

Chromium source is ~100 GB, build output ~50 GB. You need at least 200 GB storage.
- Free tier: 15 GB (not enough)
- Additional storage: $0.07/GB/month (~$14 for 200 GB, can delete after build)

## Steps

1. Go to https://github.com/codespaces/new
2. Select the **SayCrazyy2/NextKiwi** repository
3. Choose the **nextkiwi** branch
4. Click **Create codespace** — this will use the devcontainer config (16 cores, 64 GB RAM, 200 GB storage)

Wait for the setup script to finish (installs JDK, ninja, ccache, depot_tools, swap).

5. Once the Codespace is ready, run:
```bash
bash scripts/codespace_build.sh
```

6. The script will:
   - Fetch Chromium 140 source (~30-60 min)
   - Apply NextKiwi patches
   - Configure the build
   - Compile the APK (2-4 hours on 16 cores)

7. When done, the APK will be at `NextKiwi-arm64.apk` in the repo directory.

8. Download it from the Codespace file explorer, or use:
```bash
# Sign the APK (if not already signed)
keytool -genkey -v -keystore nextkiwi.jks -alias nextkiwi \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass nextkiwi -keypass nextkiwi \
  -dname "cn=NextKiwi, ou=Build, o=NextKiwi"
```

## Tips

- For incremental builds (if the Codespace is still alive):
  ```bash
  bash scripts/codespace_build.sh --incremental
  ```
- Monitor build progress:
  ```bash
  tail -f /workspaces/chromium/src/out/android_arm64/build.log
  ```
- If you hit storage limits, clean up:
  ```bash
  rm -rf /workspaces/chromium/src/out/android_arm64/obj
  ccache --clear
  ```

## Cost estimate

- 16-core Codespace for 4 hours: ~$11.52 (compute)
- 200 GB storage for 1 month: ~$14 (delete when done to stop charges)
- **Total for one build: ~$25**