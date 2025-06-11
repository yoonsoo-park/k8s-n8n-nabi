{{/*
Common labels
*/}}
{{- define "n8n-tenant-stack.labels" -}}
helm.sh/chart: {{ include "n8n-tenant-stack.chart" . }}
{{ include "n8n-tenant-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "n8n-tenant-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n-tenant-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Chart name and version
*/}}
{{- define "n8n-tenant-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Full name
*/}}
{{- define "n8n-tenant-stack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Generate basic secret if .Values.*.auth.existingSecret is not set and .Values.*.auth.password is not set */}}
{{- define "n8n-tenant-stack.postgresql.secretName" -}}
{{- if .Values.postgresql.auth.existingSecret }}
    {{- .Values.postgresql.auth.existingSecret -}}
{{- else }}
    {{- include "n8n-tenant-stack.fullname" . }}-postgresql
{{- end -}}
{{- end -}}

{{- define "n8n-tenant-stack.redis.secretName" -}}
{{- if .Values.redis.auth.existingSecret }}
    {{- .Values.redis.auth.existingSecret -}}
{{- else if .Values.redis.auth.enabled }}
    {{- include "n8n-tenant-stack.fullname" . }}-redis
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "n8n-tenant-stack.n8nEncryptionKey.secretName" -}}
{{- if .Values.n8n.encryptionKeySecret.name }}
    {{- .Values.n8n.encryptionKeySecret.name -}}
{{- else }}
    {{- include "n8n-tenant-stack.fullname" . }}-n8n-encryption-key
{{- end -}}
{{- end -}}

{{/* PostgreSQL service fullname */}}
{{- define "n8n-tenant-stack.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "n8n-tenant-stack.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Redis service fullname */}}
{{- define "n8n-tenant-stack.redis.fullname" -}}
{{- printf "%s-redis" (include "n8n-tenant-stack.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
