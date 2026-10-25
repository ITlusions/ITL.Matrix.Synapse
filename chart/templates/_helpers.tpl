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

{{- define "itl.matrix.synapse.homeserver" -}}
{{- $fullName := include "itl.matrix.synapse.name" . -}}
{{- $namespace := .Release.Namespace -}}
{{- $serverName := .Values.tenant.homeserver.values.serverName -}}
{{- $synapseSecret := lookup "v1" "Secret" $namespace (printf "%s-secrets" $fullName) | default (dict "data" (dict)) -}}
{{- $oidcSecret := lookup "v1" "Secret" $namespace "matrix-synapse-oidc-secret" | default (dict "data" (dict)) -}}
{{- $dbSecret := lookup "v1" "Secret" $namespace (printf "%s-db-app" .Release.Name) | default (dict "data" (dict)) -}}
server_name: "{{ $serverName }}"
public_baseurl: https://{{ $serverName }}
serve_server_wellknown: true
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
# In-cluster CNPG Postgres (templates/cnpg-cluster.yaml) - not
# sqlite3, which was hardcoded here regardless of the postgresql.*
# values existing (confirmed - the old matrix.postgresUri helper that
# built a connection string was defined but never actually called
# anywhere). CNPG's own generated Secret (<release>-db-app) is looked
# up directly rather than built from hand-maintained values, same
# reasoning as removing the hardcoded postgresqlPassword/username/
# password that used to live in values.yaml.
database:
  name: psycopg2
  args:
    user: {{ if $dbSecret.data.username }}{{ $dbSecret.data.username | b64dec }}{{ else }}{{ .Values.postgresql.owner }}{{ end }}
    password: {{ if $dbSecret.data.password }}{{ $dbSecret.data.password | b64dec }}{{ else }}""{{ end }}
    database: {{ if $dbSecret.data.dbname }}{{ $dbSecret.data.dbname | b64dec }}{{ else }}{{ .Values.postgresql.database }}{{ end }}
    host: {{ .Release.Name }}-db-rw
    port: 5432
    cp_min: 5
    cp_max: 10
log_config: "/data/{{ $serverName }}.log.config"
media_store_path: "/data/media_store"
enable_registration: false
registration_shared_secret: "{{ if $synapseSecret.data.registration_shared_secret }}{{ $synapseSecret.data.registration_shared_secret | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
enable_registration_without_verification: true
macaroon_secret_key: "{{ if $synapseSecret.data.macaroon_secret_key }}{{ $synapseSecret.data.macaroon_secret_key | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
form_secret: "{{ if $synapseSecret.data.form_secret }}{{ $synapseSecret.data.form_secret | b64dec }}{{ else }}{{ randAlphaNum 64 }}{{ end }}"
signing_key_path: "/data/{{ $serverName }}.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
{{- if .Values.oidc.enabled }}
oidc_providers:
  - idp_id: itlusions-keycloak
    idp_name: "ITlusions (Keycloak)"
    discover: true
    issuer: {{ .Values.oidc.issuer | quote }}
    client_id: {{ .Values.oidc.clientId | quote }}
    {{- if index $oidcSecret.data "client-secret" }}
    client_secret: "{{ index $oidcSecret.data "client-secret" | b64dec }}"
    {{- end }}
    scopes: ["openid", "profile", "email", "roles"]
    authorization_endpoint: "https://sts.itlusions.com/realms/itlusions/protocol/openid-connect/auth"
    token_endpoint: "https://sts.itlusions.com/realms/itlusions/protocol/openid-connect/token"
    userinfo_endpoint: "https://sts.itlusions.com/realms/itlusions/protocol/openid-connect/userinfo"
    jwks_uri: "https://sts.itlusions.com/realms/itlusions/protocol/openid-connect/certs"
    skip_verification: false
    backchannel_logout_enabled: true
    allow_existing_users: true
    user_mapping_provider:
      config:
        localpart_template: "{{`{{ user.preferred_username | lower | replace('-', '_') | replace('.', '_') }}`}}"
        display_name_template: "{{`{{ user.name or user.preferred_username or user.email }}`}}"
        email_template: "{{`{{ user.email }}`}}"
        attribute_requirements:
          - attribute: "roles"
            value: "student|instructor|admin"
{{- end }}
account_threepid_delegates: {}
report_stats: {{ .Values.tenant.homeserver.values.reportStats }}
opentracing: {}
stats: {}
user_directory: {}
redis: {}
push: {}
spam_checker: {}
{{- end }}