# Kong dr OnCloud Modular State

This folder is generated from `kong-dr-oncloud.yaml` and can be used directly with decK:

```bash
deck gateway validate <auth-flags> kong/dr/oncloud
deck gateway diff <auth-flags> kong/dr/oncloud
deck gateway sync <auth-flags> --yes kong/dr/oncloud
```

Each file contains one entity list item (service, consumer, partial, etc.) plus shared metadata.
