{{- define "ao.labels" -}}
app.kubernetes.io/name: ancient-oracle
app.kubernetes.io/part-of: ancient
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
