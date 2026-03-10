# Kong Dev OnCloud Modular State

This folder is generated from `kong-dev-oncloud.yaml` and can be used directly with decK:

```bash
deck gateway validate <auth-flags> kong/dev/oncloud
deck gateway diff <auth-flags> kong/dev/oncloud
deck gateway sync <auth-flags> --yes kong/dev/oncloud
```

Each file contains one entity list item (service, consumer, partial, etc.) plus shared metadata.
