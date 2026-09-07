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
- **Decommissioning apps**: Move app config files to `applications/<stack>/apps-disabled/` instead of deleting them. Remove associated manifests and clean up references from other configs (e.g., `allow_from` in `homedb.yaml`).

### 2. YAML Conventions
- Use 2-space indentation.
- Ensure `apiVersion` and `kind` are at the top.
- For Argo CD `Application` resources, ensure `syncPolicy` has `prune: true` (auto-cleans resources removed from the repo) and `selfHeal: true`.

### 3. Helm Chart: `homelab-application`
- This chart is the source of truth for deployments. If a new feature (like a specific annotation) is needed for all apps, add it to the chart templates rather than individual config files.

### 4. Alert Handling & Remediation Policy
- **Memory Alerts**:
  - By default, do NOT increase `resources.requests.memory` or limits in application YAMLs when an alert fires.
  - The standard procedure is to restart the pod (`kubectl rollout restart deployment/<app> -n <namespace>`) to release leaked or cached memory.
  - Only consider increasing requests/limits via GitOps if the issue is highly recurrent (i.e. repeated restarts fail to stabilize memory and it immediately breaches again).
- **Grafana Alert Labels**:
  - All Crossplane alert rules (`applications/monitors/configs/*.yaml`) must include `labels.resolver`:
    - `resolver: agent`: Alerts that can and should be remediated automatically by an agent following standard diagnostics and commands.
    - `resolver: human`: Alerts requiring manual review, subjective decisions, or physical intervention.

## 🤖 AI Instructions
- When adding a new app, check if it fits the `homelab-application` schema.
- Always prefer `ApplicationSet` generators for scaling similar deployments.
- If modifying `AppProjects`, ensure `destinations` and `namespaceResourceWhitelist` are correctly scoped to maintain security boundaries.
