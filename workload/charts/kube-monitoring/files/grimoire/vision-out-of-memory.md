## Vision: a service that ran out of memory

Alert: `ScrollOutOfMemory` for `scrolls/scrolls-app`, container `scrolls-app`,
memory limit `64Mi`, last state `OOMKilled`.

Remedy:

```json
{
  "diagnosis": "scrolls-app needs more memory than its 64Mi limit since the ledger grew, so the kernel kills it.",
  "actions": [
    {"type": "resources", "namespace": "scrolls", "deployment": "scrolls-app", "container": "scrolls-app", "memory": "128Mi"}
  ],
  "commit_message": "Raise scrolls-app memory limit to 128Mi"
}
```
