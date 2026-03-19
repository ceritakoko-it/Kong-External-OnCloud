# OnCloud Air Flight Template

This folder is a sample onboarding template for adding a new `OnCloud` API.

It is intentionally outside `kong/` so the pipeline does not validate, render, diff, or sync it.

Use this template by copying the relevant files into `kong/external/oncloud/` and then replacing the placeholders with real values.

Template filenames use a generic placeholder pattern:

- `<number-sequence>-service-name.yaml`
- `<number-sequence>-route-name.yaml`
- `<number-sequence>-plugin-name.yaml`
- `<number-sequence>-consumer-name.yaml`

Rename them to the real file names when onboarding the actual API.

Included samples:

- `services/001-service-name.yaml`
- `routes/001-route-name.yaml`
- `plugins/001-plugin-name.yaml`
- `plugins/002-plugin-name.yaml`
- `consumers/001-consumer-name.yaml`

## Recommended onboarding order

1. Create the `service`.
2. Create the `route` and point it to the service.
3. Add any `plugin` needed on the route, service, or globally.
4. Add the `consumer` if the API is accessed by a known client or partner.
5. Add or update `kong/env/system/*.env` or `kong/env/user/*-oncloud.env` if the new config needs environment-specific values.
6. Validate the copied files with `deck file validate`.

## Service onboarding

Source template:

- `services/001-service-name.yaml`

Target location:

- `kong/external/oncloud/services/<number-sequence>-<service-name>.yaml`

Update these fields:

- file name to the next available sequence and the real service name
- `services[].name`
- `services[].host`
- `services[].port`
- `services[].protocol`
- timeout or retry values if the upstream requires different settings

When to use env variables:

- use env variables if the upstream host or other values differ by environment
- add the variable to the required files under `kong/env/system/*.env` or `kong/env/user/*-oncloud.env`
- use the placeholder token inside `kong/external/oncloud/`, for example `__AIR_FLIGHT_SERVICE_HOST__`

Example outcome:

- `kong/external/oncloud/services/018-air-flight-service.yaml`

## Route onboarding

Source template:

- `routes/001-route-name.yaml`

Target location:

- `kong/external/oncloud/routes/<number-sequence>-<route-name>.yaml`

Update these fields:

- file name to the next available sequence and the real route name
- `routes[].name`
- `routes[].hosts`
- `routes[].paths`
- `routes[].methods`
- `routes[].service.name`
- `strip_path`, `preserve_host`, and protocol settings if required by the API

Route checks:

- make sure the route points to an existing `service.name`
- use environment variables for host values when the public hostname changes per environment
- keep the route name descriptive, for example `air-flight-search-route`

Example outcome:

- `kong/external/oncloud/routes/019-air-flight-search-route.yaml`

## Plugin onboarding

Source templates:

- `plugins/001-plugin-name.yaml`
- `plugins/002-plugin-name.yaml`

Target location:

- `kong/external/oncloud/plugins/<number-sequence>-<plugin-name>.yaml`

Update these fields:

- file name to the next available sequence and the real plugin purpose
- `plugins[].name`
- `plugins[].config`
- one attachment target only as needed:
  - `plugins[].route.name`
  - `plugins[].service.name`
  - `plugins[].consumer.username`

Plugin checks:

- confirm the referenced route, service, or consumer already exists
- use one file per plugin for clarity
- if the plugin contains environment-specific values, add them to `kong/env/system/*.env` or `kong/env/user/*-oncloud.env` and reference them through placeholders

Example outcomes:

- `kong/external/oncloud/plugins/020-air-flight-cors.yaml`
- `kong/external/oncloud/plugins/021-air-flight-request-transformer.yaml`

## Consumer onboarding

Source template:

- `consumers/001-consumer-name.yaml`

Target location:

- `kong/external/oncloud/consumers/<number-sequence>-<consumer-name>.yaml`

Update these fields:

- file name to the next available sequence and the real consumer name
- `consumers[].username`
- `consumers[].custom_id`
- `consumers[].tags`

Consumer checks:

- use a stable username that reflects the calling application or partner
- use `custom_id` only when you need a stable external identifier
- parameterize `custom_id` in `kong/env/system/*.env` when the value differs by environment
- use a clear env naming pattern, for example `<CONSUMER_NAME>_CUSTOM_ID`
- if authentication credentials are needed, create the related credential object in the appropriate Kong config after the consumer is defined

Example mapping:

- consumer `standard_core_api_user` -> `STANDARD_CORE_API_USER_CUSTOM_ID`
- consumer `standard_general_services_user` -> `STANDARD_GENERAL_SERVICES_USER_CUSTOM_ID`

Example outcome:

- `kong/external/oncloud/consumers/005-air-flight-portal-consumer.yaml`

## Environment variable onboarding

Add new variables to:

- `kong/env/system/dev-system.env`
- `kong/env/system/uat-system.env`
- `kong/env/system/prod-system.env`
- `kong/env/user/dev-oncloud.env`
- `kong/env/user/uat-oncloud.env`
- `kong/env/user/prod-oncloud.env`

Use env variables for values such as:

- upstream host names
- public host names
- issuer URLs
- Redis partial IDs, types, hosts, passwords, and Sentinel settings
- consumer `custom_id` values
- vault or partial references

Example env variables:

- `AIR_FLIGHT_SERVICE_HOST`
- `AIR_FLIGHT_PUBLIC_HOST`
- `AIR_FLIGHT_CONSUMER_CUSTOM_ID`

If you add a new placeholder token to the shared `kong/external/oncloud` files, also update:

- `scripts/render-kong-state.sh`

The renderer must know how to replace that token during deployment.

## Validation checklist

Before creating a PR or running deployment:

1. Confirm all copied files are under `kong/external/oncloud/`, not under `templates/`.
2. Confirm numbering does not collide with existing files.
3. Confirm all `__PLACEHOLDER__` values have been replaced in live config.
4. Confirm any new env variables exist in every required `kong/env/system/*.env` or `kong/env/user/*-oncloud.env` file.
5. Run `deck file validate kong/external/oncloud`.
