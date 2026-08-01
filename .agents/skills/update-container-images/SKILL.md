---
name: update-container-images
description: TRIGGER this skill when checking for image updates or updating container image tags in application YAML files (e.g., in applications/homeflix/apps, applications/homelab/apps, applications/devops/apps) using check-updates.py / Renovate CLI.
---

# Checking and Updating Container Image Tags

This guide outlines the standard workflow for inspecting and updating container image tags in GitOps application manifests (`applications/<stack>/apps/*.yaml`) using `check-updates.py` and Renovate CLI.

---

## Workflow Steps

### 1. Synchronize Git Repository
Always pull the latest changes before making modifications:
```bash
git pull
```

### 2. Prepare Apps with `latest` Tag (Force Renovate Version Lookup)
In `renovate.json`, updates for images using `tag: latest` are ignored by rule.
To force Renovate to look up and report the latest release version for apps configured with `tag: latest`, update their tag to `tag: 0.0.0` before running the lookup:
- Replace `tag: latest` (or `tag: "latest"`) with `tag: 0.0.0` in the target application YAML file(s).

### 3. Inspect Pending Updates
Run the update checker script:
```bash
python3 check-updates.py
```
To view all images (including those already up to date):
```bash
python3 check-updates.py --all
```

The script executes Renovate in local lookup mode (`npx -y renovate --platform=local --dry-run=lookup`) and outputs a table listing pending image updates per application file.

### 4. Determine Target Versions
- Renovate categorizes updates by type (e.g., `minor: 0.9.10, major: 1.6.0`).
- Select the highest available version for each application unless instructed otherwise.
- If only a specific stack is requested (e.g. `applications/homeflix/apps`), update only matching YAML files.

### 5. Update Application YAML Files
In each target file (`applications/<stack>/apps/<app>.yaml`), update the `tag:` field with the resolved version:
```yaml
name: my-app
image: lscr.io/linuxserver/my-app
tag: 1.6.0  # ← Update tag value from 0.0.0 (or old tag) to the target release tag
```

**Notes:**
- Maintain standard 2-space indentation.
- Match existing tag syntax (e.g., `tag: 1.6.0` or `tag: v2.3.0`).

### 6. Verification
Re-run the update checker script to confirm that targeted applications are now reported as up to date:
```bash
python3 check-updates.py
```

### 7. Git Confirmation
- Summarize all modified application files and their new tags for the user.
- **Rule**: Never commit or push to Git without explicit user confirmation.
