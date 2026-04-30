# Azure DevOps System Guide

## Purpose

This document merges the Azure DevOps operating guide for both Kong repositories that are managed together in this workspace:

- `Kong-External-OnCloud`
- `Kong-Internal-OnPrem`

The goal is to keep the duplicated operational knowledge in one structure. The shared Azure DevOps model is explained once, and the implementation differences are separated into dedicated `OnCloud` and `OnPrem` sections.

This guide is written for system configuration and daily operations. It explains how the pipelines are organized, how the YAML files are used, how rendering works, how deployment, promotion, rollback, and ping are executed, and what must be prepared in Azure DevOps before any run will succeed.

## Scope

This guide covers the two repositories side by side:

| Repository | Control Plane Style | Shared Source Path |
| --- | --- | --- |
| `Kong-External-OnCloud` | External OnCloud | `kong/external/oncloud/` |
| `Kong-Internal-OnPrem` | Internal OnPrem | `kong/internal/onprem/` |

Both repositories use the same operating principle:

1. Shared decK YAML is stored in a common template folder.
2. Environment-specific values are stored in env files.
3. Azure DevOps renders the shared template at runtime.
4. decK validates, diffs, backs up, and syncs the rendered output.

The differences between the repositories are in:

- the directory names
- the environment combinations
- the promotion targets
- the override behavior
- the extra validation and ping flow used by `OnPrem`

## Shared Azure DevOps Model

### Manual-only pipeline execution

Both repositories are intentionally manual-only:

```yaml
trigger: none
pr: none
```

This is important because these pipelines are not just validation pipelines. They can change live Konnect control planes, create rollback artifacts, and apply rollback states. Manual triggering is part of the governance model.

### Common Azure DevOps prerequisites

Before any pipeline can run, Azure DevOps must provide:

1. A build agent pool named `cicd-agent`
2. A Konnect token variable named `KONG_TOKEN`
3. A Konnect API base URL variable named `KONG_ADDR`

Recommended setup:

1. Create an Azure DevOps variable group
2. Store `KONG_TOKEN` as a secret
3. Store `KONG_ADDR` as a normal variable
4. Link that variable group to each pipeline definition

The build agent must be able to:

- run Bash
- use `git`, `curl`, `tar`, `find`, `sed`, `perl`, `awk`, and `xargs`
- download `decK`
- call the Konnect API
- publish and download Azure DevOps artifacts

### Common pipeline execution pattern

Both repositories follow the same operational flow during deployment and promotion:

1. Validate the requested mode, environment, and branch combination
2. Check out the repository
3. Pin the working tree to the exact `Build.SourceVersion`
4. Ensure `decK` is installed
5. Validate `KONG_TOKEN` and `KONG_ADDR`
6. Resolve the target control plane and target state path
7. Render the shared state when the repository is using shared templates
8. Run `deck gateway ping`
9. Run `deck file validate`
10. Run `deck gateway diff`
11. If differences exist, back up the current live control plane
12. Publish that backup as a pipeline artifact
13. Run `deck gateway sync`

Rollback uses a similar safety-first flow:

1. Validate rollback parameters
2. Download the requested backup artifact
3. Resolve the selected backup YAML file
4. Confirm the rollback file belongs to the intended control plane
5. Run `deck gateway ping`
6. Run `deck file validate`
7. Run `deck gateway diff`
8. Run `deck gateway sync` only if differences exist

### Common source-of-truth design

Both repositories use a shared template model instead of maintaining separate checked-in decK folders per environment. That means:

- shared YAML should remain environment-agnostic
- placeholders should be used instead of hardcoded environment values
- env files are part of the deployable system design, not just optional configuration

In practice, the authoring rule is simple:

1. Put structural Kong objects in the shared template folders
2. Put environment-specific values in env files
3. Let Azure DevOps render the final state

### Common rollback artifact pattern

When a deployment or promotion detects changes, the current live state is dumped before sync and published as a build artifact.

The artifact naming pattern is:

`kong-backup-<environment>-<controlPlane>-<BuildId>`

The backup file inside the artifact normally follows this pattern:

`<control-plane>-current-before-sync-<timestamp>.yaml`

That build artifact is the input for rollback.

## Shared Pipeline File Layout

The repositories use the same Azure DevOps file pattern:

