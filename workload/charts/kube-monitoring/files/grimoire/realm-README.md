# The realm, as the grimoire wants it

- `tunings/<namespace>/<deployment>.yaml`: partial Deployments. The Seer applies
  them with server-side apply on top of what the chart installed.
- `spirits/`: whole objects the grimoire owns, labelled
  `grimoire.achrona.io/realm=true`. When a spirit leaves the grimoire, the Seer
  removes it from the realm.
