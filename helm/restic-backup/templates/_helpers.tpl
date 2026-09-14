{{/*
Expand the name of the chart.
*/}}
{{- define "restic-backup.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Repository secret key helper
*/}}
{{- define "restic-backup.repositoryKey" -}}
{{- if .Values.secret.repositoryKey }}
{{- .Values.secret.repositoryKey }}
{{- else }}
{{- printf "%s-repository" .Values.nodeName }}
{{- end }}
{{- end }}