| File | Purpose |
| --- | --- |
| `azure-pipelines.yml` | Generic manual entry point |
| `azure-pipelines-dev.yml` | Dev wrapper |
| `azure-pipelines-uat.yml` | UAT wrapper |
| `azure-pipelines-prod.yml` | Higher-environment wrapper |
| `azure-pipelines-nonprod.yml` | Narrow non-production wrapper |
| `pipelines/deployment.yml` | Deployment stage template |
| `pipelines/promotion.yml` | Promotion stage template |
| `pipelines/rollback.yml` | Rollback stage template |

`Kong-Internal-OnPrem` has one additional operational path:

| File | Purpose |
| --- | --- |
| `azure-pipelines-ping.yml` | Manual connectivity test wrapper |
| `pipelines/ping.yml` | decK ping stage template |

## Shared Authoring Rules

These rules should be followed in both repositories:

1. Do not hardcode environment-specific hosts, IDs, or URLs in the shared YAML.
2. When introducing a new placeholder, add the matching env variable to every environment that must render successfully.
3. Keep service ownership and route ownership separated cleanly.
4. Treat system env files as platform-owned configuration.
5. Treat user env files as operational configuration.
6. Keep the build ID and backup filename after every successful higher-environment run so rollback can be executed quickly.

## OnCloud Section

### Repository scope

The `OnCloud` implementation lives in `Kong-External-OnCloud`.

Its shared source-of-truth path is:

`kong/external/oncloud/`

Its environment files currently exist under:

- `kong/env/system/`
- `kong/env/user/`
- `kong/env/override/`

Important operational paths:

| Path | Purpose |
| --- | --- |
| `kong/external/oncloud/` | Shared decK source for external OnCloud |
| `kong/env/system/dev-system.env` | Dev system values |
| `kong/env/system/uat-system.env` | UAT system values |
| `kong/env/system/prod-system.env` | Prod system values |
| `kong/env/user/dev-oncloud.env` | Dev user values |
| `kong/env/user/uat-oncloud.env` | UAT user values |
| `kong/env/user/prod-oncloud.env` | Prod user values |
| `kong/env/override/prod-oncloud-preprod.env` | Override values used for PreProd promotion |

### OnCloud environment and branch governance

Current operational rules are:

#### Deployment

- `Dev` deployment runs from `development`
- `Uat` deployment runs from `master`

#### Promotion

- `PreProd` promotion runs from `master`
- `Prod` promotion runs from `master`

#### Rollback

- `Dev` rollback runs from `development`
- `Uat` rollback runs from `master`
- `Prod` rollback runs from `master`
- `PreProd` rollback is blocked

### OnCloud render model

The render script is:

`scripts/render-kong-state.sh`

It loads:

1. `kong/env/system/<env>-system.env`
2. `kong/env/user/<env>-oncloud.env`
3. optional override file, if the run requires one

The rendered output is written into `$(Pipeline.Workspace)/rendered/...`.

The shared YAML contains placeholders such as:

- `__CONTROL_PLANE_NAME__`
- `__PUBLIC_HOST_PRIMARY__`
- `__OPTIONAL_PUBLIC_HOST_SECONDARY__`
- `__KAOTIM_SERVICE_HOST__`
- `__ISSUER_URL__`
- Redis partial placeholders

The script also:

- chooses the correct Redis partial template based on `redis-ce` or `redis-ee`
- swaps prod consumer files into place when rendering production-style output
- removes optional host lines when secondary host values are blank
- fails if unresolved placeholders remain

### OnCloud PreProd behavior

`PreProd` is implemented as a production-style render plus an override file.

The pipeline:

1. loads production system values
2. loads production user values
3. applies `kong/env/override/prod-oncloud-preprod.env`

That override switches the active Redis partial references to the PreProd values. This is why the PreProd path is not just a simple copy of `Prod`; it deliberately changes which Redis-backed partials the rendered YAML will reference.

### Step-by-step: configure Azure DevOps for OnCloud

1. Create a pipeline definition for `azure-pipelines-dev.yml`
2. Create a pipeline definition for `azure-pipelines-uat.yml`
3. Create a pipeline definition for `azure-pipelines-prod.yml`
4. Link the shared variable group containing `KONG_TOKEN` and `KONG_ADDR`

Recommended pipeline names are separate operational names for Dev, UAT, and Prod so operators do not need to select from a large generic parameter set.

### Step-by-step: make an OnCloud change

