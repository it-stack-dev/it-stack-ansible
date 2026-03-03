#!/usr/bin/env pwsh
# scripts/create-inventory.ps1
# Creates group_vars (collaboration, communications, business, it_management)
# and host_vars (lab-app1, lab-comm1, lab-pbx1, lab-biz1, lab-mgmt1)

$base = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-ansible"

function Write-YML { param($path, $content)
  $dir = Split-Path $path
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# ── group_vars/collaboration.yml ──────────────────────────────────────────────
Write-YML "$base\inventory\group_vars\collaboration.yml" @'
---
# ============================================================
# Collaboration Server Variables (lab-app1 - 10.0.50.13)
# inventory/group_vars/collaboration.yml
# ============================================================

# ── Nextcloud ────────────────────────────────────────────────
nextcloud_version:          "28"
nextcloud_install_dir:      "/var/www/nextcloud"
nextcloud_data_dir:         "/srv/nextcloud/data"
nextcloud_db_host:          "10.0.50.12"
nextcloud_db_name:          "nextcloud"
nextcloud_db_user:          "nextcloud"
nextcloud_admin_user:       "admin"
nextcloud_trusted_domains:
  - "cloud.{{ it_stack_domain }}"
  - "10.0.50.13"
nextcloud_php_memory_limit: "1024M"
nextcloud_max_upload:       "16G"
nextcloud_port:             80
nextcloud_https_port:       443

# ── Mattermost ───────────────────────────────────────────────
mattermost_version:         "9.5"
mattermost_install_dir:     "/opt/mattermost"
mattermost_data_dir:        "/opt/mattermost/data"
mattermost_db_host:         "10.0.50.12"
mattermost_db_name:         "mattermost"
mattermost_db_user:         "mattermost"
mattermost_site_url:        "https://chat.{{ it_stack_domain }}"
mattermost_port:            8065
mattermost_system_admin:    "mmadmin"
mattermost_team_name:       "IT-Stack Team"

# ── Jitsi Meet ───────────────────────────────────────────────
jitsi_domain:               "meet.{{ it_stack_domain }}"
jitsi_enable_auth:          true
jitsi_auth_type:            "jwt"
jitsi_jicofo_auth_user:     "focus"
jitsi_jvb_auth_user:        "jvb"
jitsi_stun_servers:
  - "stun.l.google.com:19302"
jitsi_prosody_port:         5222
jitsi_videobridge_port:     10000
'@

# ── group_vars/communications.yml ────────────────────────────────────────────
Write-YML "$base\inventory\group_vars\communications.yml" @'
---
# ============================================================
# Communications Server Variables (lab-comm1 + lab-pbx1)
# inventory/group_vars/communications.yml
# ============================================================

# ── iRedMail ─────────────────────────────────────────────────
iredmail_domain:                "{{ it_stack_domain }}"
iredmail_hostname:              "mail.{{ it_stack_domain }}"
iredmail_db_type:               "pgsql"
iredmail_db_host:               "10.0.50.12"
iredmail_postfix_mynetworks:    "127.0.0.0/8 10.0.50.0/24"
iredmail_mailbox_size_limit:    "2048M"
iredmail_message_size_limit:    "100M"
iredmail_smtp_port:             587
iredmail_imap_port:             993

# ── FreePBX (Asterisk) ───────────────────────────────────────
freepbx_version:                "17"
asterisk_version:               "20"
freepbx_install_dir:            "/var/www/html/admin"
freepbx_sip_port:               5060
freepbx_sips_port:              5061
freepbx_rtp_start:              10000
freepbx_rtp_end:                20000
freepbx_admin_email:            "pbxadmin@{{ it_stack_domain }}"
freepbx_db_host:                "localhost"
freepbx_db_name:                "freepbx"
asterisk_run_user:              "asterisk"

# ── Zammad ───────────────────────────────────────────────────
zammad_version:                 "6"
zammad_db_host:                 "10.0.50.12"
zammad_db_name:                 "zammad"
zammad_db_user:                 "zammad"
zammad_fqdn:                    "desk.{{ it_stack_domain }}"
zammad_port:                    3000
zammad_rails_env:               "production"
zammad_elasticsearch_host:      "10.0.50.12"
zammad_elasticsearch_port:      9200

# ── Zabbix (also on comm1 alongside desk services) ───────────
zabbix_version:                 "6.4"
zabbix_server_host:             "10.0.50.14"
zabbix_db_host:                 "10.0.50.12"
zabbix_db_name:                 "zabbix"
zabbix_db_user:                 "zabbix"
zabbix_frontend_fqdn:           "monitor.{{ it_stack_domain }}"
zabbix_server_port:             10051
zabbix_agent_port:              10050
zabbix_web_port:                80
'@

# ── group_vars/business.yml ───────────────────────────────────────────────────
Write-YML "$base\inventory\group_vars\business.yml" @'
---
# ============================================================
# Business Applications Server Variables (lab-biz1 - 10.0.50.17)
# inventory/group_vars/business.yml
# ============================================================

# ── SuiteCRM ─────────────────────────────────────────────────
suitecrm_version:           "7.14"
suitecrm_install_dir:       "/var/www/suitecrm"
suitecrm_db_host:           "10.0.50.12"
suitecrm_db_name:           "suitecrm"
suitecrm_db_user:           "suitecrm"
suitecrm_site_url:          "https://crm.{{ it_stack_domain }}"
suitecrm_admin_user:        "admin"
suitecrm_php_memory_limit:  "768M"
suitecrm_cron_interval:     "*/5 * * * *"

# ── Odoo ─────────────────────────────────────────────────────
odoo_version:               "17.0"
odoo_install_dir:           "/opt/odoo"
odoo_config_dir:            "/etc/odoo"
odoo_log_dir:               "/var/log/odoo"
odoo_db_host:               "10.0.50.12"
odoo_db_user:               "odoo"
odoo_admin_email:           "admin@{{ it_stack_domain }}"
odoo_http_port:             8069
odoo_longpolling_port:      8072
odoo_workers:               4
odoo_max_cron_threads:      2
odoo_limit_memory_hard:     "2684354560"   # 2.5 GB
odoo_limit_memory_soft:     "2147483648"   # 2 GB
odoo_limit_time_cpu:        60
odoo_limit_time_real:       120

# ── OpenKM ───────────────────────────────────────────────────
openkm_version:             "7.1"
openkm_install_dir:         "/opt/openkm"
openkm_data_dir:            "/srv/openkm/data"
openkm_db_host:             "10.0.50.12"
openkm_db_name:             "openkm"
openkm_db_user:             "openkm"
openkm_http_port:           8080
openkm_tomcat_port:         8009
openkm_java_opts:           "-Xmx2g -Xms512m"
openkm_admin_user:          "okmAdmin"
openkm_repository_home:     "/srv/openkm/data"
'@

# ── group_vars/it_management.yml ─────────────────────────────────────────────
Write-YML "$base\inventory\group_vars\it_management.yml" @'
---
# ============================================================
# IT Management Server Variables (lab-mgmt1 - 10.0.50.18)
# inventory/group_vars/it_management.yml
# ============================================================

# ── Taiga ────────────────────────────────────────────────────
taiga_version:              "6.8"
taiga_install_dir:          "/opt/taiga"
taiga_backend_dir:          "/opt/taiga/taiga-back"
taiga_frontend_dir:         "/opt/taiga/taiga-front"
taiga_db_host:              "10.0.50.12"
taiga_db_name:              "taiga"
taiga_db_user:              "taiga"
taiga_site_url:             "https://pm.{{ it_stack_domain }}"
taiga_backend_port:         8001
taiga_events_port:          8888
taiga_secret_key:           "{{ vault_taiga_secret_key }}"
taiga_enable_github_auth:   false
taiga_enable_ldap:          true
taiga_ldap_server:          "ldap://10.0.50.11"

# ── Snipe-IT ─────────────────────────────────────────────────
snipeit_version:            "7.0"
snipeit_install_dir:        "/var/www/snipeit"
snipeit_db_host:            "10.0.50.12"
snipeit_db_name:            "snipeit"
snipeit_db_user:            "snipeit"
snipeit_app_url:            "https://assets.{{ it_stack_domain }}"
snipeit_app_port:           80
snipeit_mail_host:          "mail.{{ it_stack_domain }}"
snipeit_mail_port:          587
snipeit_mail_from:          "assets@{{ it_stack_domain }}"
snipeit_php_version:        "8.2"

# ── GLPI ─────────────────────────────────────────────────────
glpi_version:               "10.0.14"
glpi_install_dir:           "/var/www/glpi"
glpi_files_dir:             "/srv/glpi/files"
glpi_db_host:               "10.0.50.12"
glpi_db_name:               "glpi"
glpi_db_user:               "glpi"
glpi_site_url:              "https://itsm.{{ it_stack_domain }}"
glpi_port:                  80
glpi_admin_email:           "itsm@{{ it_stack_domain }}"
glpi_cron_interval:         "*/5 * * * *"
'@

Write-Host "group_vars done"

# ── host_vars ─────────────────────────────────────────────────────────────────
$hostVarsDir = "$base\inventory\host_vars"

Write-YML "$hostVarsDir\lab-app1.yml" @'
---
# inventory/host_vars/lab-app1.yml
# Collaboration server — Nextcloud + Mattermost + Jitsi
ansible_host:           "10.0.50.13"
server_role:            "collaboration"
server_description:     "Nextcloud + Mattermost + Jitsi Meet"
server_ram_gb:          24
server_vcpus:           8
server_disk_gb:         500

# PHP-FPM pool settings tuned for 24 GB RAM
php_fpm_pm:             "dynamic"
php_fpm_max_children:   50
php_fpm_start_servers:  10
php_fpm_min_spare:      5
php_fpm_max_spare:      20
php_memory_limit:       "1024M"

# UFW rules specific to this host
ufw_allow_ports:
  - { port: 80,    proto: tcp, comment: "HTTP" }
  - { port: 443,   proto: tcp, comment: "HTTPS" }
  - { port: 8065,  proto: tcp, comment: "Mattermost" }
  - { port: 10000, proto: udp, comment: "Jitsi WebRTC" }
  - { port: 4443,  proto: tcp, comment: "Jitsi Harvester" }
'@

Write-YML "$hostVarsDir\lab-comm1.yml" @'
---
# inventory/host_vars/lab-comm1.yml
# Communications server — iRedMail + Zammad + Zabbix
ansible_host:           "10.0.50.14"
server_role:            "communications"
server_description:     "iRedMail + Zammad Help Desk + Zabbix Monitoring"
server_ram_gb:          16
server_vcpus:           6
server_disk_gb:         200

ufw_allow_ports:
  - { port: 25,    proto: tcp, comment: "SMTP" }
  - { port: 143,   proto: tcp, comment: "IMAP" }
  - { port: 993,   proto: tcp, comment: "IMAPS" }
  - { port: 465,   proto: tcp, comment: "SMTPS" }
  - { port: 587,   proto: tcp, comment: "Submission" }
  - { port: 80,    proto: tcp, comment: "HTTP" }
  - { port: 443,   proto: tcp, comment: "HTTPS" }
  - { port: 3000,  proto: tcp, comment: "Zammad" }
  - { port: 10051, proto: tcp, comment: "Zabbix Server" }
'@

Write-YML "$hostVarsDir\lab-pbx1.yml" @'
---
# inventory/host_vars/lab-pbx1.yml
# VoIP server — FreePBX / Asterisk
ansible_host:           "10.0.50.16"
server_role:            "voip"
server_description:     "FreePBX + Asterisk VoIP PBX"
server_ram_gb:          8
server_vcpus:           4
server_disk_gb:         100

ufw_allow_ports:
  - { port: 80,    proto: tcp, comment: "FreePBX Admin HTTP" }
  - { port: 443,   proto: tcp, comment: "FreePBX Admin HTTPS" }
  - { port: 5060,  proto: tcp, comment: "SIP TCP" }
  - { port: 5060,  proto: udp, comment: "SIP UDP" }
  - { port: 5061,  proto: tcp, comment: "SIP TLS" }
  - { port: "10000:20000", proto: udp, comment: "RTP media" }
'@

Write-YML "$hostVarsDir\lab-biz1.yml" @'
---
# inventory/host_vars/lab-biz1.yml
# Business applications server — SuiteCRM + Odoo + OpenKM
ansible_host:           "10.0.50.17"
server_role:            "business"
server_description:     "SuiteCRM (CRM) + Odoo (ERP) + OpenKM (DMS)"
server_ram_gb:          24
server_vcpus:           8
server_disk_gb:         500

php_fpm_pm:             "dynamic"
php_fpm_max_children:   30
php_fpm_start_servers:  5
php_fpm_min_spare:      3
php_fpm_max_spare:      10
php_memory_limit:       "768M"

ufw_allow_ports:
  - { port: 80,    proto: tcp, comment: "HTTP" }
  - { port: 443,   proto: tcp, comment: "HTTPS" }
  - { port: 8069,  proto: tcp, comment: "Odoo HTTP" }
  - { port: 8072,  proto: tcp, comment: "Odoo Longpolling" }
  - { port: 8080,  proto: tcp, comment: "OpenKM" }
'@

Write-YML "$hostVarsDir\lab-mgmt1.yml" @'
---
# inventory/host_vars/lab-mgmt1.yml
# IT Management server — Taiga + Snipe-IT + GLPI
ansible_host:           "10.0.50.18"
server_role:            "it_management"
server_description:     "Taiga (Projects) + Snipe-IT (Assets) + GLPI (ITSM)"
server_ram_gb:          16
server_vcpus:           6
server_disk_gb:         200

php_fpm_pm:             "dynamic"
php_fpm_max_children:   30
php_fpm_start_servers:  5
php_fpm_min_spare:      3
php_fpm_max_spare:      10
php_memory_limit:       "512M"

ufw_allow_ports:
  - { port: 80,    proto: tcp, comment: "HTTP" }
  - { port: 443,   proto: tcp, comment: "HTTPS" }
  - { port: 8001,  proto: tcp, comment: "Taiga Backend" }
  - { port: 8888,  proto: tcp, comment: "Taiga Events" }
'@

Write-Host "host_vars done"
Write-Host "ALL INVENTORY VARS DONE"
