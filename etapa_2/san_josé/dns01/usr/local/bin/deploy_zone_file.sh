#!/usr/bin/env bash
# CI-0144 - Despliegue automatico de zonas DNS estaticas
#
# Funciones:
# - Revisar cinco zonas primarias estaticas.
# - Detectar cambios en cada archivo fuente.
# - Incrementar automaticamente el serial SOA.
# - Validar la zona antes del despliegue.
# - Recargar exclusivamente la zona modificada.
# - Verificar el serial cargado por BIND.
# - Restaurar el archivo anterior ante errores.
# - Evitar ejecuciones simultaneas.
# - Registrar los resultados en journald.
#
# No modifica zonas dinamicas administradas por Kea.

set -Eeuo pipefail

readonly SOURCE_DIR="/etc/dns-deploy/zones"
readonly TARGET_DIR="/var/named/master"
readonly LOCK_FILE="/run/ci0144-dns-zone-deploy.lock"

readonly ZONES=(
    "1.4.10.in-addr.arpa"
    "19.4.10.in-addr.arpa"
    "17.4.10.in-addr.arpa"
    "33.4.10.in-addr.arpa"
    "35.4.10.in-addr.arpa"
)

TEMP=""
BACKUP=""
ACTIVE_ZONE=""
ACTIVE_TARGET=""
DEPLOY_STARTED=0

log() {
    local level="$1"
    shift
    echo "$(date -Is) [$level] $*" >&2
}

cleanup() {
    [[ -z "$TEMP" ]] || rm -f -- "$TEMP"
    [[ -z "$BACKUP" ]] || rm -f -- "$BACKUP"
    TEMP=""
    BACKUP=""
}

restore_backup() {
    if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
        log ERROR "Restaurando zona $ACTIVE_ZONE"

        cp -a -- "$BACKUP" "$ACTIVE_TARGET"
        restorecon "$ACTIVE_TARGET"

        if ! rndc reload "$ACTIVE_ZONE"; then
            log ERROR "No se pudo recargar la zona restaurada"
            return 1
        fi
    fi
}

on_error() {
    local status=$?

    trap - ERR

    log ERROR "Despliegue fallido en ${ACTIVE_ZONE:-general}. Codigo: $status"

    if (( DEPLOY_STARTED == 1 )); then
        restore_backup || true
    fi

    cleanup
    exit "$status"
}

trap on_error ERR
trap cleanup EXIT

# Evitar despliegues simultaneos.
exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    log ERROR "Ya existe otro despliegue en ejecucion"
    exit 1
fi

# Extraer el serial SOA con o sin comentario "; Serial".
get_serial() {
    local file="$1"

    awk '
        /[[:space:]]SOA[[:space:]]/ {
            in_soa = 1
            next
        }
        in_soa && /^[[:space:]]*[0-9]{10}([[:space:]]|$)/ {
            print $1
            found++
            exit
        }
        END {
            if (found != 1) exit 1
        }
    ' "$file"
}

# Comparar archivos ignorando exclusivamente el serial SOA.
normalized_zone() {
    awk '
        /[[:space:]]SOA[[:space:]]/ {
            in_soa = 1
            print
            next
        }
        in_soa && /^[[:space:]]*[0-9]{10}([[:space:]]|$)/ {
            sub(/[0-9]{10}/, "SERIAL")
            in_soa = 0
        }
        { print }
    ' "$1"
}

# Sustituir exclusivamente el serial SOA.
set_serial() {
    local file="$1"
    local serial="$2"

    awk -v serial="$serial" '
        /[[:space:]]SOA[[:space:]]/ {
            in_soa = 1
            print
            next
        }
        in_soa && /^[[:space:]]*[0-9]{10}([[:space:]]|$)/ {
            sub(/[0-9]{10}/, serial)
            in_soa = 0
        }
        { print }
    ' "$file"
}

