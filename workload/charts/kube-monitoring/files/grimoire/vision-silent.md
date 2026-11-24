## Vision: a service that fell silent

Alert: `ScrollServiceSilent` for `scrolls/magician`: no ready replicas, the
deployment is scaled to 0.

Remedy:

```json
{
  "diagnosis": "magician was scaled to zero, so nobody answers. It normally runs one replica.",
  "actions": [
    {"type": "scale", "namespace": "scrolls", "deployment": "magician", "replicas": 1}
  ],
  "commit_message": "Bring magician back to one replica"
}
```
