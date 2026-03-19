# Kong Konnect CI/CD Governance

This repository is the source of truth for Kong decK configuration and promotion flow across environments.

For `OnCloud`, the source of truth is:

- shared base: `kong/external/oncloud`
- environment values: `kong/env/system/*.env` and `kong/env/user/*-oncloud.env`

Reusable onboarding samples live outside the deployable tree:

- `templates/oncloud-air-flight`

That folder is documentation/template material only. It is intentionally outside `kong/` so the current validation and deployment pipeline does not treat it as live decK state.

## Naming Conventions

| Component | Naming Convention | Sample |
| --- | --- | --- |
| Azure Repos Repository | `<environment>-kong` | `dev-kong.conf` |
| Azure DevOps Pipeline | `<external/internal>-api-<deployment/promotion>-pipeline` | `internal-api-deployment-pipeline` |
| Kong Control Plane | `<environment>-<data-center>` | `development-azure` |
| Kong Gateway Service | `<application-name>-<env>` | `saldo-dev` |
| Kong API Route | `<application-name>-<env>-route` | `saldo-dev-route` |

## Branching Strategy

- `development` is used for deployment to Dev.
- `master` is used for deployment to Uat/Prod, promotion to Prod, and rollback to Uat/Prod.
- Feature work is done in feature branches and merged via PR.
- Hotfix work can branch from `master` and merge back to `master`.

## Pipeline Model

The pipeline is manual-only:

- `trigger: none`
- `pr: none`

Run via Azure DevOps `Run pipeline` with parameters:

- `mode`: `deployment` or `promotion` or `rollback`
- `environment`: `Dev`, `Uat`, `Prod`
- `controlPlane`: `OnCloud`
- `rollbackBuildId`: required when `mode=rollback`, points to the source pipeline `BuildId` that published backup artifact
- `rollbackBackupFile`: required when `mode=rollback`, exact backup YAML filename inside the published artifact

Azure DevOps also exposes:

- `Branch/tag`
- `Commit`

If `Commit` is filled, the pipeline explicitly pins checkout to `Build.SourceVersion` and fails if the checked-out commit does not match.

## Azure DevOps Prerequisites

Before running any pipeline, create these variables in Azure DevOps:

- `KONG_TOKEN`
  - secret
  - Konnect access token used by decK
- `KONG_ADDR`
  - plain text
  - Konnect API base URL
  - example: `https://us.api.konghq.com`

Recommended:

- store them in a variable group
- link that variable group to this pipeline

Without these values, deployment, promotion, and rollback will fail in the `Validate required variables` step.

## Environment Setup

For `OnCloud`, each environment is rendered from:

- `kong/env/system/<env>-system.env`
- `kong/env/user/<env>-oncloud.env`

Current files:

- `kong/env/system/dev-system.env`
- `kong/env/system/uat-system.env`
- `kong/env/system/prod-system.env`
- `kong/env/user/dev-oncloud.env`
- `kong/env/user/uat-oncloud.env`
- `kong/env/user/prod-oncloud.env`

The renderer loads the matching `system` file first, then overlays the selected `user` file.

Values that usually must be reviewed per environment:

- `CONTROL_PLANE_NAME`
- `GET_TOKEN_SERVICE_NAME`
- `GET_TOKEN_SERVICE_HOST`
- `ISSUER_URL`
- `REDIS_HOST`
- `REDIS_PARTIAL_NAME`
- `REDIS_CACHE_PARTIAL_NAME`
- `VAULT_CONFIG_STORE_ID`
- `STANDARD_CORE_API_USER_CUSTOM_ID`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID`
- `PUBLIC_HOST_PRIMARY`
- `PUBLIC_HOST_SECONDARY`
- `KAOTIM_SERVICE_HOST`

Consumer `custom_id` mapping:

- `STANDARD_CORE_API_USER_CUSTOM_ID` -> consumer `standard_core_api_user`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID` -> consumer `standard_general_services_user`

### First-Time Setup For Uat / Prod

Before first deployment to a new environment, make sure these dependencies already exist in Konnect for that target environment:

1. Identity issuer / identity domain
- example:
  - `Dev-OnCloud` -> `https://<dev-identity-domain>.sg.identity.konghq.com/auth`
  - `Uat-OnCloud` -> `https://<uat-identity-domain>.sg.identity.konghq.com/auth`
  - `Prod-OnCloud` -> `https://<prod-identity-domain>.sg.identity.konghq.com/auth`
- update both:
  - `ISSUER_URL`
  - `GET_TOKEN_SERVICE_HOST`

2. Vault `konnect` with prefix `identity`
- create the vault in the target control plane if it does not exist yet
- after creating it, get the JSON and copy:
  - `config.config_store_id`
- put that value into:
  - `VAULT_CONFIG_STORE_ID`

Important:

- do not use the top-level vault `id`
- use only `config.config_store_id`

Example:

If Konnect returns:

```json
{
  "config": {
    "config_store_id": "<config-store-id>"
  },
  "id": "<vault-id>",
  "name": "konnect",
  "prefix": "identity"
}
```

