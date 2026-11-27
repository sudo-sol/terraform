#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
# initdb, pg_ctl and postgres must come from the same PostgreSQL installation.
pg_bin=${PG_BINDIR:-$(pg_config --bindir)}
export PGHOST="$scratch" PGPORT=55432 PGDATABASE=postgres PGUSER=orders_test_admin
unset PGPASSWORD PGSSLMODE PGSSLROOTCERT DB_IAM
"$pg_bin/initdb" -D "$scratch/data" -U "$PGUSER" -A trust --encoding=UTF8 --no-locale > "$scratch/init.log"
cleanup() {
  "$pg_bin/pg_ctl" -D "$scratch/data" -m fast -w stop >/dev/null 2>&1 || true
  rm -rf -- "$scratch"
}
trap cleanup EXIT
"$pg_bin/pg_ctl" -D "$scratch/data" -l "$scratch/postgres.log" \
  -o "-c listen_addresses='' -k '$scratch' -p $PGPORT" -w start
PYTHONPATH="$project/app${PYTHONPATH:+:$PYTHONPATH}" python3 "$project/tests/test_orders.py" -v
