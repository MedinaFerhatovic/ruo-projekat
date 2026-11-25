#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VM_IP=""

# Sacekaj da Terraform prepozna IPv4 adresu masine.
for attempt in {1..60}; do
  terraform -chdir=terraform/vm apply \
    -refresh-only -auto-approve -no-color >/dev/null

  VM_IP="$(
    terraform -chdir=terraform/vm output -json vm_addresses |
      python3 -c '
import ipaddress
import json
import sys

addresses = json.load(sys.stdin)
print(next(
    (a for a in addresses if ipaddress.ip_address(a).version == 4),
    ""
))
'
  )"

  if [ -n "$VM_IP" ]; then
    break
  fi

  sleep 5
done

if [ -z "$VM_IP" ]; then
  echo "GRESKA: virtuelna masina jos nema IPv4 adresu"
  exit 1
fi

cat > ansible/inventory.ini <<EOF
[servers]
ruo-vm ansible_host=$VM_IP ansible_user=medina ansible_ssh_private_key_file=$HOME/.ssh/ruo_projekat ansible_python_interpreter=/usr/bin/python3 ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

printf '{"dns_server":"%s"}\n' "$VM_IP" \
  > terraform/dns/runtime.auto.tfvars.json

mkdir -p .runtime
printf '%s\n' "$VM_IP" > .runtime/vm-ip

echo "Adresa masine: $VM_IP"
echo "Ansible inventory i DNS adresa su azurirani"

ansible -i ansible/inventory.ini servers \
  -m wait_for_connection -a "timeout=300"