{{/* Базовое имя релиза, обрезанное до 63 символов (ограничение DNS-меток k8s). */}}
{{- define "tunduk.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tunduk.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "tunduk.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "tunduk.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: tunduk-security-server
{{- end -}}

{{/* Имена и селекторы для сервера безопасности. */}}
{{- define "tunduk.ss.fullname" -}}
{{- printf "%s-ss" (include "tunduk.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tunduk.ss.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tunduk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: security-server
{{- end -}}

{{/* Имена и селекторы для встроенной БД. */}}
{{- define "tunduk.db.fullname" -}}
{{- printf "%s-db" (include "tunduk.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tunduk.db.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tunduk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end -}}

{{/* Имя Secret: готовый existingSecret либо сгенерированный чартом. */}}
{{- define "tunduk.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "tunduk.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Имя ServiceAccount. */}}
{{- define "tunduk.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "tunduk.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Хост БД: headless service встроенной БД либо внешний хост. */}}
{{- define "tunduk.dbHost" -}}
{{- if .Values.postgresql.embedded -}}
{{- include "tunduk.db.fullname" . -}}
{{- else -}}
{{- required "externalDatabase.host обязателен при postgresql.embedded=false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{- define "tunduk.dbPort" -}}
{{- if .Values.postgresql.embedded -}}
5432
{{- else -}}
{{- .Values.externalDatabase.port | default 5432 -}}
{{- end -}}
{{- end -}}
