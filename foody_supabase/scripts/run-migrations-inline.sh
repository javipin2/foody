#!/bin/bash
set -e
cd "/mnt/c/Users/javier/Videos/usb/FOODY APP/foody_supabase/migrations"
for f in $(ls *.sql | sort); do
  echo ">> $f"
  docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done
echo "DONE"
docker exec -i supabase-db psql -U postgres -d postgres -t -c "SELECT count(*) FROM ciudades"
