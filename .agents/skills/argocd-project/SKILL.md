---
name: argocd-project
description: TRIGGER this skill when working in the argocd-homelab repository — adding, disabling, or modifying applications; using the homelab-application Helm chart; understanding ApplicationSet generators, stack.yaml structure, SealedSecrets management, or the project directory layout. Covers GitOps conventions, app lifecycle, Helm chart values, and sync policies. Use ONLY when operating on this project.
---

# ArgoCD Homelab Project Guide

This repository manages homelab infrastructure via Argo CD GitOps. Below are the conventions, directory layout, and workflows for managing applications.

---

## 1. Architecture Overview

### Directory structure

```
argocd-homelab/
├── applications/           # Argo CD Applications + ApplicationSets
│   ├── homeflix/           # Media stack (plex, sonarr, radarr, etc.)
│   │   ├── stack.yaml      # ApplicationSet (Git file generator)
│   │   ├── apps/           # Active app value files → *.yaml
│   │   ├── apps-disabled/  # Decommissioned app value files
│   │   └── manifests/      # SealedSecrets and extra K8s resources
│   ├── homelab/            # Core infrastructure stack
│   │   ├── stack.yaml
│   │   ├── apps/
│   │   ├── apps-disabled/
│   │   ├── manifests/
│   │   └── argocd.yaml     # Raw Application for ArgoCD itself (not in apps/)
│   ├── devops/             # DevOps tools (forgejo, etc.)
│   │   └── stack.yaml
│   ├── platform/           # System components (sealed-secrets, image-updater)
│   ├── ingress/            # Cloudflare tunnels
│   │   └── tunnels/
│   ├── hetzner/            # Apps on Hetzner infra
│   └── other/              # Miscellaneous
├── helm/                   # Local Helm charts
│   ├── homelab-application/  # Generic wrapper chart (Deployment, Service, Ingress, etc.)
│   └── nubulus-tunnel/       # Tunnel chart
├── settings/               # Global Argo CD config
│   ├── config.yaml         # Bootstrap ApplicationSet (scans all stack dirs)
│   ├── projects.yaml       # AppProject definitions
│   └── argocd/             # SealedSecrets for repo credentials
└── AGENTS.md               # AI agent guidelines for this repo
```

### Stack → Namespace → Project mapping

| Stack dir | ArgoCD Project | K8s Namespace | ApplicationSet pattern |
|-----------|---------------|---------------|----------------------|
| `applications/homeflix/` | `homeflix` | `homeflix` | Git file generator → `apps/*.yaml` |
| `applications/homelab/` | `homelab` | `homelab` | Git file generator → `apps/*.yaml` |
| `applications/devops/` | `devops` | `devops` | Git file generator → `apps/*.yaml` |
| `applications/platform/` | `platform` | varies (sealed-secrets, etc.) | Raw Application manifests |
| `applications/ingress/` | `ingress` | `ingress` | Raw manifests in `tunnels/` |
| `applications/other/` | `argocd` | varies | Raw manifests |
| `applications/hetzner/` | (varies) | (varies) | Raw manifests |

### How ApplicationSets work

Each stack's `stack.yaml` is an **ApplicationSet** with a **Git file generator** that scans `apps/*.yaml` and creates one ArgoCD Application per file. The YAML file contents are passed directly as Helm values to the `helm/homelab-application` chart:

```yaml
# applications/homeflix/stack.yaml (simplified)
spec:
  generators:
    - git:
        repoURL: ssh://git@github.com/alemuro/argocd-homelab.git
        revision: HEAD
        files:
          - path: "applications/homeflix/apps/*.yaml"
  template:
    spec:
      source:
        path: helm/homelab-application
        helm:
          values: |
            {{- toYaml . | nindent 12 }}
```

Key details:
- Apps are **named** from the `name:` field in their YAML, prefixed by the stack (e.g. `homeflix-plex`)
- The `metadata.name` comes from the ApplicationSet template: `homeflix-{{.name}}`
- No `argocd` Application resource is created per app — the ApplicationSet manages them
- The `settings/config.yaml` bootstrap ApplicationSet scans all stack folders recursively to ensure they are synced

### When NOT to use the ApplicationSet pattern

