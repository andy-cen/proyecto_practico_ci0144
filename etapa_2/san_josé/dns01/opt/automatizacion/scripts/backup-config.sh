#!/bin/bash
# Respaldo diario de configuraciones de dns01.sjo hacia dns01.lim.
# Evita duplicados, reintenta transferencias y registra errores.

set -Eeuo pipefail
umask 077

readonly INVENTARIO="/opt/automatizacion/scripts/backup-files.txt"
readonly BACKUP_DIR="/var/backups/configuraciones"
readonly STATE_DIR="/var/lib/backup-config"
readonly LOCK_FILE="/run/backup-config.lock"

readonly SSH_KEY="/opt/automatizacion/keys/backup-sjo-to-lim"
readonly KNOWN_HOSTS="/opt/automatizacion/keys/known_hosts"
readonly DESTINO="backup-sjo@10.4.19.20:"

readonly HASH_FILE="${STATE_DIR}/ultimo-hash"
readonly BACKUP_FILE="${STATE_DIR}/ultimo-archivo"
readonly PENDING_FILE="${STATE_DIR}/transferencia-pendiente"

TEMPORAL=""
ARCHIVO_NUEVO=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

finalizar() {
    local codigo=$?

    if [[ -n "$TEMPORAL" ]]; then
        rm -f -- "$TEMPORAL"
    fi

    if (( codigo != 0 )); then
        log "ERROR: Respaldo finalizado con codigo $codigo"
    fi
}

trap finalizar EXIT

transferir() {
    local archivo="$1"

    log "Transfiriendo: $archivo"

    rsync -av \
        -e "ssh -i ${SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${KNOWN_HOSTS}" \
        "${BACKUP_DIR}/${archivo}" \
        "$DESTINO"
}

guardar_estado() {
    local archivo="$1"
    local hash="$2"

    printf '%s\n' "$hash" > "${HASH_FILE}.tmp"
    printf '%s\n' "$archivo" > "${BACKUP_FILE}.tmp"

    mv -f "${HASH_FILE}.tmp" "$HASH_FILE"
    mv -f "${BACKUP_FILE}.tmp" "$BACKUP_FILE"

    rm -f "$PENDING_FILE"
}

if (( EUID != 0 )); then
    log "ERROR: El script requiere permisos root"
    exit 1
fi

exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    log "INFO: Ya existe otro respaldo en ejecucion"
    exit 0
fi

log "INICIO: Respaldo de dns01.sjo"

for herramienta in tar rsync ssh sha256sum rndc find mktemp; do
    if ! command -v "$herramienta" > /dev/null; then
        log "ERROR: Falta la herramienta $herramienta"
        exit 1
    fi
done

for archivo in "$INVENTARIO" "$SSH_KEY" "$KNOWN_HOSTS"; do
    if [[ ! -f "$archivo" ]]; then
        log "ERROR: No existe $archivo"
        exit 1
    fi
done

mkdir -p "$BACKUP_DIR" "$STATE_DIR"
chmod 700 "$BACKUP_DIR" "$STATE_DIR"

while IFS= read -r ruta || [[ -n "$ruta" ]]; do
    [[ -z "$ruta" ]] && continue

    if [[ ! -e "$ruta" ]]; then
        log "ERROR: Ruta inexistente: $ruta"
        exit 1
    fi
done < "$INVENTARIO"

# Recuperar transferencias pendientes antes de crear otro respaldo.
if [[ -f "$PENDING_FILE" ]]; then
    PENDIENTE="$(cat "$PENDING_FILE")"

    if [[ ! -f "${BACKUP_DIR}/${PENDIENTE}" ]]; then
        log "ERROR: No existe el respaldo pendiente: $PENDIENTE"
        exit 1
    fi

    log "Reintentando transferencia pendiente"

    transferir "$PENDIENTE"

    HASH_PENDIENTE="$(
        sha256sum "${BACKUP_DIR}/${PENDIENTE}" |
        awk '{print $1}'
    )"

    guardar_estado "$PENDIENTE" "$HASH_PENDIENTE"

    log "Transferencia pendiente recuperada correctamente"
fi

# Sincronizar zonas dinamicas de BIND.
log "Sincronizando zonas DNS"
rndc sync

# Generar archivo temporal seguro.
TEMPORAL="$(mktemp "${BACKUP_DIR}/.dns01-sjo-XXXXXXXX.tar.gz")"

log "Generando respaldo temporal"

tar -czf "$TEMPORAL" -C / -T "$INVENTARIO"

# Comprobar integridad del archivo.
tar -tzf "$TEMPORAL" > /dev/null

# El hash corresponde exactamente al archivo generado.
HASH_ACTUAL="$(
    sha256sum "$TEMPORAL" |
    awk '{print $1}'
)"

FECHA="$(TZ=America/Costa_Rica date '+%Y%m%d')"
NOMBRE="dns01-sjo-${FECHA}-${HASH_ACTUAL:0:16}.tar.gz"

# Mismo contenido y misma fecha: reutilizar archivo.
if [[ -f "${BACKUP_DIR}/${NOMBRE}" ]]; then
    HASH_EXISTENTE="$(
        sha256sum "${BACKUP_DIR}/${NOMBRE}" |
        awk '{print $1}'
    )"

    if [[ "$HASH_ACTUAL" != "$HASH_EXISTENTE" ]]; then
        log "ERROR: El respaldo existente no coincide con su hash"
        exit 1
    fi

    log "SIN CAMBIOS: Reutilizando respaldo existente"
else
    mv -- "$TEMPORAL" "${BACKUP_DIR}/${NOMBRE}"
    TEMPORAL=""

    chmod 600 "${BACKUP_DIR}/${NOMBRE}"

    log "Nuevo respaldo creado: $NOMBRE"
fi

# Registrar la transferencia pendiente antes de iniciarla.
printf '%s\n' "$NOMBRE" > "$PENDING_FILE"

transferir "$NOMBRE"

# Guardar estado solamente despues de transferir correctamente.
guardar_estado "$NOMBRE" "$HASH_ACTUAL"

# Retener respaldos locales durante 14 dias.
find "$BACKUP_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'dns01-sjo-*.tar.gz' \
    -mtime +13 \
    ! -name "$NOMBRE" \
    -delete

log "EXITO: Respaldo completado: $NOMBRE"