1. Update shared YAML under `kong/external/oncloud/`
2. If environment-specific values are needed, update the correct files under `kong/env/system/` or `kong/env/user/`
3. Merge Dev-targeted work to `development`
4. Merge UAT, PreProd, and Prod-targeted work to `master`
5. Run the corresponding wrapper pipeline

### Step-by-step: deploy OnCloud

#### Deploy to Dev

1. Open the pipeline bound to `azure-pipelines-dev.yml`
2. Confirm `mode=deployment`
3. Confirm `environment=Dev`
4. Run from `development`

#### Deploy to UAT

1. Open the pipeline bound to `azure-pipelines-uat.yml`
2. Confirm `mode=deployment`
3. Confirm `environment=Uat`
4. Run from `master`

### Step-by-step: promote OnCloud

#### Promote to PreProd

1. Open the pipeline bound to `azure-pipelines-prod.yml`
2. Set `mode=promotion`
3. Set `environment=PreProd`
4. Run from `master`

#### Promote to Prod

1. Open the pipeline bound to `azure-pipelines-prod.yml`
2. Set `mode=promotion`
3. Set `environment=Prod`
4. Run from `master`

### Step-by-step: rollback OnCloud

1. Open the correct wrapper pipeline
2. Set `mode=rollback`
3. Choose `Dev`, `Uat`, or `Prod`
4. Supply `rollbackBuildId`
5. Supply `rollbackBackupFile`
6. Run from the correct branch

### OnCloud troubleshooting

If rendering fails, the most common causes are:

- a new placeholder was added to shared YAML without adding the env variable
- the wrong env file was edited
- the PreProd override path was not considered when checking Redis partial references

If rollback fails, the most common cause is selecting a backup file from the wrong control plane or wrong build.

## OnPrem Section

### Repository scope

The `OnPrem` implementation lives in `Kong-Internal-OnPrem`.

Its shared source-of-truth path is:

`kong/internal/onprem/`

Its environment files currently exist under:

- `kong/env/system/`
- `kong/env/user/`

Important operational paths:

| Path | Purpose |
| --- | --- |
| `kong/internal/onprem/` | Shared decK source for internal OnPrem |
| `kong/env/system/dev-system.env` | Dev system values |
| `kong/env/system/uat-system.env` | UAT system values |
| `kong/env/system/prod-system.env` | Prod system values |
| `kong/env/system/dr-system.env` | DR system values |
| `kong/env/user/dev-onprem.env` | Dev user values |
| `kong/env/user/uat-onprem.env` | UAT user values |
| `kong/env/user/prod-onprem.env` | Prod user values |
| `scripts/validate-rendered-redis-partials.sh` | Additional rendered-state validation |
| `azure-pipelines-ping.yml` | Dedicated manual connectivity pipeline |

### OnPrem environment and branch governance

Current operational rules are:

#### Deployment

- `Dev` deployment runs from `development`
- `Uat` deployment runs from `master`

#### Promotion

- `Prod` promotion runs from `master`
- `DR` promotion runs from `master`
- pipeline logic also contains a `PreProd` path, but see the note below

#### Rollback

- `Dev` rollback runs from `development`
- `Uat` rollback runs from `master`
- `Prod` rollback runs from `master`
- `DR` rollback is blocked by the wrapper pipeline

### Important current state: OnPrem PreProd

The shared promotion template contains logic for `PreProd`, but the current repository snapshot does not contain:

- `kong/env/system/preprod-system.env`
- `kong/env/user/preprod-onprem.env`

That means `PreProd` is not complete in the current checked-in shared render model. Before using `PreProd` operationally in this repository, those env files must be created and fully populated.

### OnPrem render model

The render script is also:

`scripts/render-kong-state.sh`

For OnPrem, it loads:

1. `kong/env/system/<env>-system.env`
2. `kong/env/user/<env>-onprem.env`
3. optional override file when promotion needs one

The rendered output is written into `$(Pipeline.Workspace)/rendered/...`.

The OnPrem render process additionally handles:

- environment-specific service hosts, protocols, and ports
- route upstream URIs
- Redis and Redis cache partials
- consumer custom IDs
- production-specific consumer file swapping
- conditional stripping of Redis Enterprise-only fields when the active partial type is not `redis-ee`

### OnPrem DR behavior

`DR` promotion is not rendered from a dedicated checked-in `dr-onprem.env` user file.

