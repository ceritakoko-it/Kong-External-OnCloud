# Kong preprod OnCloud Modular State

This folder is generated from `kong-preprod-oncloud.yaml` and can be used directly with decK:

```bash
deck gateway validate <auth-flags> kong/preprod/oncloud
deck gateway diff <auth-flags> kong/preprod/oncloud
deck gateway sync <auth-flags> --yes kong/preprod/oncloud
```

Each file contains one entity list item (service, consumer, partial, etc.) plus shared metadata.
