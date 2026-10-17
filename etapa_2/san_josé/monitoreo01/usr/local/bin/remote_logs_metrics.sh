#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/remote"
METRIC_DIR="/var/lib/node_exporter/textfile_collector"
LIMIT_BYTES=1073741824

USED_BYTES=$(du -sb "$LOG_DIR" | awk '{print $1}')

TMP_FILE=$(mktemp "$METRIC_DIR/remote_logs.XXXXXX")

cat > "$TMP_FILE" <<EOF
# HELP remote_logs_used_bytes Espacio utilizado por los logs centralizados en bytes.
# TYPE remote_logs_used_bytes gauge
remote_logs_used_bytes $USED_BYTES

# HELP remote_logs_limit_bytes Limite operativo de almacenamiento en bytes.
# TYPE remote_logs_limit_bytes gauge
remote_logs_limit_bytes $LIMIT_BYTES
EOF

chmod 644 "$TMP_FILE"
mv -f "$TMP_FILE" "$METRIC_DIR/remote_logs.prom"
