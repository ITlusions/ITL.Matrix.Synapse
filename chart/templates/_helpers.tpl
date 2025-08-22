{{/*
Expand the name of the chart.
*/}}
{{- define "itl.matrix.synapse.name" -}}
{{- default .Release.Name .Values.tenant.name | trunc 63 | trimSuffix "-" }}
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
{{- $secretName := printf "%s-secret" (include "itl.matrix.synapse.name" .) -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace $secretName | default (dict "data" (dict)) -}}
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
enable_registration: false
registration_shared_secret: "{{ if and $secret.data (index $secret.data "registrationSharedSecret") }}{{ index $secret.data "registrationSharedSecret" | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
enable_registration_without_verification: true
macaroon_secret_key: "{{ if and $secret.data (index $secret.data "macaroonSecretKey") }}{{ index $secret.data "macaroonSecretKey" | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
form_secret: "{{ if and $secret.data (index $secret.data "formSecret") }}{{ index $secret.data "formSecret" | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
signing_key_path: "/data/matrix.dev.itlusions.com.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
oidc_providers:
  - idp_id: itlusions-keycloak
    idp_name: "ITlusions (keycloak)"
    discover: true
    issuer: "https://sts.itlusions.com/realms/itlusions"   # Keycloak realm issuer
    client_id: "synapse-tenant1"                            # client you created in Keycloak
    client_secret: "{{ if and $secret.data (index $secret.data "clientSecret") }}{{ index $secret.data "clientSecret" | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"               # inject from k8s secret
    scopes: ["openid", "profile", "email"]
    backchannel_logout_enabled: true
    user_mapping_provider:
      config:
        localpart_template: "{{`{{ user.preferred_username or user.sub }}`}}"
        display_name_template: "{{`{{ user.name or user.preferred_username or user.email }}`}}"
        email_template: "{{`{{ user.email }}`}}"
account_threepid_delegates: {}
report_stats: true
opentracing: {}
stats: {}
user_directory: {}
redis: {}
push: {}
spam_checker: {}
{{- end }}