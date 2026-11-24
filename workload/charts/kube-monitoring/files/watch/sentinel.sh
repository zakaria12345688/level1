#!/bin/sh
# The sentinel: watches a namespace and raises alerts in Alertmanager.
#   ScrollOutOfMemory    a container was OOMKilled
#   ScrollServiceSilent  a deployment has no ready replicas on two scans in a row
#                        (and nothing in it was OOMKilled)
set -u
AM="${ALERTMANAGER_URL:-http://alertmanager:9093}"
NS="${WATCH_NAMESPACE:-scrolls}"
RUNBOOKS=/etc/sentinel/runbooks.json
INTERVAL="${INTERVAL:-30}"
SEEN=/tmp/silent-last-scan
: > "$SEEN"
echo "[sentinel] watching $NS, alerting $AM every ${INTERVAL}s"
while true; do
  if pods=$(kubectl get pods -n "$NS" -o json) && deps=$(kubectl get deployments -n "$NS" -o json); then
    silent_before=$(cat "$SEEN")
    alerts=$(jq -cn --argjson pods "$pods" --argjson deps "$deps" --slurpfile rb "$RUNBOOKS" '
      $rb[0] as $rb | (now | todate) as $start | ((now + 180) | todate) as $end |
      [ $pods.items[] as $p | ($p.status.containerStatuses // [])[] as $c
        | select(($c.lastState.terminated.reason // $c.state.terminated.reason // "") == "OOMKilled")
        | ([$p.spec.containers[] | select(.name == $c.name) | .resources.limits.memory // "none"][0]) as $limit
        | {labels: {alertname: "ScrollOutOfMemory", severity: "critical", namespace: $p.metadata.namespace,
                    deployment: ($p.metadata.labels["app.kubernetes.io/name"] // "unknown"), container: $c.name},
           annotations: {summary: "\($c.name) in \($p.metadata.name) was OOMKilled (\($c.restartCount) restarts, memory limit \($limit))",
                         runbook: $rb.ScrollOutOfMemory},
           startsAt: $start, endsAt: $end} ] as $oom |
      ($oom | map(.labels.deployment)) as $oomed |
      $oom + [ $deps.items[] | select((.status.readyReplicas // 0) == 0) | select(.metadata.name as $n | $oomed | index($n) | not)
        | {labels: {alertname: "ScrollServiceSilent", severity: "critical", namespace: .metadata.namespace, deployment: .metadata.name},
           annotations: {summary: "\(.metadata.name) has no ready replicas (\(.spec.replicas // 0) desired)",
                         runbook: $rb.ScrollServiceSilent},
           startsAt: $start, endsAt: $end} ]
      | unique_by(.labels)')
    echo "$alerts" | jq -r '[.[] | select(.labels.alertname == "ScrollServiceSilent") | .labels.deployment] | join(" ")' > "$SEEN"
    alerts=$(echo "$alerts" | jq -c --arg before " $silent_before " '[.[] | .labels.deployment as $d | select(.labels.alertname != "ScrollServiceSilent" or ($before | contains(" " + $d + " ")))]')
    count=$(echo "$alerts" | jq length)
    if [ "$count" -gt 0 ]; then
      if curl -fsS -m 10 -X POST -H 'Content-Type: application/json' -d "$alerts" "$AM/api/v2/alerts" >/dev/null; then
        echo "[sentinel] $(date -u +%H:%M:%S) raised: $(echo "$alerts" | jq -r '[.[] | "\(.labels.alertname) \(.labels.deployment)"] | join(", ")')"
      else
        echo "[sentinel] $(date -u +%H:%M:%S) Alertmanager unreachable"
      fi
    fi
  else
    echo "[sentinel] $(date -u +%H:%M:%S) cannot read $NS"
  fi
  sleep "$INTERVAL"
done