Then the matching `kong/env/system/<env>-system.env` file must contain:

```env
VAULT_CONFIG_STORE_ID=<config-store-id>
```

Not:

```env
VAULT_CONFIG_STORE_ID=<vault-id>
```

3. Review route hostnames for the target environment
- set:
  - `PUBLIC_HOST_PRIMARY`
  - `PUBLIC_HOST_SECONDARY`
- `PUBLIC_HOST_SECONDARY` may be left blank

4. Review any environment-specific upstream values
- `KAOTIM_SERVICE_HOST`
- `REDIS_PARTIAL_NAME`
- `REDIS_CACHE_PARTIAL_NAME`

5. Review any environment-specific consumer identifiers
- `STANDARD_CORE_API_USER_CUSTOM_ID`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID`

These values map to:

- `CoreAPI` -> `STANDARD_CORE_API_USER_CUSTOM_ID`
- `GeneralServices` -> `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID`

### Parameter Checklist By Environment

Before first run for each environment, verify:

`Dev-OnCloud`
- `CONTROL_PLANE_NAME=Dev-OnCloud`
- `GET_TOKEN_SERVICE_HOST=<dev-identity-domain>.sg.identity.konghq.com`
- `ISSUER_URL=https://<dev-identity-domain>.sg.identity.konghq.com/auth`
- `VAULT_CONFIG_STORE_ID` matches the Dev config store

