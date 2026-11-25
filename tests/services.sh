#!/usr/bin/env bash
set -euo pipefail

VM_IP="${1:-192.168.122.158}"

ssh -i "$HOME/.ssh/ruo_projekat" \
  -o BatchMode=yes \
  "medina@$VM_IP" bash -s -- "$VM_IP" <<'REMOTE'
set -euo pipefail

VM_IP="$1"

check_dns() {
  name="$1"
  expected="$2"
  actual="$(dig @127.0.0.1 "$name" A +short)"

  if [ "$actual" != "$expected" ]; then
    echo "GRESKA: $name: ocekivano $expected, dobijeno $actual"
    exit 1
  fi

  echo "USPJEH: $name -> $actual"
}

check_dns api.ruo.test 172.28.20.20
check_dns db.ruo.test 172.28.30.20
check_dns web.ruo.test "$VM_IP"

curl --fail --silent --show-error --max-time 15 \
  -o /dev/null http://127.0.0.1:8080/
echo "USPJEH: frontend odgovara"

curl --fail --silent --show-error --max-time 15 \
  http://127.0.0.1:8080/api/users |
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
if not isinstance(data, list):
    raise SystemExit("GRESKA: API nije vratio listu")
print("USPJEH: API vraca JSON listu korisnika")
'

echo "USPJEH: svi testovi servisa su prosli"
REMOTE