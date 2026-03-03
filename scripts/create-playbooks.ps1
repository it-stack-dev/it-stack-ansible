#!/usr/bin/env pwsh
# scripts/create-playbooks.ps1
# Creates all 15 deploy playbooks for Phase 2-4 services

$base = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-ansible"
$pb   = "$base\playbooks"

function Write-Playbook { param($path, $content)
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ── deploy-nextcloud.yml ──────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-nextcloud.yml" @'
---
# playbooks/deploy-nextcloud.yml
# Deploy and configure Nextcloud 28 on lab-app1.
# Run with: make deploy-nextcloud
#
# Prerequisites:
#   - Phase 1 complete (FreeIPA, PostgreSQL, Redis, Keycloak, Traefik)
#   - vault/secrets.yml contains: vault_pg_nextcloud_pass, vault_nextcloud_admin_pass
#   - DNS record: cloud.<domain> → lab-proxy1 (10.0.50.15)

- name: "Deploy Nextcloud Collaboration Platform"
  hosts: collaboration
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Nextcloud vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_nextcloud_pass is defined
          - vault_nextcloud_admin_pass is defined
        fail_msg: "Missing Nextcloud vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: nextcloud
      tags: [nextcloud, collaboration]

  post_tasks:
    - name: "Verify Nextcloud status endpoint"
      ansible.builtin.uri:
        url: "http://localhost/status.php"
        return_content: true
        status_code: 200
      register: nc_status
      ignore_errors: true
      tags: [verify]

    - name: "Display Nextcloud deployment summary"
      ansible.builtin.debug:
        msg:
          - "Nextcloud {{ nextcloud_version }} deployed on {{ inventory_hostname }}"
          - "URL: https://cloud.{{ it_stack_domain }}"
          - "Admin user: {{ nextcloud_admin_user }}"
          - "Data dir: {{ nextcloud_data_dir }}"
          - "DB host: {{ nextcloud_db_host }} / {{ nextcloud_db_name }}"
      tags: [verify]
'@

# ── deploy-mattermost.yml ─────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-mattermost.yml" @'
---
# playbooks/deploy-mattermost.yml
# Deploy and configure Mattermost Team Edition on lab-app1.
# Run with: make deploy-mattermost
#
# Prerequisites:
#   - Phase 1 complete; Nextcloud deployed (shares PHP/Nginx)
#   - vault/secrets.yml contains: vault_pg_mattermost_pass, vault_mattermost_admin_pass

- name: "Deploy Mattermost Team Messaging"
  hosts: collaboration
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Mattermost vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_mattermost_pass is defined
          - vault_mattermost_admin_pass is defined
        fail_msg: "Missing Mattermost vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: mattermost
      tags: [mattermost, collaboration]

  post_tasks:
    - name: "Verify Mattermost API health"
      ansible.builtin.uri:
        url: "http://localhost:{{ mattermost_port }}/api/v4/system/ping"
        return_content: true
        status_code: 200
      register: mm_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Mattermost deployment summary"
      ansible.builtin.debug:
        msg:
          - "Mattermost {{ mattermost_version }} deployed on {{ inventory_hostname }}"
          - "URL: {{ mattermost_site_url }}"
          - "Admin: {{ mattermost_system_admin }}"
          - "Port: {{ mattermost_port }}"
          - "DB: {{ mattermost_db_host }} / {{ mattermost_db_name }}"
      tags: [verify]
'@

# ── deploy-jitsi.yml ──────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-jitsi.yml" @'
---
# playbooks/deploy-jitsi.yml
# Deploy and configure Jitsi Meet on lab-app1.
# Run with: make deploy-jitsi
#
# Prerequisites:
#   - Phase 1 complete; Keycloak running for JWT auth
#   - vault/secrets.yml contains: vault_jitsi_jicofo_pass, vault_jitsi_jvb_pass, vault_jitsi_jwt_secret

- name: "Deploy Jitsi Meet Video Conferencing"
  hosts: collaboration
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Jitsi vault vars present"
      ansible.builtin.assert:
        that:
          - vault_jitsi_jicofo_pass is defined
          - vault_jitsi_jvb_pass is defined
          - vault_jitsi_jwt_secret is defined
        fail_msg: "Missing Jitsi vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: jitsi
      tags: [jitsi, collaboration]

  post_tasks:
    - name: "Verify Jitsi XMPP port reachable"
      ansible.builtin.wait_for:
        port: "{{ jitsi_prosody_port }}"
        host: localhost
        timeout: 30
      ignore_errors: true
      tags: [verify]

    - name: "Display Jitsi deployment summary"
      ansible.builtin.debug:
        msg:
          - "Jitsi Meet deployed on {{ inventory_hostname }}"
          - "URL: https://{{ jitsi_domain }}"
          - "Auth type: {{ jitsi_auth_type }}"
          - "STUN servers: {{ jitsi_stun_servers | join(', ') }}"
      tags: [verify]
'@

# ── deploy-iredmail.yml ───────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-iredmail.yml" @'
---
# playbooks/deploy-iredmail.yml
# Deploy and configure iRedMail on lab-comm1.
# Run with: make deploy-iredmail
#
# Prerequisites:
#   - Phase 1 complete; reverse DNS (PTR) configured for 10.0.50.14
#   - vault/secrets.yml contains: vault_iredmail_admin_pass, vault_pg_iredmail_pass
#   - IMPORTANT: iRedMail installer must be run once manually; this role configures it

- name: "Deploy iRedMail Email Server"
  hosts: communications
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert iRedMail vault vars present"
      ansible.builtin.assert:
        that:
          - vault_iredmail_admin_pass is defined
          - vault_pg_iredmail_pass is defined
        fail_msg: "Missing iRedMail vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: iredmail
      tags: [iredmail, communications, email]

  post_tasks:
    - name: "Verify Postfix SMTP port listening"
      ansible.builtin.wait_for:
        port: "{{ iredmail_smtp_port }}"
        host: localhost
        timeout: 30
      ignore_errors: true
      tags: [verify]

    - name: "Verify Dovecot IMAPS port listening"
      ansible.builtin.wait_for:
        port: "{{ iredmail_imap_port }}"
        host: localhost
        timeout: 30
      ignore_errors: true
      tags: [verify]

    - name: "Display iRedMail deployment summary"
      ansible.builtin.debug:
        msg:
          - "iRedMail deployed on {{ inventory_hostname }}"
          - "Mail domain: {{ iredmail_domain }}"
          - "SMTP ports: 25, {{ iredmail_smtp_port }}"
          - "IMAP: {{ iredmail_imap_port }}"
          - "Admin console: https://mail.{{ it_stack_domain }}/iredadmin"
      tags: [verify]
'@

# ── deploy-zammad.yml ─────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-zammad.yml" @'
---
# playbooks/deploy-zammad.yml
# Deploy and configure Zammad Help Desk on lab-comm1.
# Run with: make deploy-zammad
#
# Prerequisites:
#   - PostgreSQL + Elasticsearch running; iRedMail deployed for email integration
#   - vault/secrets.yml contains: vault_pg_zammad_pass, vault_zammad_secret_key_base

- name: "Deploy Zammad Help Desk"
  hosts: communications
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Zammad vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_zammad_pass is defined
          - vault_zammad_secret_key_base is defined
        fail_msg: "Missing Zammad vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: zammad
      tags: [zammad, communications, helpdesk]

  post_tasks:
    - name: "Verify Zammad health endpoint"
      ansible.builtin.uri:
        url: "http://localhost:{{ zammad_port }}/api/v1/getting_started"
        return_content: true
        status_code: 200
      register: zammad_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Zammad deployment summary"
      ansible.builtin.debug:
        msg:
          - "Zammad {{ zammad_version }} deployed on {{ inventory_hostname }}"
          - "URL: https://{{ zammad_fqdn }}"
          - "Port: {{ zammad_port }}"
          - "DB: {{ zammad_db_host }} / {{ zammad_db_name }}"
          - "Elasticsearch: {{ zammad_elasticsearch_host }}:{{ zammad_elasticsearch_port }}"
      tags: [verify]
'@

# ── deploy-elasticsearch.yml ──────────────────────────────────────────────────
Write-Playbook "$pb\deploy-elasticsearch.yml" @'
---
# playbooks/deploy-elasticsearch.yml
# Deploy and configure Elasticsearch 8 on lab-db1.
# Run with: make deploy-elasticsearch
#
# Prerequisites:
#   - PostgreSQL and Redis already deployed on lab-db1
#   - vault/secrets.yml contains: vault_elasticsearch_password

- name: "Deploy Elasticsearch Search & Analytics Engine"
  hosts: database
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Elasticsearch vault vars present"
      ansible.builtin.assert:
        that:
          - vault_elasticsearch_password is defined
        fail_msg: "Missing Elasticsearch vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: elasticsearch
      tags: [elasticsearch, database, search]

  post_tasks:
    - name: "Verify Elasticsearch cluster health"
      ansible.builtin.uri:
        url: "http://localhost:{{ elasticsearch_http_port }}/_cluster/health"
        user: "elastic"
        password: "{{ vault_elasticsearch_password }}"
        force_basic_auth: true
        return_content: true
        status_code: 200
      register: es_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Elasticsearch deployment summary"
      ansible.builtin.debug:
        msg:
          - "Elasticsearch {{ elasticsearch_version }} deployed on {{ inventory_hostname }}"
          - "HTTP port: {{ elasticsearch_http_port }}"
          - "Transport port: {{ elasticsearch_transport_port }}"
          - "Data dir: {{ elasticsearch_data_dir }}"
          - "Heap: {{ elasticsearch_heap_size }}"
      tags: [verify]
'@

Write-Host "Phase 2 + elasticsearch playbooks done"

# ── deploy-freepbx.yml ────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-freepbx.yml" @'
---
# playbooks/deploy-freepbx.yml
# Deploy and configure FreePBX (Asterisk) on lab-pbx1.
# Run with: make deploy-freepbx
#
# Prerequisites:
#   - Phase 1 complete; iRedMail deployed for voicemail-to-email
#   - vault/secrets.yml contains: vault_freepbx_admin_pass, vault_freepbx_db_pass

- name: "Deploy FreePBX VoIP PBX"
  hosts: communications
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert FreePBX vault vars present"
      ansible.builtin.assert:
        that:
          - vault_freepbx_admin_pass is defined
          - vault_freepbx_db_pass is defined
        fail_msg: "Missing FreePBX vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: freepbx
      tags: [freepbx, voip, communications]

  post_tasks:
    - name: "Verify SIP port listening"
      ansible.builtin.wait_for:
        port: "{{ freepbx_sip_port }}"
        host: localhost
        timeout: 30
        msg: "SIP port {{ freepbx_sip_port }} not listening"
      ignore_errors: true
      tags: [verify]

    - name: "Display FreePBX deployment summary"
      ansible.builtin.debug:
        msg:
          - "FreePBX {{ freepbx_version }} (Asterisk {{ asterisk_version }}) deployed on {{ inventory_hostname }}"
          - "Admin URL: https://{{ inventory_hostname }}/admin"
          - "SIP port: {{ freepbx_sip_port }} (TCP/UDP)"
          - "RTP range: {{ freepbx_rtp_start }}-{{ freepbx_rtp_end }}/UDP"
      tags: [verify]
'@

# ── deploy-suitecrm.yml ───────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-suitecrm.yml" @'
---
# playbooks/deploy-suitecrm.yml
# Deploy and configure SuiteCRM on lab-biz1.
# Run with: make deploy-suitecrm
#
# Prerequisites:
#   - Phase 1 complete; iRedMail for email campaigns
#   - vault/secrets.yml contains: vault_pg_suitecrm_pass, vault_suitecrm_admin_pass

- name: "Deploy SuiteCRM Customer Relationship Management"
  hosts: business
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert SuiteCRM vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_suitecrm_pass is defined
          - vault_suitecrm_admin_pass is defined
        fail_msg: "Missing SuiteCRM vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: suitecrm
      tags: [suitecrm, business, crm]

  post_tasks:
    - name: "Verify SuiteCRM HTTP response"
      ansible.builtin.uri:
        url: "http://localhost/"
        return_content: false
        status_code: 200
        follow_redirects: all
      register: crm_status
      ignore_errors: true
      tags: [verify]

    - name: "Display SuiteCRM deployment summary"
      ansible.builtin.debug:
        msg:
          - "SuiteCRM {{ suitecrm_version }} deployed on {{ inventory_hostname }}"
          - "URL: {{ suitecrm_site_url }}"
          - "Admin: {{ suitecrm_admin_user }}"
          - "Install dir: {{ suitecrm_install_dir }}"
          - "DB: {{ suitecrm_db_host }} / {{ suitecrm_db_name }}"
      tags: [verify]
'@

# ── deploy-odoo.yml ───────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-odoo.yml" @'
---
# playbooks/deploy-odoo.yml
# Deploy and configure Odoo ERP on lab-biz1.
# Run with: make deploy-odoo
#
# Prerequisites:
#   - Phase 1 complete; SuiteCRM deployed (shares lab-biz1)
#   - vault/secrets.yml contains: vault_pg_odoo_pass, vault_odoo_admin_pass, vault_odoo_master_pass

- name: "Deploy Odoo Enterprise Resource Planning"
  hosts: business
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Odoo vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_odoo_pass is defined
          - vault_odoo_admin_pass is defined
          - vault_odoo_master_pass is defined
        fail_msg: "Missing Odoo vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: odoo
      tags: [odoo, business, erp]

  post_tasks:
    - name: "Verify Odoo HTTP health"
      ansible.builtin.uri:
        url: "http://localhost:{{ odoo_http_port }}/web/health"
        return_content: true
        status_code: 200
      register: odoo_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Odoo deployment summary"
      ansible.builtin.debug:
        msg:
          - "Odoo {{ odoo_version }} deployed on {{ inventory_hostname }}"
          - "URL: https://erp.{{ it_stack_domain }}"
          - "HTTP port: {{ odoo_http_port }}"
          - "Longpolling port: {{ odoo_longpolling_port }}"
          - "Workers: {{ odoo_workers }}"
          - "DB: {{ odoo_db_host }} / odoo"
      tags: [verify]
'@

# ── deploy-openkm.yml ─────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-openkm.yml" @'
---
# playbooks/deploy-openkm.yml
# Deploy and configure OpenKM Document Management System on lab-biz1.
# Run with: make deploy-openkm
#
# Prerequisites:
#   - Phase 1 complete; Java 17 available
#   - vault/secrets.yml contains: vault_pg_openkm_pass, vault_openkm_admin_pass

- name: "Deploy OpenKM Document Management System"
  hosts: business
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert OpenKM vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_openkm_pass is defined
          - vault_openkm_admin_pass is defined
        fail_msg: "Missing OpenKM vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: openkm
      tags: [openkm, business, dms]

  post_tasks:
    - name: "Verify OpenKM HTTP port"
      ansible.builtin.wait_for:
        port: "{{ openkm_http_port }}"
        host: localhost
        timeout: 60
        msg: "OpenKM port {{ openkm_http_port }} not listening after 60s"
      ignore_errors: true
      tags: [verify]

    - name: "Display OpenKM deployment summary"
      ansible.builtin.debug:
        msg:
          - "OpenKM {{ openkm_version }} deployed on {{ inventory_hostname }}"
          - "URL: https://docs.{{ it_stack_domain }}"
          - "HTTP port: {{ openkm_http_port }}"
          - "Data dir: {{ openkm_data_dir }}"
          - "DB: {{ openkm_db_host }} / {{ openkm_db_name }}"
          - "JVM opts: {{ openkm_java_opts }}"
      tags: [verify]
'@

Write-Host "Phase 3 playbooks done"

# ── deploy-taiga.yml ──────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-taiga.yml" @'
---
# playbooks/deploy-taiga.yml
# Deploy and configure Taiga Project Management on lab-mgmt1.
# Run with: make deploy-taiga
#
# Prerequisites:
#   - Phase 1 complete; Keycloak for SSO LDAP integration
#   - vault/secrets.yml contains: vault_pg_taiga_pass, vault_taiga_secret_key, vault_taiga_admin_pass

- name: "Deploy Taiga Project Management Platform"
  hosts: it_management
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Taiga vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_taiga_pass is defined
          - vault_taiga_secret_key is defined
          - vault_taiga_admin_pass is defined
        fail_msg: "Missing Taiga vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: taiga
      tags: [taiga, it-management, projects]

  post_tasks:
    - name: "Verify Taiga backend API health"
      ansible.builtin.uri:
        url: "http://localhost:{{ taiga_backend_port }}/api/v1/"
        return_content: true
        status_code: 200
      register: taiga_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Taiga deployment summary"
      ansible.builtin.debug:
        msg:
          - "Taiga {{ taiga_version }} deployed on {{ inventory_hostname }}"
          - "URL: {{ taiga_site_url }}"
          - "Backend port: {{ taiga_backend_port }}"
          - "Events port: {{ taiga_events_port }}"
          - "LDAP: {{ taiga_ldap_server }}"
      tags: [verify]
'@

# ── deploy-snipeit.yml ────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-snipeit.yml" @'
---
# playbooks/deploy-snipeit.yml
# Deploy and configure Snipe-IT Asset Management on lab-mgmt1.
# Run with: make deploy-snipeit
#
# Prerequisites:
#   - Phase 1 complete; iRedMail for email notifications
#   - vault/secrets.yml contains: vault_pg_snipeit_pass, vault_snipeit_app_key, vault_snipeit_admin_pass

- name: "Deploy Snipe-IT Asset Management"
  hosts: it_management
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Snipe-IT vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_snipeit_pass is defined
          - vault_snipeit_app_key is defined
          - vault_snipeit_admin_pass is defined
        fail_msg: "Missing Snipe-IT vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: snipeit
      tags: [snipeit, it-management, assets]

  post_tasks:
    - name: "Verify Snipe-IT HTTP response"
      ansible.builtin.uri:
        url: "http://localhost/"
        return_content: false
        status_code: 200
        follow_redirects: all
      register: snipeit_status
      ignore_errors: true
      tags: [verify]

    - name: "Display Snipe-IT deployment summary"
      ansible.builtin.debug:
        msg:
          - "Snipe-IT {{ snipeit_version }} deployed on {{ inventory_hostname }}"
          - "URL: {{ snipeit_app_url }}"
          - "Install dir: {{ snipeit_install_dir }}"
          - "DB: {{ snipeit_db_host }} / {{ snipeit_db_name }}"
          - "Mail: {{ snipeit_mail_host }}:{{ snipeit_mail_port }}"
      tags: [verify]
'@

# ── deploy-glpi.yml ───────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-glpi.yml" @'
---
# playbooks/deploy-glpi.yml
# Deploy and configure GLPI ITSM on lab-mgmt1.
# Run with: make deploy-glpi
#
# Prerequisites:
#   - PostgreSQL running; Snipe-IT deployed (for asset sync API)
#   - vault/secrets.yml contains: vault_pg_glpi_pass, vault_glpi_admin_pass

- name: "Deploy GLPI IT Service Management"
  hosts: it_management
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert GLPI vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_glpi_pass is defined
          - vault_glpi_admin_pass is defined
        fail_msg: "Missing GLPI vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: glpi
      tags: [glpi, it-management, itsm]

  post_tasks:
    - name: "Verify GLPI HTTP response"
      ansible.builtin.uri:
        url: "http://localhost/"
        return_content: false
        status_code: 200
        follow_redirects: all
      register: glpi_status
      ignore_errors: true
      tags: [verify]

    - name: "Display GLPI deployment summary"
      ansible.builtin.debug:
        msg:
          - "GLPI {{ glpi_version }} deployed on {{ inventory_hostname }}"
          - "URL: {{ glpi_site_url }}"
          - "Install dir: {{ glpi_install_dir }}"
          - "Files dir: {{ glpi_files_dir }}"
          - "DB: {{ glpi_db_host }} / {{ glpi_db_name }}"
      tags: [verify]
'@

# ── deploy-zabbix.yml ─────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-zabbix.yml" @'
---
# playbooks/deploy-zabbix.yml
# Deploy and configure Zabbix Monitoring on lab-comm1.
# Run with: make deploy-zabbix
#
# Prerequisites:
#   - Phase 1 complete; PostgreSQL running; Mattermost deployed for alert webhooks
#   - vault/secrets.yml contains: vault_pg_zabbix_pass, vault_zabbix_admin_pass

- name: "Deploy Zabbix Infrastructure Monitoring"
  hosts: communications
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Zabbix vault vars present"
      ansible.builtin.assert:
        that:
          - vault_pg_zabbix_pass is defined
          - vault_zabbix_admin_pass is defined
        fail_msg: "Missing Zabbix vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: zabbix
      tags: [zabbix, monitoring, infrastructure]

  post_tasks:
    - name: "Verify Zabbix server port"
      ansible.builtin.wait_for:
        port: "{{ zabbix_server_port }}"
        host: localhost
        timeout: 30
      ignore_errors: true
      tags: [verify]

    - name: "Display Zabbix deployment summary"
      ansible.builtin.debug:
        msg:
          - "Zabbix {{ zabbix_version }} deployed on {{ inventory_hostname }}"
          - "Frontend URL: https://{{ zabbix_frontend_fqdn }}"
          - "Server port: {{ zabbix_server_port }}"
          - "DB: {{ zabbix_db_host }} / {{ zabbix_db_name }}"
      tags: [verify]
'@

# ── deploy-graylog.yml ────────────────────────────────────────────────────────
Write-Playbook "$pb\deploy-graylog.yml" @'
---
# playbooks/deploy-graylog.yml
# Deploy and configure Graylog Log Management on lab-proxy1.
# Run with: make deploy-graylog
#
# Prerequisites:
#   - Elasticsearch running on lab-db1; MongoDB available
#   - vault/secrets.yml contains: vault_graylog_password_secret, vault_graylog_root_password_sha2

- name: "Deploy Graylog Centralized Log Management"
  hosts: infrastructure
  gather_facts: true
  vars_files:
    - ../vault/secrets.yml

  pre_tasks:
    - name: "Assert Graylog vault vars present"
      ansible.builtin.assert:
        that:
          - vault_graylog_password_secret is defined
          - vault_graylog_root_password_sha2 is defined
        fail_msg: "Missing Graylog vault variables in vault/secrets.yml"

  roles:
    - role: common
      tags: [common]
    - role: graylog
      tags: [graylog, logging, infrastructure]

  post_tasks:
    - name: "Verify Graylog API health"
      ansible.builtin.uri:
        url: "http://localhost:{{ graylog_http_port }}/api/"
        return_content: true
        status_code: 200
      register: graylog_health
      ignore_errors: true
      tags: [verify]

    - name: "Display Graylog deployment summary"
      ansible.builtin.debug:
        msg:
          - "Graylog {{ graylog_version }} deployed on {{ inventory_hostname }}"
          - "URL: https://logs.{{ it_stack_domain }}"
          - "HTTP port: {{ graylog_http_port }}"
          - "Syslog UDP: {{ graylog_syslog_udp_port }}"
          - "GELF TCP: {{ graylog_gelf_tcp_port }}"
          - "Elasticsearch: {{ graylog_elasticsearch_hosts }}"
      tags: [verify]
'@

Write-Host "Phase 4 playbooks done"
Write-Host "ALL 15 PLAYBOOKS CREATED"