`Uat-OnCloud`
- `CONTROL_PLANE_NAME=Uat-OnCloud`
- `GET_TOKEN_SERVICE_HOST=<uat-identity-domain>.sg.identity.konghq.com`
- `ISSUER_URL=https://<uat-identity-domain>.sg.identity.konghq.com/auth`
- `STANDARD_CORE_API_USER_CUSTOM_ID=wchk88gpachhwr34`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID=yz955goaapqvdt3r`
- `VAULT_CONFIG_STORE_ID` matches the UAT config store

`Prod-OnCloud`
- `CONTROL_PLANE_NAME=Prod-OnCloud`
- `GET_TOKEN_SERVICE_HOST=<prod-identity-domain>.sg.identity.konghq.com`
- `ISSUER_URL=https://<prod-identity-domain>.sg.identity.konghq.com/auth`
- `STANDARD_CORE_API_USER_CUSTOM_ID=7fkajd8uqyeagaxz`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID=84dunjlkr2lue0ul`
- `VAULT_CONFIG_STORE_ID` matches the Prod config store

## Governance Rules (Enforced)

The stage `Validate_Run_Rules` blocks invalid combinations and fails the run.

Allowed combinations:

1. Deployment to Dev
- `mode=deployment`
- `environment=Dev`
- branch `refs/heads/development`

2. Deployment to Uat
- `mode=deployment`
- `environment=Uat`
- branch `refs/heads/master`

3. Promotion Uat -> Prod
- `mode=promotion`
- `environment=Prod`
- branch `refs/heads/master`

4. Rollback to Dev
- `mode=rollback`
- `environment=Dev`
- branch `refs/heads/development`

5. Rollback to Uat
- `mode=rollback`
- `environment=Uat`
- branch `refs/heads/master`

6. Rollback to Prod
- `mode=rollback`
- `environment=Prod`
- branch `refs/heads/master`

Any other combination fails in the guard stage.

## Deployment and Promotion Flow

Shared high-level behavior:

1. Checkout repository and pin to the selected commit ID.
2. Install decK.
3. Validate required secrets (`KONG_TOKEN`, `KONG_ADDR`).
4. Resolve control plane and desired state path.
5. Render shared `OnCloud` state when applicable.
6. Ping gateway, validate config locally, run diff.
7. If any diff summary count is non-zero (`Created`, `Updated`, `Deleted`), treat as changes.
8. Backup current state.
9. Publish backup as pipeline artifact.
10. Run `deck gateway sync`.

OnCloud repository behavior:

1. `kong/external/oncloud` is the shared base template.
2. The selected target environment loads:
- `kong/env/system/<env>-system.env`
- `kong/env/user/<env>-oncloud.env`
3. The pipeline renders the shared base into a temporary folder and deploys that rendered output.
4. `kong/<env>/oncloud` folders are no longer used for `OnCloud`.

System env files currently parameterize:

- `CONTROL_PLANE_NAME`
- `GET_TOKEN_SERVICE_NAME`
- `GET_TOKEN_SERVICE_HOST`
- `ISSUER_URL`
- `REDIS_HOST`
- `REDIS_PASSWORD`
- `REDIS_PARTIAL_ID`
- `STANDARD_CORE_API_USER_CUSTOM_ID`
- `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID`
- `REDIS_PARTIAL_NAME`
- `REDIS_PARTIAL_TYPE`
- `REDIS_PARTIAL_HOST`
- `REDIS_PARTIAL_PASSWORD`
- `REDIS_PARTIAL_SENTINEL_MASTER`
- `REDIS_PARTIAL_SENTINEL_NODES`
- `REDIS_PARTIAL_SENTINEL_PASSWORD`
- `REDIS_PARTIAL_SENTINEL_ROLE`
- `REDIS_PARTIAL_SENTINEL_USERNAME`
- `REDIS_CACHE_PARTIAL_ID`
- `REDIS_CACHE_PARTIAL_NAME`
- `REDIS_CACHE_HOST`
- `REDIS_CACHE_PASSWORD`
- `REDIS_CACHE_SENTINEL_MASTER`
- `REDIS_CACHE_SENTINEL_NODES`
- `REDIS_CACHE_SENTINEL_PASSWORD`
- `REDIS_CACHE_SENTINEL_ROLE`
- `REDIS_CACHE_SENTINEL_USERNAME`
- `VAULT_CONFIG_STORE_ID`

Notes:

- user env files currently parameterize `PUBLIC_HOST_PRIMARY`, `PUBLIC_HOST_SECONDARY`, and `KAOTIM_SERVICE_HOST`
- Redis partial settings now follow the same system-env structure used by `Kong-Internal-OnPrem`, so Prod can move from simple Redis to Sentinel-backed `redis-ee` without another template redesign.
- Current intent: only `Prod` should move to Sentinel-backed `redis-ee` for advanced rate limiting. `Dev` and `Uat` stay on the current setup unless explicitly changed later.
- `PUBLIC_HOST_PRIMARY` is required.
- `PUBLIC_HOST_SECONDARY` is optional. If blank, the renderer removes the second `hosts` entry so route YAML stays valid.
- `STANDARD_CORE_API_USER_CUSTOM_ID` and `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID` should be set per environment if Konnect consumer IDs differ between control planes.
- `VAULT_CONFIG_STORE_ID` must match the live config store binding intended for that environment. Changing it on an already-used vault may fail due to Konnect reference constraints.

Promotion-specific repository behavior:

1. For shared `OnCloud`, promotion no longer copies repo folders. It renders `kong/external/oncloud` using the target environment file and deploys directly to the target control plane.
2. Legacy folder-copy promotion is still used for control planes that do not have a shared base template.

## Backup Mechanism

Backups are created only when changes are detected.

Backup location on agent:

- `$(Build.ArtifactStagingDirectory)/kong-backup`

Backup file:

1. Current state dump:
- `<control-plane>-current-before-sync-<timestamp>.yaml`

Published artifact name:

- `kong-backup-<environment>-<controlPlane>-<BuildId>`

Note: backup files are not committed to this repo; they are available in Azure DevOps run artifacts.

## Rollback Flow

Rollback re-applies backup dump state from a previous run artifact to the selected target control plane.

1. Validate run rules and ensure `rollbackBuildId` and `rollbackBackupFile` are provided.
2. Download artifact named `kong-backup-<environment>-<controlPlane>-<rollbackBuildId>`.
3. Resolve rollback source file using the exact `rollbackBackupFile` parameter value.
4. Validate rollback alignment:
- artifact directory must match the selected `environment`, `controlPlane`, and `rollbackBuildId`
- rollback YAML `control_plane_name` must exactly match the selected target control plane
5. Run `deck gateway ping`, `deck file validate`, and `diff`.
6. If diff shows changes, execute `deck gateway sync` using the resolved rollback dump file.

### 6.4. Pipeline Automation with Azure DevOps

To execute this strategy reliably, manual intervention must be eliminated. All backup, restore, and rollback operations will be handled by Azure Pipelines.

## Mermaid Flow Diagram

```mermaid
flowchart TD
    A[Manual Run Triggered] --> B{Branch}
    B -->|development| C[Validate_Run_Rules]
    B -->|uat| C
    B -->|master| C
    B -->|other| X[Fail Pipeline]

    C --> C0{mode + environment valid for branch?}
    C0 -->|No| X
    C0 -->|Yes| D{mode}

    D -->|deployment| E[Deploy Stage]
    D -->|promotion| F[Promote Stage]

    E --> E0[Checkout + Pin Commit]
    E0 --> E1[Install decK + Validate Vars]
    E1 --> E2[Resolve target path, env file, control plane]
    E2 --> E21[Render shared OnCloud state when available]
    E21 --> E3[Ping + File Validate + Diff]
    E3 --> E4{Created/Updated/Deleted > 0?}
    E4 -->|No| Z[Finish - No Sync]
    E4 -->|Yes| E5[Backup current]
    E5 --> E6[Publish backup artifact]
    E6 --> E7[deck gateway sync]
    E7 --> Z

    F --> F1{environment}
    F1 -->|Prod| F2[Checkout + Pin Commit]
    F2 --> F4[Resolve target env file and render shared OnCloud state]
    F4 --> F5[Ping + File Validate + Diff]
    F5 --> F6{Created/Updated/Deleted > 0?}
    F6 -->|No| Z
    F6 -->|Yes| F7[Backup current]
    F7 --> F8[Publish backup artifact]
    F8 --> F9[deck gateway sync]
    F9 --> Z
```
