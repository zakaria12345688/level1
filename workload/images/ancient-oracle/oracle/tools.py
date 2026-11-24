"""
The Oracle's tools: read-only views of the cluster, shaped for an AI
assistant.

Each tool returns plain data (dicts and lists); the server renders it as
JSON.
"""

from datetime import datetime, timezone

from .kube import Kube, KubeError


TOOLS = {}


def tool(name, description, properties=None, required=()):
    def register(fn):
        TOOLS[name] = {
            "fn": fn,
            "spec": {
                "name": name,
                "description": description,
                "inputSchema": {
                    "type": "object",
                    "properties": properties or {},
                    "required": list(required),
                    "additionalProperties": False,
                },
                "annotations": {
                    "readOnlyHint": True,
                    "openWorldHint": False,
                },
            },
        }
        return fn

    return register


NAMESPACE = {
    "type": "string",
    "description": "Namespace. Leave out for all namespaces.",
}
kube = Kube()


def _ns_path(namespace, group_path, resource):
    if namespace:
        return f"{group_path}/namespaces/{namespace}/{resource}"

    return f"{group_path}/{resource}"


def _age(ts):
    if not ts:
        return None

    try:
        then = (
            datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ")
            .replace(tzinfo=timezone.utc)
            .timestamp()
        )
    except ValueError:
        return None

    s = max(0, int(kube.now() - then))
    for unit, size in (("d", 86400), ("h", 3600), ("m", 60)):
        if s >= size:
            return f"{s // size}{unit}"

    return f"{s}s"


def _pod_row(p):
    meta, spec, status = (
        p.get("metadata", {}),
        p.get("spec", {}),
        p.get("status", {}),
    )
    cs = status.get("containerStatuses") or []

    return {
        "namespace": meta.get("namespace"),
        "name": meta.get("name"),
        "phase": status.get("phase"),
        "ready": (
            f"{sum(1 for c in cs if c.get('ready'))}/"
            f"{len(spec.get('containers') or [])}"
        ),
        "restarts": sum(int(c.get("restartCount", 0)) for c in cs),
        "node": spec.get("nodeName"),
        "age": _age(meta.get("creationTimestamp")),
    }


@tool(
    "list_namespaces",
    "List the cluster's namespaces and their phase.",
)
def list_namespaces():
    rows = [
        {
            "name": n["metadata"]["name"],
            "phase": (n.get("status") or {}).get("phase"),
        }
        for n in kube.items("/api/v1/namespaces")
    ]
    return {"namespaces": rows, "count": len(rows)}


@tool(
    "list_pods",
    "List pods with their phase, readiness, restart count and node.",
    {
        "namespace": NAMESPACE,
        "label_selector": {
            "type": "string",
            "description": (
                "Kubernetes label selector, "
                "e.g. app.kubernetes.io/name=scrolls-app"
            ),
        },
    },
)
def list_pods(namespace=None, label_selector=None):
    rows = [
        _pod_row(p)
        for p in kube.items(
            _ns_path(namespace, "/api/v1", "pods"),
            {"labelSelector": label_selector},
        )
    ]
    return {"pods": rows, "count": len(rows)}


@tool(
    "get_pod",
    "Details of one pod: containers, images, resources, state and "
    "conditions.",
    {"namespace": {"type": "string"}, "name": {"type": "string"}},
    required=("namespace", "name"),
)
def get_pod(namespace, name):
    p = kube.request(f"/api/v1/namespaces/{namespace}/pods/{name}")
    status = p.get("status", {})
    states = {c["name"]: c for c in status.get("containerStatuses") or []}

    containers = []
    for c in p.get("spec", {}).get("containers") or []:
        st = states.get(c["name"], {})
        containers.append({
            "name": c["name"],
            "image": c.get("image"),
            "resources": c.get("resources") or {},
            "ready": bool(st.get("ready")),
            "restarts": int(st.get("restartCount", 0)),
            "state": st.get("state") or {},
            "last_state": st.get("lastState") or {},
        })

    return {"pod": {
        **_pod_row(p),
        "labels": p.get("metadata", {}).get("labels") or {},
        "service_account": p.get("spec", {}).get("serviceAccountName"),
        "containers": containers,
        "conditions": [
            {
                "type": c.get("type"),
                "status": c.get("status"),
                "reason": c.get("reason"),
            }
            for c in status.get("conditions") or []
        ],
    }}


