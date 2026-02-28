# it-stack-ansible

> Ansible automation for deploying and managing all 20 IT-Stack services across an 8-server Ubuntu 24.04 infrastructure.

Part of the [IT-Stack](https://github.com/it-stack-dev) open-source enterprise IT platform.

---

## Overview

This repository contains Ansible roles, playbooks, and inventory for all four implementation phases of IT-Stack:

| Phase | Services | Target Servers |
|-------|----------|----------------|
| 1 | FreeIPA, Keycloak, PostgreSQL, Redis, Traefik | lab-id1, lab-db1, lab-proxy1 |
| 2 | Nextcloud, Mattermost, Jitsi, iRedMail, Zammad | lab-app1, lab-comm1 |
| 3 | FreePBX, SuiteCRM, Odoo, OpenKM | lab-pbx1, lab-biz1 |
| 4 | Taiga, Snipe-IT, GLPI, Elasticsearch, Zabbix, Graylog | lab-mgmt1 |

## Directory Structure

```
it-stack-ansible/
├── ansible.cfg                     # Ansible configuration
├── requirements.yml                # Galaxy collections + roles
├── Makefile                        # Convenience targets
├── inventory/
│   ├── hosts.ini                   # All 8 servers
│   ├── group_vars/
│   │   ├── all.yml                 # Global variables
│   │   ├── identity.yml            # FreeIPA + Keycloak vars
│   │   ├── database.yml            # PostgreSQL + Redis vars
│   │   └── infrastructure.yml      # Traefik vars
│   └── host_vars/
│       ├── lab-id1.yml
│       ├── lab-db1.yml
│       └── lab-proxy1.yml
├── playbooks/
│   ├── site.yml                    # Full Phase 1 deployment
│   ├── deploy-freeipa.yml
│   ├── deploy-postgresql.yml
│   ├── deploy-redis.yml
│   ├── deploy-keycloak.yml
│   └── deploy-traefik.yml
├── roles/
│   ├── common/                     # Base OS hardening (all nodes)
│   ├── freeipa/                    # FreeIPA LDAP/DNS/Kerberos
│   ├── postgresql/                 # PostgreSQL 16 + 11 service DBs
│   ├── redis/                      # Redis 7 cache
│   ├── keycloak/                   # Keycloak 24 SSO
│   └── traefik/                    # Traefik 3 reverse proxy
└── vault/
    └── secrets.yml.example         # Vault variable template
```

## Prerequisites

- Ansible 2.15+ on your control machine
- SSH access to all target servers as `ansible` user with key-based auth
- Python 3.10+ on target servers
- Ubuntu 24.04 Server on all nodes

## Quick Start

### 1. Install dependencies

```bash
make deps
# or: ansible-galaxy install -r requirements.yml
```

### 2. Configure vault secrets

```bash
cp vault/secrets.yml.example vault/secrets.yml
# Edit vault/secrets.yml — fill in all CHANGE_ME values
ansible-vault encrypt vault/secrets.yml
echo 'your-vault-password' > .vault_pass
chmod 600 .vault_pass
```

### 3. Test connectivity

```bash
make ping
```

### 4. Deploy Phase 1 (full stack)

```bash
make site
# or: ansible-playbook playbooks/site.yml
```

### 5. Deploy individual services

```bash
make deploy-freeipa
make deploy-postgresql
make deploy-redis
make deploy-keycloak
make deploy-traefik
```

## Server Layout

| Hostname | IP | Phase | Services |
|----------|----|-------|---------|
| lab-id1 | 10.0.50.11 | 1 | FreeIPA, Keycloak |
| lab-db1 | 10.0.50.12 | 1 | PostgreSQL, Redis |
| lab-app1 | 10.0.50.13 | 2 | Nextcloud, Mattermost, Jitsi |
| lab-comm1 | 10.0.50.14 | 2 | iRedMail, Zammad, Zabbix |
| lab-proxy1 | 10.0.50.15 | 1 | Traefik, Graylog |
| lab-pbx1 | 10.0.50.16 | 3 | FreePBX |
| lab-biz1 | 10.0.50.17 | 3 | SuiteCRM, Odoo, OpenKM |
| lab-mgmt1 | 10.0.50.18 | 4 | Taiga, Snipe-IT, GLPI |

## Roles

### `common`
Applied to every node. Handles:
- Package installation and OS updates
- NTP (chrony)
- SSH hardening
- UFW firewall baseline
- fail2ban
- Ansible service account

### `freeipa`
Deploys FreeIPA with integrated DNS and Kerberos. Creates:
- Service groups (it-admins, it-users, service-accounts, voip-users)
- Service accounts (keycloak-svc, nextcloud-svc, mattermost-svc, zabbix-svc)
- HBAC rules

### `postgresql`
Deploys PostgreSQL 16 and creates all 11 service databases:

| Database | User | Service |
|----------|------|---------|
| keycloak | keycloak | Keycloak SSO |
| nextcloud | nextcloud | Nextcloud |
| mattermost | mattermost | Mattermost |
| zammad | zammad | Zammad Help Desk |
| suitecrm | suitecrm | SuiteCRM |
| odoo | odoo | Odoo ERP |
| openkm | openkm | OpenKM DMS |
| taiga | taiga | Taiga PM |
| snipeit | snipeit | Snipe-IT |
| glpi | glpi | GLPI ITSM |
| zabbix | zabbix | Zabbix Monitoring |

### `redis`
Deploys Redis 7 with:
- Password authentication
- Memory limits (configurable per host)
- Disabled dangerous commands (FLUSHALL, FLUSHDB, DEBUG)
- Append-only persistence

### `keycloak`
Deploys Keycloak 24.0.5 with:
- PostgreSQL backend
- FreeIPA LDAP federation
- `it-stack` realm
- OIDC clients for Nextcloud, Mattermost, Jitsi, Odoo, Zammad, Taiga

### `traefik`
Deploys Traefik 3 reverse proxy with:
- Automatic HTTP → HTTPS redirect
- TLS via FreeIPA ACME (internal) or Let's Encrypt
- Dynamic routing for all 14 service subdomains
- Hardened TLS ciphers (TLS 1.2+)
- Security headers middleware
- Dashboard with BasicAuth

## Vault Variables

All secrets use the `vault_` prefix. See `vault/secrets.yml.example` for the full list.

```yaml
vault_ipa_admin_password: "..."
vault_keycloak_admin_password: "..."
vault_pg_nextcloud_pass: "..."
vault_redis_password: "..."
vault_traefik_dashboard_pass: "..."
# ... etc
```

## Make Targets

```
make help              Show all targets
make deps              Install Galaxy collections and roles
make lint              Run ansible-lint
make check             Dry-run (--check) site.yml
make site              Deploy full Phase 1 stack
make deploy-freeipa    Deploy FreeIPA only
make deploy-keycloak   Deploy Keycloak only
make deploy-postgresql Deploy PostgreSQL only
make deploy-redis      Deploy Redis only
make deploy-traefik    Deploy Traefik only
make ping              Test connectivity to all hosts
make facts             Gather facts from all hosts
make vault-edit        Edit vault/secrets.yml
make vault-view        View vault/secrets.yml
```

## Security

- All passwords stored in Ansible Vault (`vault/secrets.yml`)
- `.vault_pass` and `vault/secrets.yml` are excluded by `.gitignore`
- SSH root login disabled on all nodes
- Password authentication disabled (key-based only)
- fail2ban protects SSH with 24h bans after 3 failures
- UFW default-deny with allowlist per service

## License

Apache 2.0 — see [LICENSE](../../../LICENSE)
