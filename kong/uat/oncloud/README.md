# Kong uat OnCloud Modular State

This folder is generated from `kong-uat-oncloud.yaml` and can be used directly with decK:

```bash
deck gateway validate <auth-flags> kong/uat/oncloud
deck gateway diff <auth-flags> kong/uat/oncloud
deck gateway sync <auth-flags> --yes kong/uat/oncloud
```

Each file contains one entity list item (service, consumer, partial, etc.) plus shared metadata.
