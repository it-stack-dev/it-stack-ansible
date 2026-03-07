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
        deploy-1node deploy-2node deploy-3node deploy-4node deploy-5node \
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

# ── Lab Tiers (limited hardware) ──────────────────────────────────────────────
## deploy-1node  Deploy full stack on a single machine (64 GB RAM min)
deploy-1node:
	$(ANSIBLE) -i inventory/hosts-1node.ini $(VAULT_ARGS) playbooks/site-1node.yml

## deploy-2node  Deploy stack across 2 nodes (32 GB each)
deploy-2node:
	$(ANSIBLE) -i inventory/hosts-2node.ini $(VAULT_ARGS) playbooks/site-2node.yml

## deploy-3node  Deploy stack across 3 nodes (32+24+24 GB)
deploy-3node:
	$(ANSIBLE) -i inventory/hosts-3node.ini $(VAULT_ARGS) playbooks/site-3node.yml

## deploy-4node  Deploy stack across 4 nodes (16+32+24+24 GB)
deploy-4node:
	$(ANSIBLE) -i inventory/hosts-4node.ini $(VAULT_ARGS) playbooks/site-4node.yml

## deploy-5node  Deploy stack across 5 nodes — near-production (recommended lab min)
deploy-5node:
	$(ANSIBLE) -i inventory/hosts-5node.ini $(VAULT_ARGS) playbooks/site-5node.yml

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

## vault-init   Create vault/secrets.yml from example template (first-time setup)
vault-init:
	@if [ -f vault/secrets.yml ]; then \
		echo "ERROR: vault/secrets.yml already exists. Use 'make vault-edit'."; exit 1; \
	fi
	cp vault/secrets.yml.example vault/secrets.yml
	@echo "Edit vault/secrets.yml with real passwords, then run:"
	@echo "  ansible-vault encrypt vault/secrets.yml --vault-password-file .vault_pass"

# ── Production Readiness ──────────────────────────────────────────────────────

## harden       Security hardening — SSH, fail2ban, UFW firewall, sysctl, auditd (all hosts)
harden:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/harden.yml

## harden-check Dry-run security hardening (--check --diff, no changes)
harden-check:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --check --diff playbooks/harden.yml

## tls          Create internal CA and deploy TLS certs to all hosts + Traefik
tls:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/tls-setup.yml

## tls-ca       Set up internal CA on lab-proxy1 only
tls-ca:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --tags ca playbooks/tls-setup.yml

## tls-certs    Generate and distribute host certificates (CA must exist first)
tls-certs:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --tags certs,distribute,traefik playbooks/tls-setup.yml

## backup       Run immediate full backup (PostgreSQL + Nextcloud + configs)
backup:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) playbooks/backup.yml

## backup-setup Install nightly backup cron jobs on all servers
backup-setup:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --tags setup playbooks/backup.yml

## backup-pg    PostgreSQL dump only
backup-pg:
	$(ANSIBLE) -i inventory/hosts.ini $(VAULT_ARGS) --limit database --tags postgres playbooks/backup.yml

## backup-verify Verify backup archive integrity
backup-verify:
	$(ANSIBLE) $(INVENTORY) $(VAULT_ARGS) --tags verify playbooks/backup.yml