Some apps are deployed as standalone `kind: Application` resources instead of going through an ApplicationSet:
- **ArgoCD itself**: `applications/homelab/argocd.yaml` — a raw `Application` using the `argo-cd` Helm chart
- **Platform components**: `applications/platform/sealed-secrets.yaml`, `argocd-image-updater.yaml` — raw `Application` resources using third-party charts
- **Tunnels**: `applications/ingress/tunnels/` — raw K8s manifests deployed directly (not through the homelab-application chart)

Use a raw `Application` resource when the app needs an external Helm chart or custom K8s manifests. Use the ApplicationSet + `apps/*.yaml` pattern when the app fits the `homelab-application` chart schema.

---

## 2. Adding a New Application

### Standard flow (using `homelab-application` chart)

1. **Create a YAML values file** in the appropriate stack's `apps/` directory:

   `applications/<stack>/apps/<app-name>.yaml`

2. **Populate the required values** (see section 4 for full schema reference):

   ```yaml
   name: my-app
   image: some/image
   tag: latest
   port: 8080
   domains:
     - my-app.immaleix.casa
   ```

3. **If the app needs access to a shared resource** (e.g. a database), update the `allow_from` list in the target's config (like `homedb.yaml`):

   ```yaml
   # applications/homelab/apps/homedb.yaml — add the new app
   allow_from:
     - umami
     - n8n
     - my-app           # ← add here
   ```

4. **If the app needs an API key or other secrets**, create a SealedSecret in the stack's `manifests/` directory (see section 5).

### Real example: Plex

```yaml
# applications/homeflix/apps/plex.yaml
name: plex
image: lscr.io/linuxserver/plex
tag: latest
port: 32400
node_selector:
  kubernetes.io/hostname: worker-0
domains:
  - plex.immaleix.casa
pod_additional_ports:
  - name: plex
    container_port: 32400
    host_port: 29400
    protocol: TCP
mount:
  /mnt/local/configs/plex: /config
  /mnt/nfs/homeflix-v2/movies: /movies
  /mnt/nfs/homeflix-v2/tv: /tv
resources:
  requests:
    cpu: 200m
    memory: 768Mi
  limits:
    gpu.intel.com/i915: 1
env:
  PUID: "1000"
  PGID: "1000"
  TZ: "Europe/Madrid"
allow_from:
  - tautulli
  - seerr
```

### Direct Helm chart flow

For apps that use an external Helm chart (not `homelab-application`):

```yaml
# applications/homelab/argocd.yaml — ArgoCD itself
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: argocd
  source:
    chart: argo-cd
    repoURL: https://argoproj.github.io/argo-helm
    targetRevision: '*'
    helm:
      releaseName: argocd
      values: |
        ...
```

`ApplyOutOfSyncOnly=true` is the standard sync option for all apps. Use `prune: false` unless you have a specific reason to allow pruning.

---

## 3. Disabling an Application

To decommission an application:

1. **Move the app values file** from `apps/` to `apps-disabled/`:

   ```
   applications/homeflix/apps/jellyfin.yaml
   → applications/homeflix/apps-disabled/jellyfin.yaml
   ```

