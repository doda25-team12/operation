{{/*
Expand the name of the chart.
*/}}
{{- define "sms-spam-detector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "sms-spam-detector.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "sms-spam-detector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "sms-spam-detector.labels" -}}
helm.sh/chart: {{ include "sms-spam-detector.chart" . }}
{{ include "sms-spam-detector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "sms-spam-detector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sms-spam-detector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Model Service labels
*/}}
{{- define "sms-spam-detector.modelService.labels" -}}
{{ include "sms-spam-detector.labels" . }}
app: {{ .Values.modelService.name }}
component: backend
{{- end }}

{{/*
Model Service selector labels
*/}}
{{- define "sms-spam-detector.modelService.selectorLabels" -}}
app: {{ .Values.modelService.name }}
{{- end }}

{{/*
App Service labels
*/}}
{{- define "sms-spam-detector.appService.labels" -}}
{{ include "sms-spam-detector.labels" . }}
app: {{ .Values.appService.name }}
component: frontend
{{- end }}

{{/*
App Service selector labels
*/}}
{{- define "sms-spam-detector.appService.selectorLabels" -}}
app: {{ .Values.appService.name }}
{{- end }}

{{/*
Full image name for model service
*/}}
{{- define "sms-spam-detector.modelService.image" -}}
{{- printf "%s/%s/%s:%s" .Values.imageRegistry .Values.imageOrganization .Values.modelService.image.repository .Values.modelService.image.tag }}
{{- end }}

{{/*
Full image name for app service
*/}}
{{- define "sms-spam-detector.appService.image" -}}
{{- printf "%s/%s/%s:%s" .Values.imageRegistry .Values.imageOrganization .Values.appService.image.repository .Values.appService.image.tag }}
{{- end }}
