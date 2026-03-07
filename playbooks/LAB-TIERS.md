# IT-Stack Lab Deployment Tiers

> **Do I need 8 servers to use IT-Stack?**
> No. Use the tier that matches what you have.
> The Ansible playbooks in this directory cover 1–8 nodes.

---

## Summary Table

| Tier | Nodes | Total RAM | Use Case | Playbook |
|------|-------|-----------|----------|----------|
| **1-Node** | 1 | 64 GB | Home lab, demos, learning | `site-1node.yml` |
| **2-Node** | 2 | 64 GB | School / small team | `site-2node.yml` |
| **3-Node** | 3 | 80 GB | Small office | `site-3node.yml` |
| **4-Node** | 4 | 96 GB | Department | `site-4node.yml` |
| **5-Node** | 5 | 104 GB | Near-production lab | `site-5node.yml` |
| **8-Node** | 8 | 144 GB | Production | `site.yml` |

---

## Node Layouts

### 1-Node — Everything on one machine

```
lab-solo1 (192.168.1.10, 64 GB RAM):
  FreeIPA · Keycloak · Traefik
  PostgreSQL · Redis · Elasticsearch
  Nextcloud · Mattermost · Jitsi
  iRedMail · FreePBX · Zammad
  SuiteCRM · Odoo · OpenKM
  Taiga · Snipe-IT · GLPI
  Zabbix · Graylog
```

**Trade-offs:** Works but slow. All Java services (Keycloak, Elasticsearch, Graylog)
compete for RAM. Reduce heap sizes using the `elasticsearch_heap_size=1g` inventory vars.
FreeIPA DNS doesn't delegate — `/etc/hosts` used for internal resolution.

**Minimum hardware:** 64 GB RAM, 16 vCPU, 500 GB SSD
**Practical minimum (skip Jitsi+FreePBX+Graylog):** 32 GB RAM, 8 vCPU, 300 GB SSD

---

### 2-Node — Foundation vs. Applications

```
lab-node1 (192.168.1.10, 32 GB RAM):  ← Foundation
  FreeIPA · Keycloak · Traefik
  PostgreSQL · Redis · Elasticsearch

lab-node2 (192.168.1.11, 32 GB RAM):  ← All 14 application services
  Nextcloud · Mattermost · Jitsi
  iRedMail · FreePBX · Zammad
  SuiteCRM · Odoo · OpenKM
  Taiga · Snipe-IT · GLPI
  Zabbix · Graylog
```

**Best for:** Learning the dependency chain. Node1 must come up first.
**Trade-offs:** Node2 is still overloaded. Good for understanding architecture, not for load testing.

---

### 3-Node — Foundation / Comms / Business

```
lab-node1 (192.168.1.10, 32 GB RAM):  ← Foundation
  FreeIPA · Keycloak · PostgreSQL · Redis · Elasticsearch · Traefik

lab-node2 (192.168.1.11, 24 GB RAM):  ← Collaboration + Communications
  Nextcloud · Mattermost · Jitsi
  iRedMail · FreePBX · Zammad

lab-node3 (192.168.1.12, 24 GB RAM):  ← Business + IT Management + Monitoring
  SuiteCRM · Odoo · OpenKM
  Taiga · Snipe-IT · GLPI
  Zabbix · Graylog
```

**Best for:** Testing real service-to-service integrations (SuiteCRM↔FreePBX CTI, Zabbix→Mattermost alerts).
**Trade-offs:** PostgreSQL on node1 serves all databases — adequate for lab load.

---

### 4-Node — Dedicated Database Tier

```
lab-node1 (192.168.1.10, 16 GB RAM):  ← Identity + Proxy
  FreeIPA · Keycloak · Traefik

lab-node2 (192.168.1.11, 32 GB RAM):  ← Database (dedicated)
  PostgreSQL · Redis · Elasticsearch

lab-node3 (192.168.1.12, 24 GB RAM):  ← Collaboration + Communications
  Nextcloud · Mattermost · Jitsi
  iRedMail · FreePBX · Zammad

lab-node4 (192.168.1.13, 24 GB RAM):  ← Business + IT Mgmt + Monitoring
  SuiteCRM · Odoo · OpenKM
  Taiga · Snipe-IT · GLPI
  Zabbix · Graylog
```