2. **Remove associated SealedSecrets** from `manifests/`:

   ```
   applications/homeflix/manifests/jellyfin-secrets.yaml  → delete
   ```

   (SealedSecrets are standalone resources; they don't get disabled, they get deleted.)

3. **Clean up cross-references** in other app configs:

   If the disabled app was in another app's `allow_from` list, remove it:

   ```yaml
   # applications/homelab/apps/homedb.yaml
   allow_from:
     - umami
     - n8n
     # - jellyfin    ← remove this
   ```

4. **Commit and push**. ArgoCD will detect the app is no longer in the `apps/*.yaml` glob and will delete the Application (subject to `prune: false` policy — the K8s resources remain until manually cleaned up).

### Why not just delete?

The `apps-disabled/` directory preserves the config in case the app needs to be re-enabled later. It also serves as documentation of what was previously deployed.

---

## 4. Helm Chart: `homelab-application` Reference

Chart location: `helm/homelab-application/` (local chart, `apiVersion: v2`, version `0.2.0`)

Generates these resources (conditionally):
- **ConfigMap** — if `configmaps` is set
- **Deployment** — always (creates the pod with env, volumes, args, resources)
- **ImageUpdater** — if `image_updater.enabled` is true
- **Ingress** (×2–3) — if `port` + at least one of `domains`/`cloudflare_domains`
- **Middleware** (HTTP→HTTPS redirect) — if `port` + `domains` and `disableHttpRedirect` is not set
- **NetworkPolicy** — if any of `allow_from`, `allow_from_cidrs`, `allow_from_namespaces` is set
- **Service** — if `port` is set

### Values schema

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `name` | string | `""` | **Required.** App name (used for resource names, labels, selectors) |
| `image` | string | `""` | **Required.** Container image (e.g. `lscr.io/linuxserver/plex`) |
| `tag` | string | `"latest"` | Image tag |
| `port` | int | `null` | Container port. If set, generates Service + optionally Ingress |
| `servicePort` | int | `80` | Service port (maps to `containerPort`) |
| `serviceAnnotations` | map | `{}` | Annotations for the Service resource |
| `domains` | string[] | `[]` | Public domains. Generates Ingress (HTTP→HTTPS redirect + TLS) via Traefik + cert-manager |
| `cloudflare_domains` | string[] | `[]` | Domains routed through Cloudflare Tunnel (separate Ingress with `cloudflare-tunnel` class) |
| `disableHttpRedirect` | bool | `false` | If true, skips creating the HTTP→HTTPS Middleware |
| `mount` | map | `{}` | HostPath volumes. Format: `hostPath: mountPath` |
| `configmaps` | map | `{}` | ConfigMap content. Format: `mountPath: \| content`. Each entry becomes a file at the path |
| `resources` | map | `{}` | K8s resource requests/limits (standard K8s format) |
| `allow_from` | string[] | `[]` | App names allowed to reach this app (generates NetworkPolicy Ingress rules selecting `k8s-app` label) |
| `allow_from_cidrs` | string[] | `[]` | CIDR ranges allowed to reach this app |
| `allow_from_namespaces` | string[] | `[]` | Namespace names allowed to reach this app |
| `env` | map | `{PUID: "1000", PGID: "1000", TZ: "Europe/Madrid"}` | Environment variables (plain text) |
| `secretEnv` | map | `{}` | Secret-backed env vars. Format: `ENV_NAME: { secretName: "...", key: "..." }` |
| `args` | string[] | `[]` | Container command arguments |
| `node_selector` | map | `{}` | Node selector labels (prefer this over `nodeSelector`) |
| `nodeSelector` | map | `{}` | Alternate node selector (kept for backward compat) |
| `imagePullSecrets` | array | `[]` | Image pull secret references |
| `pod_additional_ports` | object[] | — | Extra container ports. Each has: `name`, `container_port`, optional `host_port`, optional `protocol` (default TCP) |
| `image_updater` | object | — | Auto-update config. Format: `{ enabled: bool, strategy: "semver", allow_tags: "v*" }` |

### Environment variables note

The chart sets `PUID: "1000"`, `PGID: "1000"`, and `TZ: "Europe/Madrid"` by default. If you override `env:` in your app config, you MUST include these explicitly or they will be lost:

```yaml
env:
  PUID: "1000"
  PGID: "1000"
  TZ: "Europe/Madrid"
  MY_CUSTOM_VAR: "value"
```

### Usage examples

**Minimal app** (just a Deployment, no Ingress):
```yaml
name: my-daemon
image: alpine
tag: "3.19"
args:
  - sleep
  - infinity
```

**App with Ingress + secrets**:
```yaml
name: openbao
image: ghcr.io/openbao/openbao
port: 8200
domains:
  - openbao.immaleix.casa
node_selector:
  kubernetes.io/hostname: worker-1
mount:
  /mnt/local/configs/openbao: /openbao/data
configmaps:
  /openbao/config.hcl: |
    ui     = true
    listener "tcp" {
      tls_disable = true
      address     = "0.0.0.0:8200"
    }
args:
  - server
  - -config=/openbao/config.hcl
```

**App with additional port** (host networking bypass):
```yaml
name: plex
image: lscr.io/linuxserver/plex
port: 32400
pod_additional_ports:
  - name: plex
    container_port: 32400
    host_port: 29400     # Bypasses Cilium NodePort range
    protocol: TCP
```

---

## 5. SealedSecrets

SealedSecrets are encrypted Kubernetes Secrets stored in Git. They live in `manifests/` directories under each stack:

```
applications/<stack>/manifests/<app>-secrets.yaml
```

### How they work

1. The `bitnami/sealed-secrets` controller (deployed via `applications/platform/sealed-secrets.yaml`) runs in the cluster
2. You encrypt a secret using `kubeseal`, producing a `SealedSecret` resource
3. The SealedSecret is committed to Git (safe because only the cluster controller can decrypt it)
4. The controller decrypts it into a regular `Secret` in the namespace

### Adding a new SealedSecret

1. **Create the secret locally** (do NOT commit this):
   ```bash
   kubectl create secret generic my-app-creds \
     --namespace homeflix \
     --dry-run=client \
     --from-literal=API_KEY=supersecret \
     -o json > /tmp/my-app-creds.json
   ```

2. **Seal it** (replace the controller name and namespace with your cluster's values):
   ```bash
   kubeseal --controller-name=sealed-secrets \
     --controller-namespace=sealed-secrets \
     --format=yaml < /tmp/my-app-creds.json \
     > applications/homeflix/manifests/my-app-creds.yaml
   ```

3. **Reference it** from your app config via `secretEnv`:
   ```yaml
   # applications/homeflix/apps/my-app.yaml
   name: my-app
   image: some/image
   port: 8080
   secretEnv:
     API_KEY:
       secretName: my-app-creds
       key: API_KEY
   ```

### Real SealedSecret examples

```yaml
# applications/homeflix/manifests/radarr.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: radarr-apikey
  namespace: homeflix
spec:
  encryptedData:
    RADARR_APIKEY: AgArv6fBQujAF8MiOYgGvwMD...
  template:
    metadata:
      name: radarr-apikey
      namespace: homeflix
```

```yaml
# applications/homelab/manifests/umami.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: umami-db
  namespace: homelab
spec:
  encryptedData:
    MYSQL_URI: AgC/hc2ihReUHzJIqcwWA//gkXb...
  template:
    metadata:
      name: umami-db
      namespace: homelab
```

### Important rules

- The SealedSecret's `metadata.name` + `metadata.namespace` must match what `secretEnv` references
- The `encryptedData` keys match the environment variable names referenced in the app config
- Always encrypt from scratch when the secret value changes (kubeseal produces a new ciphertext each time, even for the same plaintext — this is by design)

---

## 6. Conventions & Sync Policies

### YAML conventions

- **2-space indentation** everywhere
- **`apiVersion`** and **`kind`** at the top of every resource
- For ArgoCD `Application` resources, ensure:
  - `syncPolicy.automated.prune: false` (prevents accidental deletions)
  - `syncPolicy.automated.selfHeal: true` (auto-corrects drift)
  - `syncPolicy.syncOptions: [ApplyOutOfSyncOnly=true]` (efficient syncing)

### Sync policies per stack

| Stack | prune | selfHeal | Notes |
|-------|-------|----------|-------|
| homeflix | `false` | `true` | Standard |
| homelab | `false` | `true` | Standard |
| devops | `true` | `true` | Exception — prune is enabled here |
| platform | `false` | `true` | Standard (for raw Applications) |
| ingress | `false` | `true` | Standard |
| settings | `false` | `true` | Bootstrap config |

### AppProject conventions

Defined in `settings/projects.yaml`. Each stack has its own AppProject:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: homeflix
spec:
  destinations:
    - namespace: "homeflix"
      server: "*"
  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
```

When modifying AppProjects:
- Ensure `destinations` correctly scope the allowed namespaces
- Use `namespaceResourceWhitelist` to restrict resource types per project
- The `argocd` project is for ArgoCD's own namespace
- The `platform` project has `clusterResourceWhitelist` for cluster-scoped resources

### Git workflow

- **Always run `git pull`** before making changes (sync with remote)
- **Never push to git without asking** the user first for confirmation
- Commit messages should be concise and describe the change
- Prefer `ApplicationSet` generators for scaling similar deployments
- When adding features to `homelab-application`, modify the chart templates — not individual app configs
