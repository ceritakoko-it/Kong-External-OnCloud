# Kong prod OnCloud Modular State

This folder is generated from `kong-prod-oncloud.yaml` and can be used directly with decK:

```bash
deck gateway validate <auth-flags> kong/prod/oncloud
deck gateway diff <auth-flags> kong/prod/oncloud
deck gateway sync <auth-flags> --yes kong/prod/oncloud
```

Each file contains one entity list item (service, consumer, partial, etc.) plus shared metadata.
