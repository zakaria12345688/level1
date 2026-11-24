# The grimoire of Achrona

Ixeth, the Watchful Seer, keeps its mind and its remedies here. The Seer reads
this repository on every alert and keeps the realm in step with it.

| Path | What it is |
|---|---|
| `mind/persona.md` | Who the Seer is. Sent to the oracle with every alert |
| `mind/visions/` | Worked examples the Seer learns from |
| `realm/tunings/` | Partial objects (replicas, resources) applied on top of the chart |
| `realm/spirits/` | Whole objects owned by the grimoire. Removed from the realm when removed from here |

Every remedy is a commit. Clone it through the realm's gate (the line from
`terraform output -raw hosts` in `workload/` in your /etc/hosts, user `guild`):

    git clone http://guild@grimoire.achrona.test/realm.git

or from inside the realm:

    kubectl port-forward -n oracle svc/grimoire 8081:80
    git clone http://localhost:8081/realm.git
