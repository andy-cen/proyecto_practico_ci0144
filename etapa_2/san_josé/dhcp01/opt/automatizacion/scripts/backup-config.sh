#!/bin/bash
# CI-0144: respaldo de dhcp01.sjo hacia la sede LIM.
# Ejecutar como root; no incrustar contraseñas ni claves privadas.
set -Eeuo pipefail
umask 077

readonly SITE="sjo"
readonly HOST="dhcp01"
readonly INVENTARIO="/opt/automatizacion/scripts/backup-files.txt"
readonly CONF="/etc/backup-config/backup.conf"
readonly BACKUP_DIR="/var/backups/configuraciones"
readonly STATE_DIR="/var/lib/backup-config"
readonly LOCK_FILE="/run/backup-config.lock"
readonly SSH_KEY="/opt/automatizacion/keys/backup-to-lim"
readonly KNOWN_HOSTS="/opt/automatizacion/keys/known_hosts"
readonly DEST_USER="backup-sjo-dhcp01"
readonly DEST_PATH="/srv/backups/sjo/dhcp01/"

TEMPORAL=""
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
cleanup() {
  local status=$?
  [[ -z "$TEMPORAL" ]] || rm -f -- "$TEMPORAL"
  (( status == 0 )) || log "ERROR: respaldo terminado con codigo $status"
}
trap cleanup EXIT

transferir() {
  local nombre="$1"
  log "Transferencia: $nombre"
  rsync -av --checksum \
    -e "ssh -i $SSH_KEY -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$KNOWN_HOSTS -o ConnectTimeout=10" \
    "$BACKUP_DIR/$nombre" "$DEST_USER@$DEST_HOST:"
}

guardar_estado() {
  local nombre="$1" hash="$2"
  printf '%s\n' "$hash" > "$STATE_DIR/ultimo-hash.tmp"
  printf '%s\n' "$nombre" > "$STATE_DIR/ultimo-archivo.tmp"
  mv -f "$STATE_DIR/ultimo-hash.tmp" "$STATE_DIR/ultimo-hash"
  mv -f "$STATE_DIR/ultimo-archivo.tmp" "$STATE_DIR/ultimo-archivo"
  rm -f -- "$STATE_DIR/transferencia-pendiente"
}

(( EUID == 0 )) || { log 'ERROR: se requiere root'; exit 1; }
exec 9>"$LOCK_FILE"
flock -n 9 || { log 'INFO: respaldo ya en ejecucion'; exit 0; }
log "INICIO: $HOST.$SITE"

for cmd in tar rsync ssh sha256sum find mktemp awk; do
  command -v "$cmd" >/dev/null || { log "ERROR: falta $cmd"; exit 1; }
done
[[ -f "$CONF" ]] || { log "ERROR: falta $CONF"; exit 1; }
# Archivo root:root 0600, solo con DEST_HOST=IP_o_FQDN.
# shellcheck source=/dev/null
source "$CONF"
: "${DEST_HOST:?ERROR: DEST_HOST no configurado}"
[[ "$DEST_HOST" != 'REEMPLAZAR_IP_O_FQDN' ]] || { log 'ERROR: configurar IP destino'; exit 1; }
for f in "$INVENTARIO" "$SSH_KEY" "$KNOWN_HOSTS"; do
  [[ -f "$f" ]] || { log "ERROR: falta $f"; exit 1; }
done
[[ -s "$INVENTARIO" ]] || { log 'ERROR: inventario vacio'; exit 1; }
mkdir -p "$BACKUP_DIR" "$STATE_DIR"
chmod 700 "$BACKUP_DIR" "$STATE_DIR"
while IFS= read -r ruta || [[ -n "$ruta" ]]; do
  [[ -z "$ruta" || "$ruta" == \#* ]] && continue
  [[ "$ruta" == /* && -e "$ruta" ]] || { log "ERROR: ruta ausente o invalida: $ruta"; exit 1; }
done < "$INVENTARIO"

# Recuperar primero cualquier envio incompleto.
if [[ -f "$STATE_DIR/transferencia-pendiente" ]]; then
  pendiente="$(cat "$STATE_DIR/transferencia-pendiente")"
  [[ "$pendiente" =~ ^dhcp01-sjo-[0-9]{8}-[0-9a-f]{16}\.tar\.gz$ ]] || { log 'ERROR: estado pendiente invalido'; exit 1; }
  [[ -f "$BACKUP_DIR/$pendiente" ]] || { log "ERROR: falta respaldo pendiente $pendiente"; exit 1; }
  log "Reintentando transferencia pendiente: $pendiente"
  transferir "$pendiente"
  hash_pendiente="$(sha256sum "$BACKUP_DIR/$pendiente" | awk '{print $1}')"
  guardar_estado "$pendiente" "$hash_pendiente"
  log 'Transferencia pendiente recuperada'
fi

# Este servidor no requiere rndc sync; no se alteran sus servicios.

# Archivo temporal: se verifica antes de publicar y transferir.
TEMPORAL="$(mktemp "$BACKUP_DIR/.dhcp01-sjo-XXXXXXXX.tar.gz")"
log 'Creando archivo comprimido'
tar -czf "$TEMPORAL" -C / -T "$INVENTARIO"
tar -tzf "$TEMPORAL" >/dev/null
hash="$(sha256sum "$TEMPORAL" | awk '{print $1}')"
fecha="$(TZ=America/Costa_Rica date +%Y%m%d)"
nombre="dhcp01-sjo-${fecha}-${hash:0:16}.tar.gz"
if [[ -f "$BACKUP_DIR/$nombre" ]]; then
  hash_existente="$(sha256sum "$BACKUP_DIR/$nombre" | awk '{print $1}')"
  [[ "$hash_existente" == "$hash" ]] || { log 'ERROR: colision o archivo existente alterado'; exit 1; }
  log "SIN CAMBIOS: reutilizando $nombre"
else
  mv -- "$TEMPORAL" "$BACKUP_DIR/$nombre"
  TEMPORAL=""
  chmod 600 "$BACKUP_DIR/$nombre"
  log "Respaldo local: $nombre"
fi
printf '%s\n' "$nombre" > "$STATE_DIR/transferencia-pendiente"
transferir "$nombre"
guardar_estado "$nombre" "$hash"
# 14 dias de retencion local; no borrar el archivo vigente.
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'dhcp01-sjo-*.tar.gz' \
  -mtime +13 ! -name "$nombre" -delete
log "EXITO: $nombre"
