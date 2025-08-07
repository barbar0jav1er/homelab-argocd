{{/*
App name
*/}}
{{- define "pihole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resources full name
*/}}
{{- define "pihole.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Commons Label for all resources
*/}}
{{- define "pihole.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "pihole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector Labels for pods
*/}}
{{- define "pihole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pihole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name for the service account
*/}}
{{- define "pihole.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pihole.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "pihole.secretName" -}}
{{- if .Values.password.create -}}
{{- printf "%s-secret" (include "pihole.fullname" .) -}}
{{- else -}}
{{- .Values.password.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "pihole.secretKey" -}}
{{- if .Values.password.create -}}
admin-password
{{- else -}}
{{- .Values.password.existingSecretKey -}}
{{- end -}}
{{- end -}}