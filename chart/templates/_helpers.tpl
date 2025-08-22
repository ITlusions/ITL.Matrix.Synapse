{{/*
Expand the name of the chart.
*/}}
{{- define "itl.matrix.synapse.name" -}}
{{- default .Chart.Name .Values.tenant.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "itl.matrix.synapse.fullname" -}}
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
{{- define "itl.matrix.synapse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "itl.matrix.synapse.labels" -}}
helm.sh/chart: {{ include "itl.matrix.synapse.chart" . }}
{{ include "itl.matrix.synapse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "itl.matrix.synapse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "itl.matrix.synapse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "itl.matrix.synapse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "itl.matrix.synapse.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "matrix.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "matrix.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "matrix.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "matrix.labels" -}}
helm.sh/chart: {{ include "matrix.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: "matrix"
{{- end -}}
# TODO: Include labels from values
{{/*
Synapse specific labels
*/}}
{{- define "matrix.synapse.labels" -}}
{{- range $key, $val := .Values.synapse.labels -}}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}

{{/*
Element specific labels
*/}}
#TOOO: Change riot to element
{{- define "matrix.element.labels" -}}
{{- range $key, $val := .Values.riot.labels }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}

{{/*
Coturn specific labels
*/}}
{{- define "matrix.coturn.labels" -}}
{{- range $key, $val := .Values.coturn.labels -}}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}

{{/*
Mail relay specific labels
*/}}
{{- define "matrix.mail.labels" -}}
{{- range $key, $val := .Values.mail.relay.labels -}}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}

{{/*
Synapse hostname, derived from either the Values.matrix.hostname override or the Ingress definition
*/}}
{{- define "matrix.hostname" -}}
{{- if .Values.matrix.hostname }}
{{- .Values.matrix.hostname -}}
{{- else }}
{{- .Values.ingress.hosts.synapse -}}
{{- end }}
{{- end }}

{{/*
Synapse hostname prepended with https:// to form a complete URL
*/}}
{{- define "matrix.baseUrl" -}}
{{- if .Values.matrix.hostname }}
{{- printf "https://%s" .Values.matrix.hostname -}}
{{- else }}
{{- printf "https://%s" .Values.ingress.hosts.synapse -}}
{{- end }}
{{- end }}

{{/*
Helper function to get a postgres connection string for the database, with all of the auth and SSL settings automatically applied
*/}}
{{- define "matrix.postgresUri" -}}
{{- if .Values.postgresql.enabled -}}
postgres://{{ .Values.postgresql.username }}:{{ .Values.postgresql.password }}@{{ include "matrix.fullname" . }}-postgresql/%s{{ if .Values.postgresql.ssl }}?ssl=true&sslmode={{ .Values.postgresql.sslMode}}{{ end }}
{{- else -}}
postgres://{{ .Values.postgresql.username }}:{{ .Values.postgresql.password }}@{{ .Values.postgresql.hostname }}:{{ .Values.postgresql.port }}/%s{{ if .Values.postgresql.ssl }}?ssl=true&sslmode={{ .Values.postgresql.sslMode }}{{ end }}
{{- end }}
{{- end }}

{{- define "itl.matrix.synapse.homeserver" -}}
server_name: "matrix.dev.itlusions.com"
pid_file: /data/homeserver.pid
presence:
  presence_router: {}
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
database:
  name: sqlite3
  args:
    database: /data/homeserver.db
log_config: "/data/matrix.dev.itlusions.com.log.config"
media_store_path: "/data/media_store"
registration_shared_secret: "maQKuVjpSMBH@#F9VOmW7g#DqSwm_VYDM;ajb6^3QBf,8VhXYg"
macaroon_secret_key: "uLJ62kwNWO_DLcKAmbzqYkFwlDQWjNl5@G#SKT*i9~bZrZy~_@"
form_secret: "2iTjom-bIq5Yh6:afKjUed^2Eokx8cd_kzdUN,A#0MFAn.tSrC"
signing_key_path: "/data/matrix.dev.itlusions.com.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
account_threepid_delegates: {}
report_stats: true
opentracing: {}
stats: {}
user_directory: {}
redis: {}
push: {}
spam_checker: {}
{{- end }}