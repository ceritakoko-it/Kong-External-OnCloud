# Kong External OnCloud Shared State

This folder is the shared base state for `OnCloud`.

It is rendered at pipeline runtime using:

- `kong/env/dev-oncloud.env`
- `kong/env/uat-oncloud.env`
- `kong/env/preprod-oncloud.env`
- `kong/env/prod-oncloud.env`
- `kong/env/dr-oncloud.env`

Do not put environment-specific literals directly in this folder. Use template tokens and env files instead.
