.DEFAULT_GOAL := help
ANSIBLE       := ansible-playbook
INVENTORY     := -i inventory/hosts.ini
VAULT_ARGS    := --vault-password-file .vault_pass

.PHONY: help deps lint check site \
        deploy-freeipa deploy-keycloak deploy-postgresql deploy-redis deploy-traefik \
        deploy-nextcloud deploy-mattermost deploy-jitsi deploy-iredmail deploy-zammad \
        deploy-elasticsearch deploy-freepbx deploy-suitecrm deploy-odoo deploy-openkm \
        deploy-taiga deploy-snipeit deploy-glpi deploy-zabbix deploy-graylog \
        deploy-phase2 deploy-phase3 deploy-phase4 \
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

# ── Phase 2: Collaboration ────────────────────────────────────────────────────
## deploy-nextcloud      Deploy Nextcloud on lab-app1
deploy-nextcloud:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-nextcloud.yml

## deploy-mattermost     Deploy Mattermost on lab-app1
deploy-mattermost:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-mattermost.yml

## deploy-jitsi          Deploy Jitsi Meet on lab-app1
deploy-jitsi:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-jitsi.yml

## deploy-iredmail       Deploy iRedMail on lab-comm1
deploy-iredmail:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-iredmail.yml

## deploy-zammad         Deploy Zammad help desk on lab-comm1
deploy-zammad:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-zammad.yml

## deploy-elasticsearch  Deploy Elasticsearch on lab-db1
deploy-elasticsearch:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-elasticsearch.yml

## deploy-phase2         Deploy all Phase 2 collaboration services
deploy-phase2: deploy-elasticsearch deploy-nextcloud deploy-mattermost deploy-jitsi deploy-iredmail deploy-zammad

# ── Phase 3: Back Office ──────────────────────────────────────────────────────
## deploy-freepbx        Deploy FreePBX on lab-pbx1
deploy-freepbx:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-freepbx.yml

## deploy-suitecrm       Deploy SuiteCRM on lab-biz1
deploy-suitecrm:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-suitecrm.yml

## deploy-odoo           Deploy Odoo ERP on lab-biz1
deploy-odoo:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-odoo.yml

## deploy-openkm         Deploy OpenKM DMS on lab-biz1
deploy-openkm:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-openkm.yml

## deploy-phase3         Deploy all Phase 3 back-office services
deploy-phase3: deploy-freepbx deploy-suitecrm deploy-odoo deploy-openkm

# ── Phase 4: IT Management ────────────────────────────────────────────────────
## deploy-taiga          Deploy Taiga project management on lab-mgmt1
deploy-taiga:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-taiga.yml

## deploy-snipeit        Deploy Snipe-IT asset management on lab-mgmt1
deploy-snipeit:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-snipeit.yml

## deploy-glpi           Deploy GLPI ITSM on lab-mgmt1
deploy-glpi:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-glpi.yml

## deploy-zabbix         Deploy Zabbix monitoring on lab-comm1
deploy-zabbix:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-zabbix.yml

## deploy-graylog        Deploy Graylog log management on lab-proxy1
deploy-graylog:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/deploy-graylog.yml

## deploy-phase4         Deploy all Phase 4 IT management services
deploy-phase4: deploy-taiga deploy-snipeit deploy-glpi deploy-zabbix deploy-graylog

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
