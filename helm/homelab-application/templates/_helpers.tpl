{{/*
Returns "true" if any pod_additional_ports entry has host_port set.
Used to decide whether to deploy a StatefulSet (hostPort) vs a Deployment.

Usage: {{ if eq (include "homelab-application.hasHostPort" .) "true" }}...StatefulSet...{{ end }}
*/}}
{{- define "homelab-application.hasHostPort" -}}
{{- $has := false -}}
{{- range .Values.pod_additional_ports -}}
{{- if .host_port -}}{{- $has = true -}}{{- end -}}
{{- end -}}
{{- if $has -}}true{{- else -}}false{{- end -}}
{{- end -}}
