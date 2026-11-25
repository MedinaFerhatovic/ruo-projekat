#!/usr/bin/env bash
set -euo pipefail

VM_IP="${1:-192.168.122.158}"

ssh -i "$HOME/.ssh/ruo_projekat" \
  -o BatchMode=yes \
  "medina@$VM_IP" bash -s <<'REMOTE'
set -euo pipefail

echo "Provjera: backend -> baza"

sudo docker compose \
  --project-directory /opt/ruo \
  -f /opt/ruo/compose.yaml \
  exec -T --interactive=false backend python -c '
import socket

with socket.create_connection(("db.ruo.test", 3306), timeout=5):
    print("USPJEH: backend pristupa bazi")
'

echo "Provjera: frontend -> baza"

sudo docker run --rm \
  --network container:ruo-frontend-1 \
  --entrypoint python ruo-backend -c '
import socket

address = socket.gethostbyname("db.ruo.test")
print("DNS adresa baze:", address)

try:
    connection = socket.create_connection((address, 3306), timeout=5)
except OSError:
    print("USPJEH: frontend nema pristup bazi")
else:
    connection.close()
    raise SystemExit("GRESKA: frontend moze pristupiti bazi")
'

echo "Provjera: backend i baza nemaju objavljene portove"

for container in ruo-backend-1 ruo-mysql-1; do
  ports="$(sudo docker port "$container")"
  if [ -n "$ports" ]; then
    echo "GRESKA: $container ima objavljene portove"
    exit 1
  fi
done

echo "USPJEH: svi testovi izolacije su prosli"
REMOTE