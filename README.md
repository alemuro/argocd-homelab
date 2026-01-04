# Homelab Infrastructure (Argo CD)

This repository manages the infrastructure and applications of my homelab using GitOps with Argo CD.

## 📂 Repository Structure

- **/applications**: Argo CD Application and ApplicationSet definitions.
  - **/platform**: Core system components (Sealed Secrets, Argo CD Image Updater).
  - **/homeflix**: Media stack applications.
    - `stack.yaml`: ApplicationSet that dynamically deploys apps from the `configs/` folder.
    - `/configs`: YAML files containing values for each application (e.g., `radarr.yaml`, `sonarr.yaml`).
- **/helm**: Local Helm charts.
  - `homelab-application`: A generic wrapper chart for homelab apps (Deployment, Service, Ingress, NetworkPolicy).
- **/settings**: Global Argo CD configurations.
  - `projects.yaml`: AppProject definitions (homeflix, platform, argocd).
  - `config.yaml`: Main bootstrap configurations.

## 🚀 How to Add a New Application (Homeflix)

The Homeflix stack uses the **Git File Generator** pattern. To deploy a new app:

1. Create a new YAML file in `applications/homeflix/configs/<app-name>.yaml`.
2. Populate it with the required values for the `homelab-application` chart:
   ```yaml
   name: my-app
   image: my-repo/my-image
   tag: latest
   port: 8080
   domains:
     - my-app.aleix.cloud
   mount:
     /path/on/host: /path/in/container
   allow_from:
     - ingress-controller
   ```
3. Commit and push. Argo CD will automatically detect the file and create a new Application.

## 🛠 Features

- **Automated Image Updates**: Managed by `argocd-image-updater` for platform components.
- **Simplified Networking**: `homelab-application` chart automatically handles Ingress and NetworkPolicies.
- **Sealed Secrets**: Secrets are encrypted and safe to store in Git.