# Calcular un serial AAAAMMDDNN estrictamente creciente.
next_serial() {
    local old="$1"
    local today old_date old_sequence sequence

    today="$(date +%Y%m%d)"
    old_date="${old:0:8}"
    old_sequence="${old:8:2}"

    if [[ "$old_date" > "$today" ]]; then
        log ERROR "Serial con fecha futura: $old"
        return 1
    fi

    if [[ "$old_date" == "$today" ]]; then
        sequence=$((10#$old_sequence + 1))
    else
        sequence=0
    fi

    if (( sequence > 99 )); then
        log ERROR "Se agotaron los seriales disponibles para hoy"
        return 1
    fi

    printf '%s%02d\n' "$today" "$sequence"
}

# Consultar el serial cargado por BIND.
loaded_serial() {
    local zone="$1"

    rndc zonestatus "$zone" |
        awk '/^serial:/ { print $2; exit }'
}

# Esperar a que BIND cargue el serial esperado.
wait_for_serial() {
    local zone="$1"
    local expected="$2"
    local current=""
    local attempt

    for attempt in {1..10}; do
        current="$(loaded_serial "$zone")" || true

        if [[ "$current" == "$expected" ]]; then
            return 0
        fi

        sleep 1
    done

    log ERROR "Zona $zone: serial esperado $expected; cargado $current"
    return 1
}

# Desplegar una zona individual.
deploy_zone() {
    local zone="$1"
    local source="${SOURCE_DIR}/${zone}.zone"
    local target="${TARGET_DIR}/${zone}.zone"
    local old_serial source_serial new_serial current_serial

    ACTIVE_ZONE="$zone"
    ACTIVE_TARGET="$target"
    DEPLOY_STARTED=0

    log INFO "Iniciando revision de zona $zone"

    if [[ ! -r "$source" || ! -f "$target" ]]; then
        log ERROR "Archivo fuente o activo no disponible para $zone"
        return 1
    fi

    old_serial="$(get_serial "$target")" || return 1
    source_serial="$(get_serial "$source")" || return 1

    if [[ ! "$old_serial" =~ ^[0-9]{10}$ ||
          ! "$source_serial" =~ ^[0-9]{10}$ ]]; then
        log ERROR "Formato de serial SOA invalido en $zone"
        return 1
    fi

    # Comprobar que el archivo activo coincide con BIND.
    current_serial="$(loaded_serial "$zone")" || return 1

    if [[ "$current_serial" != "$old_serial" ]]; then
        log ERROR "Serial activo y serial cargado no coinciden en $zone"
        return 1
    fi

    # No modificar zonas que no tengan cambios.
    if diff -q \
        <(normalized_zone "$source") \
        <(normalized_zone "$target") \
        >/dev/null; then

        log INFO "Sin cambios en $zone. Serial actual: $old_serial"
        return 0
    fi

    new_serial="$(next_serial "$old_serial")" || return 1

    log INFO "Cambios detectados en $zone"
    log INFO "Incrementando serial: $old_serial -> $new_serial"

    TEMP="$(mktemp "${target}.tmp.XXXXXX")"
    BACKUP="$(mktemp "${target}.backup.XXXXXX")"

    cp -a -- "$target" "$BACKUP"

    set_serial "$source" "$new_serial" > "$TEMP"

    chown --reference="$target" "$TEMP"
    chmod --reference="$target" "$TEMP"
    chcon --reference="$target" "$TEMP"

    # Validar antes de sustituir el archivo activo.
    if ! named-checkzone "$zone" "$TEMP"; then
        log ERROR "Validacion DNS fallida en $zone"
        cleanup
        return 1
    fi

    DEPLOY_STARTED=1

    mv -f -- "$TEMP" "$target"
    TEMP=""

    restorecon "$target"

    log INFO "Recargando zona $zone"

    if ! rndc reload "$zone"; then
        log ERROR "BIND rechazo la recarga de $zone"
        return 1
    fi

    if ! wait_for_serial "$zone" "$new_serial"; then
        log ERROR "BIND no cargo el serial esperado en $zone"
        return 1
    fi

    DEPLOY_STARTED=0

    log OK "Zona desplegada correctamente: $zone"
    log OK "Serial SOA: $new_serial"

    cleanup
}

main() {
    local command zone

    for command in awk sed diff mktemp cp mv chown chmod \
                   chcon restorecon named-checkzone rndc flock; do

        command -v "$command" >/dev/null || {
            log ERROR "Herramienta no disponible: $command"
            return 1
        }
    done

    for zone in "${ZONES[@]}"; do
        deploy_zone "$zone" || return 1
    done

    log OK "Revision de las cinco zonas finalizada correctamente"
}

main "$@"