@tool(
    "list_deployments",
    "List Deployments with desired, ready, updated and available replicas "
    "and their images.",
    {"namespace": NAMESPACE},
)
def list_deployments(namespace=None):
    rows = []
    for d in kube.items(_ns_path(namespace, "/apis/apps/v1", "deployments")):
        spec, status = d.get("spec", {}), d.get("status", {})

        rows.append({
            "namespace": d["metadata"].get("namespace"),
            "name": d["metadata"].get("name"),
            "replicas": int(spec.get("replicas", 1)),
            "ready": int(status.get("readyReplicas", 0)),
            "updated": int(status.get("updatedReplicas", 0)),
            "available": int(status.get("availableReplicas", 0)),
            "images": [
                c.get("image")
                for c in spec.get("template", {})
                .get("spec", {})
                .get("containers") or []
            ],
        })

    return {"deployments": rows, "count": len(rows)}


@tool(
    "list_services",
    "List Services with their type, cluster IP and ports.",
    {"namespace": NAMESPACE},
)
def list_services(namespace=None):
    rows = []
    for s in kube.items(_ns_path(namespace, "/api/v1", "services")):
        spec = s.get("spec", {})

        rows.append({
            "namespace": s["metadata"].get("namespace"),
            "name": s["metadata"].get("name"),
            "type": spec.get("type"),
            "cluster_ip": spec.get("clusterIP"),
            "ports": [
                f"{p.get('port')}/{p.get('protocol', 'TCP')}"
                for p in spec.get("ports") or []
            ],
        })

    return {"services": rows, "count": len(rows)}


@tool(
    "list_nodes",
    "List the cluster's nodes: readiness, kubelet version and allocatable "
    "resources.",
)
def list_nodes():
    rows = []
    for n in kube.items("/api/v1/nodes"):
        status = n.get("status", {})
        ready = next(
            (
                c.get("status") == "True"
                for c in status.get("conditions") or []
                if c.get("type") == "Ready"
            ),
            False,
        )
        alloc = status.get("allocatable") or {}

        rows.append({
            "name": n["metadata"].get("name"),
            "ready": ready,
            "kubelet": (status.get("nodeInfo") or {}).get("kubeletVersion"),
            "cpu": alloc.get("cpu"),
            "memory": alloc.get("memory"),
            "pods": alloc.get("pods"),
        })

    return {"nodes": rows, "count": len(rows)}


@tool(
    "list_events",
    "Recent events, newest first.",
    {
        "namespace": NAMESPACE,
        "limit": {
            "type": "integer",
            "minimum": 1,
            "maximum": 200,
            "default": 20,
        },
        "warnings_only": {"type": "boolean", "default": False},
    },
)
def list_events(namespace=None, limit=20, warnings_only=False):
    params = {"fieldSelector": "type=Warning"} if warnings_only else None
    events = kube.items(_ns_path(namespace, "/api/v1", "events"), params)
    events.sort(
        key=lambda e: e.get("lastTimestamp") or e.get("eventTime") or "",
        reverse=True,
    )

    rows = [
        {
            "namespace": e["metadata"].get("namespace"),
            "object": (
                f"{e.get('involvedObject', {}).get('kind')}/"
                f"{e.get('involvedObject', {}).get('name')}"
            ),
            "type": e.get("type"),
            "reason": e.get("reason"),
            "message": (e.get("message") or "").strip(),
            "count": int(e.get("count") or 1),
            "last_seen": e.get("lastTimestamp") or e.get("eventTime"),
        }
        for e in events[:max(1, min(int(limit), 200))]
    ]

    return {"events": rows, "count": len(rows)}


@tool(
    "pod_logs",
    "The last lines of a pod's log.",
    {
        "namespace": {"type": "string"},
        "name": {"type": "string"},
        "container": {
            "type": "string",
            "description": "Needed when the pod has several containers.",
        },
        "tail": {
            "type": "integer",
            "minimum": 1,
            "maximum": 500,
            "default": 50,
        },
    },
    required=("namespace", "name"),
)
def pod_logs(namespace, name, container=None, tail=50):
    text = kube.request(
        f"/api/v1/namespaces/{namespace}/pods/{name}/log",
        {"container": container, "tailLines": max(1, min(int(tail), 500))},
        raw=True,
    )

    return {
        "pod": f"{namespace}/{name}",
        "container": container,
        "lines": text.splitlines(),
    }


def call(name, arguments):
    """Runs a tool. Returns (data, error message)."""
    entry = TOOLS.get(name)
    if not entry:
        return None, f"unknown tool: {name}"

    try:
        return entry["fn"](**(arguments or {})), None
    except TypeError as e:
        return None, f"bad arguments for {name}: {e}"
    except KubeError as e:
        return None, f"the cluster refused: {e}"


def realm_hour():
    return kube.realm_hour()
