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

{{/*
Returns "true" if type is explicitly StatefulSet or if any pod_additional_ports entry has host_port set.
Used to decide whether to deploy a StatefulSet vs a Deployment.
*/}}
{{- define "homelab-application.isStatefulSet" -}}
{{- if or (eq .Values.type "StatefulSet") (eq (include "homelab-application.hasHostPort" .) "true") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Returns the desired replica count, preserving explicit 0 instead of falling back to 1.
*/}}
{{- define "homelab-application.replicas" -}}
{{- if and (hasKey .Values "replicas") (not (kindIs "invalid" .Values.replicas)) -}}
{{- int .Values.replicas -}}
{{- else -}}
1
{{- end -}}
{{- end -}}