**Best for:** Load testing the database tier independently.
Elasticsearch on its own host means Graylog/Zammad log indexing doesn't compete with PostgreSQL.

---

### 5-Node — Near-Production (Recommended Minimum)

```
lab-node1 (192.168.1.10, 16 GB RAM):  ← Identity + Proxy
  FreeIPA · Keycloak · Traefik

lab-node2 (192.168.1.11, 32 GB RAM):  ← Database
  PostgreSQL · Redis · Elasticsearch

lab-node3 (192.168.1.12, 24 GB RAM):  ← Collaboration + Comms apps
  Nextcloud · Mattermost · Jitsi · iRedMail · Zammad

lab-node4 (192.168.1.13, 16 GB RAM):  ← VoIP + Business
  FreePBX · SuiteCRM · Odoo · OpenKM

lab-node5 (192.168.1.14, 16 GB RAM):  ← IT Management + Monitoring
  Taiga · Snipe-IT · GLPI · Zabbix · Graylog
```

**Best for:** This is where integrations become realistic. Monitoring (Zabbix/Graylog) on
its own node means it actually observes the other 4 nodes. FreePBX on its own IP means SIP
routing is cleanly separated from web apps.

**This is the recommended minimum for running all 23 cross-service integrations.**

---

### 8-Node — Production

See the full `inventory/hosts.ini` and `playbooks/site.yml`.

```
lab-id1    (10.0.50.11): FreeIPA · Keycloak
lab-db1    (10.0.50.12): PostgreSQL · Redis · Elasticsearch
lab-app1   (10.0.50.13): Nextcloud · Mattermost · Jitsi
lab-comm1  (10.0.50.14): iRedMail · Zammad · Zabbix
lab-proxy1 (10.0.50.15): Traefik · Graylog
lab-pbx1   (10.0.50.16): FreePBX
lab-biz1   (10.0.50.17): SuiteCRM · Odoo · OpenKM
lab-mgmt1  (10.0.50.18): Taiga · Snipe-IT · GLPI
```

---

## Getting Started with Any Tier

### 1. Update IP addresses in the inventory file

Edit `inventory/hosts-Xnode.ini` and replace `192.168.1.1X` with your actual server IPs.

### 2. Set up SSH access

```bash
# On your control machine (where you run Ansible)
ssh-copy-id ubuntu@192.168.1.10
ssh-copy-id ubuntu@192.168.1.11
# etc.
```

### 3. Create the vault password file

```bash
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass
```

### 4. Install Ansible and dependencies

```bash
pip install ansible
ansible-galaxy install -r requirements.yml
```

### 5. Ping all nodes

```bash
ansible -i inventory/hosts-Xnode.ini all_servers -m ping
```

### 6. Run the playbook

```bash
# Full deployment
ansible-playbook -i inventory/hosts-3node.ini playbooks/site-3node.yml \
  --vault-password-file .vault_pass -e "ansible_user=ubuntu"

# Foundation only
ansible-playbook ... --tags foundation

# One node at a time
ansible-playbook ... --limit lab-node1
ansible-playbook ... --limit lab-node2
```

---

## Required File → Inventory Mapping

| Inventory | Playbook | Makefile target |
|-----------|----------|-----------------|
| `hosts-1node.ini` | `site-1node.yml` | `make deploy-1node` |
| `hosts-2node.ini` | `site-2node.yml` | `make deploy-2node` |
| `hosts-3node.ini` | `site-3node.yml` | `make deploy-3node` |
| `hosts-4node.ini` | `site-4node.yml` | `make deploy-4node` |
| `hosts-5node.ini` | `site-5node.yml` | `make deploy-5node` |
| `hosts.ini`       | `site.yml`       | `make site`         |

---

## Do You Need VMs to Work on Integrations?

**No.** The 10 remaining cross-service integrations are Ansible YAML files.
You write them on your Windows dev machine and test with Docker Compose + WireMock.

Only Labs 04–06 (SSO integration, advanced multi-service, production deployment) require
actual VMs. Labs 01–03 and the integration Ansible tasks run on Docker locally.

**Recommended workflow:**
1. Write the Ansible tasks locally (Windows/VS Code)
2. Test with `docker compose -f docker/docker-compose.integration.yml up -d` (Lab 05 stack)
3. Validate against WireMock stubs in the integration test script
4. When VMs are available, run the corresponding `site-Xnode.yml` playbook for real
