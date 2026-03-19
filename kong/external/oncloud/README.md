# Kong External OnCloud Shared State

This folder is the shared base state for `OnCloud`.

It is rendered at pipeline runtime using:

- `kong/env/system/dev-system.env` + `kong/env/user/dev-oncloud.env`
- `kong/env/system/uat-system.env` + `kong/env/user/uat-oncloud.env`
- `kong/env/system/prod-system.env` + `kong/env/user/prod-oncloud.env`

Do not put environment-specific literals directly in this folder. Use template tokens and env files instead.

Redis partials are structured to support both the current simple host/password mode and future Sentinel-backed `redis-ee` settings through `kong/env/system/*.env`, following the same pattern used in `Kong-Internal-OnPrem`.
