#!/usr/bin/env bash
# Back up the Tunduk security server: database + persistent volumes.
#
# 3-year message-log retention is a legal requirement (Tunduk regulation).
# Run from cron, e.g. daily:
#   0 2 * * * /opt/tunduk-security-server/backup/backup.sh >> /var/log/xroad-backup.log 2>&1
#
# Restore: see SETUP.md ("Backup & restore").
set -euo pipefail

# Resolve paths regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
# The compose file and its .env live in docker-compose/. Run docker compose there.
COMPOSE_DIR="$REPO_DIR/docker-compose"
cd "$COMPOSE_DIR"

# Load DB password from .env (XROAD_DB_PWD).
[ -f .env ] && set -a && . ./.env && set +a

DEST="${BACKUP_DIR:-$SCRIPT_DIR/out}"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"

DB_SVC="db"
SS_SVC="security-server"

echo "[$(date -Is)] backup start -> $DEST"

# 1) Database: pg_dumpall via the db container (captures all xroad databases+roles).
echo "  - dumping postgres"
docker compose exec -T -e PGPASSWORD="${XROAD_DB_PWD}" "$DB_SVC" \
  pg_dumpall -U postgres | gzip > "$DEST/db-$STAMP.sql.gz"

# 2) Config volume (/etc/xroad): keys, certs, anchor, db.properties.
echo "  - archiving /etc/xroad"
docker compose exec -T "$SS_SVC" tar -C / -czf - etc/xroad > "$DEST/etc-xroad-$STAMP.tar.gz"

# 3) Message-log archive volume (/var/lib/xroad): legal retention.
echo "  - archiving /var/lib/xroad"
docker compose exec -T "$SS_SVC" tar -C / -czf - var/lib/xroad > "$DEST/var-lib-xroad-$STAMP.tar.gz"

# Retention: keep last N days of local copies (archives also belong off-box).
RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-30}"
find "$DEST" -name '*.gz' -mtime "+$RETAIN_DAYS" -delete 2>/dev/null || true

echo "[$(date -Is)] backup done"
echo "  IMPORTANT: copy $DEST off-box to satisfy 3-year retention."
ls -lh "$DEST"/*"$STAMP"* 2>/dev/null || true
