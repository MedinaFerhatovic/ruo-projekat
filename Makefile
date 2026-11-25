.DEFAULT_GOAL := all
.RECIPEPREFIX := >
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.NOTPARALLEL:
.PHONY: all check infra config dns deploy test destroy

all:
>$(MAKE) check
>$(MAKE) infra
>$(MAKE) config
>$(MAKE) dns
>$(MAKE) deploy
>$(MAKE) test

check:
>@for tool in terraform ansible ansible-playbook ansible-galaxy python3 virsh ssh; do command -v "$$tool" >/dev/null || { echo "Nedostaje alat: $$tool"; exit 1; }; done
>virsh -c qemu:///system pool-info default
>virsh -c qemu:///system net-info default

infra:
>terraform -chdir=terraform/vm init -input=false
>terraform -chdir=terraform/vm apply -auto-approve -input=false
>bash scripts/prepare-access.sh

config:
>ansible-galaxy collection install -r ansible/requirements.yml
>ansible-playbook -i ansible/inventory.ini ansible/site.yml --skip-tags app

dns:
>terraform -chdir=terraform/dns init -input=false
>terraform -chdir=terraform/dns apply -auto-approve -input=false

deploy:
>ansible-playbook -i ansible/inventory.ini ansible/site.yml --tags app

test:
>mkdir -p tests/results
>bash tests/isolation.sh "$$(cat .runtime/vm-ip)" | tee tests/results/isolation.txt
>bash tests/services.sh "$$(cat .runtime/vm-ip)" | tee tests/results/services.txt

destroy:
>terraform -chdir=terraform/dns destroy -auto-approve -input=false
>terraform -chdir=terraform/vm destroy -auto-approve -input=false
>if [ -f .runtime/vm-ip ]; then ssh-keygen -R "$$(cat .runtime/vm-ip)" || true; fi
>rm -f ansible/inventory.ini terraform/dns/runtime.auto.tfvars.json .runtime/vm-ip