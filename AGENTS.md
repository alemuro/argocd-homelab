# AGENTS.md

Guidelines for AI Agents and developers working on this repository.

## 🛠 Technical Stack
- **Argo CD**: GitOps controller.
- **Helm**: Local charts for standardizing deployments.
- **Kubernetes**: Target orchestration.

## 📜 Development Rules

### 0. Synchronization
- **Always run `git pull` before making any changes** to ensure the local repository is synchronized with the remote.

### 1. Project Organization
- **Don't hardcode standard resources**: Use the `helm/homelab-application` chart for generic deployments instead of writing raw Kubernetes manifests.
- **Use the Config Pattern**: For the `homeflix` stack, always add new applications as value files in `applications/homeflix/configs/`.

### 2. YAML Conventions
- Use 2-space indentation.
- Ensure `apiVersion` and `kind` are at the top.
- For Argo CD `Application` resources, ensure `syncPolicy` has `prune: false` (to prevent accidental deletions) and `selfHeal: true`.

### 3. Helm Chart: `homelab-application`
- This chart is the source of truth for deployments. If a new feature (like a specific annotation) is needed for all apps, add it to the chart templates rather than individual config files.

## 🤖 AI Instructions
- When adding a new app, check if it fits the `homelab-application` schema.
- Always prefer `ApplicationSet` generators for scaling similar deployments.
- If modifying `AppProjects`, ensure `destinations` and `namespaceResourceWhitelist` are correctly scoped to maintain security boundaries.
