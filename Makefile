.DEFAULT_GOAL := help
ANSIBLE       := ansible-playbook
INVENTORY     := -i inventory/hosts.ini
VAULT_ARGS    := --vault-password-file .vault_pass

.PHONY: help deps lint check site \
        deploy-freeipa deploy-keycloak deploy-postgresql deploy-redis deploy-traefik \
        ping facts vault-edit vault-view

## help         Show this help
help:
	@grep -E '^## ' Makefile | sed 's/## /  /'

## deps         Install Ansible Galaxy requirements
deps:
	ansible-galaxy install -r requirements.yml --force

## lint         Lint all playbooks with ansible-lint
lint:
	ansible-lint playbooks/

## check        Dry-run the full site playbook (--check --diff)
check:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --check --diff playbooks/site.yml

## site         Deploy the complete Phase 1 stack
site:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/site.yml

## deploy-freeipa    Deploy and configure FreeIPA on lab-id1
deploy-freeipa:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-freeipa.yml

## deploy-keycloak   Deploy and configure Keycloak on lab-id1
deploy-keycloak:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-keycloak.yml

## deploy-postgresql Deploy and configure PostgreSQL on lab-db1
deploy-postgresql:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-postgresql.yml

## deploy-redis      Deploy and configure Redis on lab-db1
deploy-redis:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-redis.yml

## deploy-traefik    Deploy and configure Traefik on lab-proxy1
deploy-traefik:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-traefik.yml

## ping         Test connectivity to all hosts
ping:
	ansible all $(INVENTORY) -m ping

## facts        Gather and display facts for all hosts
facts:
	ansible all $(INVENTORY) $(VAULT_ARGS) -m setup

## vault-edit   Edit vault secrets file
vault-edit:
	ansible-vault edit --vault-password-file .vault_pass vault/secrets.yml

## vault-view   View vault secrets file (read-only)
vault-view:
	ansible-vault view --vault-password-file .vault_pass vault/secrets.yml