Instead, the current promotion flow:

1. loads `kong/env/user/prod-onprem.env`
2. loads `kong/env/system/prod-system.env`
3. creates an override env file at runtime
4. changes the active Redis partial IDs and names to the DR values

So the DR path is effectively a production-style render with DR Redis references injected by an override layer.

### OnPrem extra validation

During promotion, `OnPrem` runs:

```bash
bash scripts/validate-rendered-redis-partials.sh "$RESOLVED_TARGET_PATH"
```

This validation checks that Redis-backed plugin references in the rendered YAML actually point to Redis partials that exist in the rendered output. If a plugin references a missing rendered partial, the promotion fails before `deck gateway sync`.

This extra validation does not exist in the current `OnCloud` repository.

### OnPrem ping pipeline

`OnPrem` has a dedicated connectivity-only pipeline:

- `azure-pipelines-ping.yml`
- `pipelines/ping.yml`

Use this when you need to verify:

- `KONG_TOKEN`
- `KONG_ADDR`
- control plane reachability
- agent-to-Konnect connectivity

without attempting a deployment.

### Step-by-step: configure Azure DevOps for OnPrem

1. Create a pipeline definition for `azure-pipelines-dev.yml`
2. Create a pipeline definition for `azure-pipelines-uat.yml`
3. Create a pipeline definition for `azure-pipelines-prod.yml`
4. Create a pipeline definition for `azure-pipelines-ping.yml`
5. Link the shared variable group containing `KONG_TOKEN` and `KONG_ADDR`

### Step-by-step: make an OnPrem change

1. Update shared YAML under `kong/internal/onprem/`
2. Update the matching system and user env files when environment-specific values are required
3. Merge Dev-targeted work to `development`
4. Merge UAT, Prod, and DR-targeted work to `master`
5. Run the corresponding wrapper pipeline

### Step-by-step: deploy OnPrem

#### Deploy to Dev

1. Open the pipeline bound to `azure-pipelines-dev.yml`
2. Confirm `mode=deployment`
3. Confirm `environment=Dev`
4. Run from `development`

#### Deploy to UAT

1. Open the pipeline bound to `azure-pipelines-uat.yml`
2. Confirm `mode=deployment`
3. Confirm `environment=Uat`
4. Run from `master`

### Step-by-step: promote OnPrem

#### Promote to Prod

1. Open the pipeline bound to `azure-pipelines-prod.yml`
2. Set `mode=promotion`
3. Set `environment=Prod`
4. Run from `master`

#### Promote to DR

1. Open the pipeline bound to `azure-pipelines-prod.yml`
2. Set `mode=promotion`
3. Set `environment=DR`
4. Run from `master`

### Step-by-step: ping OnPrem

1. Open the pipeline bound to `azure-pipelines-ping.yml`
2. Supply `controlPlaneName`
3. Run the pipeline

Use this before first deployment to a new control plane, after token rotation, or after network changes on the agent side.

### Step-by-step: rollback OnPrem

1. Open the correct wrapper pipeline
2. Set `mode=rollback`
3. Choose `Dev`, `Uat`, or `Prod`
4. Supply `rollbackBuildId`
5. Supply `rollbackBackupFile`
6. Run from the correct branch

`DR` rollback is not part of the supported wrapper path.

### OnPrem troubleshooting

If promotion fails during Redis validation, inspect:

- active Redis partial IDs and names
- override values used by the DR path
- rendered partial files in the target output directory

If `PreProd` is attempted and the run fails early, verify whether the missing `preprod` env files were added. In the current repository snapshot, they are not present.

If ping fails, do not continue with deployment until credential or connectivity issues are corrected.

## Recommended Operating Practice

Use this operating pattern for both repositories:

1. Use wrapper pipelines for normal operations.
2. Keep shared YAML generic and environment-agnostic.
3. Put control plane names, vault IDs, and other stable platform identifiers in system env files.
4. Put hostnames, upstreams, protocols, ports, and rate limits in user env files.
5. Keep rollback artifact details after every successful higher-environment run.
6. Treat promotion logic that uses overrides as a distinct flow and review those overrides carefully.

## Document Location

This merged guide should be kept in both repositories at the same relative path:

- `docs/azure-devops-system-guide.md`

That keeps the main operations guide easy to find regardless of which repository an engineer opens first.
