#!/usr/bin/env bash
# CI-0144 - Etapa 2
# Verificación periódica de servicios DNS y DHCP.
#
# DNS: realiza consultas reales a los servidores.
# DHCP: comprueba que Prometheus reciba métricas recientes de Kea.
# Publica resultados para Node Exporter (textfile collector).
#
# No modifica servicios ni configuraciones de red.

set -Eeuo pipefail

readonly DOMAIN="g04.ci0144.cr"
readonly METRICS_DIR="/var/lib/node_exporter/textfile_collector"
readonly METRICS_FILE="${METRICS_DIR}/service_checks.prom"
readonly PROMETHEUS_URL="http://127.0.0.1:9090"
readonly MAX_METRIC_AGE=120

TEMP_FILE=""

# Eliminar archivos temporales incluso cuando ocurre un error.
cleanup() {
    if [[ -n "$TEMP_FILE" ]]; then
        rm -f -- "$TEMP_FILE"
    fi
}
trap cleanup EXIT

# Registrar mensajes para su consulta mediante journalctl.
log_message() {
    echo "$(date -Is) [$1] $2" >&2
}

# Consultar un DNS autoritativo y verificar respuesta SOA con bandera AA.
check_authoritative_dns() {
    local ip="$1"
    local response

    response="$(timeout 8 dig @"$ip" "$DOMAIN" SOA \
        +norecurse +time=2 +tries=1 2>/dev/null)" || return 1

    grep -q 'status: NOERROR' <<< "$response" || return 1
    grep -Eq 'flags:.*\baa\b' <<< "$response" || return 1
    grep -q 'SOA' <<< "$response" || return 1
}

# Comprobar que el resolvedor pueda resolver un dominio externo.
check_recursive_dns() {
    local response

    response="$(timeout 8 dig @10.4.1.21 example.com A \
        +time=2 +tries=1 +short 2>/dev/null)" || return 1

    [[ -n "$response" ]]
}

# Consultar la antigüedad de las métricas Kea en Prometheus.
# Se exige al menos una muestra reciente por servidor DHCP.
check_dhcp_metrics() {
    local server="$1"
    local query response

    query="count(time() - timestamp(kea_dhcp_pool_utilization_percent{instance=\"${server}\"}) < ${MAX_METRIC_AGE})"

    response="$(curl --fail --silent --show-error --get \
        --max-time 8 \
        --data-urlencode "query=$query" \
        "${PROMETHEUS_URL}/api/v1/query")" || return 1

    # La API devuelve un vector vacío si no hay datos.
    # Extraemos el valor numérico de la respuesta con Python.
    python3 -c '
import json
import sys

try:
    payload = json.load(sys.stdin)
    results = payload["data"]["result"]
    if payload.get("status") != "success" or not results:
        sys.exit(1)
    count = float(results[0]["value"][1])
    sys.exit(0 if count > 0 else 1)
except (KeyError, ValueError, TypeError, IndexError):
    sys.exit(1)
' <<< "$response"
}

# Ejecutar una comprobación y publicar siempre un resultado 0 o 1.
record_check() {
    local service="$1"
    local site="$2"
    local server="$3"
    shift 3

    local status=0

    if "$@"; then
        status=1
        log_message "OK" "$service - $site - $server"
    else
        log_message "ERROR" "$service - $site - $server"
    fi

    printf 'ci0144_service_up{service="%s",site="%s",server="%s"} %s\n' \
        "$service" "$site" "$server" "$status" >> "$TEMP_FILE"
}

main() {
    log_message "INFO" "Iniciando verificación de servicios"

    # Archivo temporal en el mismo directorio para publicación atómica.
    TEMP_FILE="$(mktemp "${METRICS_DIR}/.service_checks.XXXXXX")"
    chmod 644 "$TEMP_FILE"

    {
        echo '# HELP ci0144_service_up Estado del servicio (1=OK, 0=fallo)'
        echo '# TYPE ci0144_service_up gauge'
    } > "$TEMP_FILE"

    # DNS autoritativo de las tres sedes.
    record_check dns_authoritative SJO dns01.sjo \
        check_authoritative_dns 10.4.1.20

    record_check dns_authoritative LIM dns01.lim \
        check_authoritative_dns 10.4.19.20

    record_check dns_authoritative CAR dns01.car \
        check_authoritative_dns 10.4.35.20

    # DNS recursivo interno.
    record_check dns_recursive SJO resolver01.sjo \
        check_recursive_dns

    # DHCP: verificar métricas recientes de cada servidor Kea.
    record_check dhcp_metrics SJO dhcp01.sjo \
        check_dhcp_metrics dhcp01.sjo

    record_check dhcp_metrics LIM dhcp01.lim \
        check_dhcp_metrics dhcp01.lim

    record_check dhcp_metrics CAR dhcp01.car \
        check_dhcp_metrics dhcp01.car

    # Publicar resultados completos, nunca un archivo parcial.
    mv -f -- "$TEMP_FILE" "$METRICS_FILE"
    TEMP_FILE=""

    log_message "INFO" "Verificación finalizada correctamente"
}

main "$@"
