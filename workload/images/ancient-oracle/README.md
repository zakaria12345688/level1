# The Ancient Oracle

A read-only [Model Context Protocol](https://modelcontextprotocol.io) server
that lets an AI assistant see the realm's Kubernetes cluster. It runs in the
cluster (namespace `ancient`, chart `../../charts/ancient-oracle`) and speaks
MCP over Streamable HTTP at `/mcp`.

| Tool | What it returns |
|---|---|
| `list_namespaces` | Namespaces and their phase |
| `list_pods` | Pods: phase, readiness, restarts, node, age |
| `get_pod` | One pod in detail: containers, images, resources, state |
| `list_deployments` | Deployments: desired, ready, updated, available replicas, images |
| `list_services` | Services: type, cluster IP, ports |
| `list_nodes` | Nodes: readiness, kubelet version, allocatable resources |
| `list_events` | Recent events, newest first |
| `pod_logs` | The last lines of a pod's log |

Everything the Oracle answers is written to its journal, readable at
`/mcp/journal` (`?limit=`, `?tool=`). The Oracle also asks itself a few
questions every 15 minutes (`ORACLE_HEARTBEAT`), so the journal shows the realm
over the day.

## Layout

```
oracle/__main__.py   entry point and the heartbeat
oracle/server.py     HTTP and MCP (JSON-RPC 2.0)
oracle/tools.py      the tools
oracle/kube.py       the Kubernetes API client (service account token)
oracle/shaping.py    keeps answers within an assistant's context budget
oracle/journal.py    the journal
runtime/             shims for the slim Python image
Dockerfile
```

## Build and run

```bash
docker build --platform linux/amd64 -t <registry>/realm/ancient-oracle:<tag> .
docker push <registry>/realm/ancient-oracle:<tag>
```

The image runs as user 65534 and needs only the standard library.
