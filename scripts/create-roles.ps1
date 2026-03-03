param()
$base = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-ansible"

function Write-Role {
    param([string]$path, [string]$content)
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
}

# ── REMAINING DEFAULTS ───────────────────────────────────────────────────────

Write-Role "$base\roles\openkm\defaults\main.yml" @"
---
# roles/openkm/defaults/main.yml

openkm_version:           "6.3.12"
openkm_install_dir:       "/opt/openkm"
openkm_data_dir:          "/var/lib/openkm"
openkm_log_dir:           "/var/log/openkm"
openkm_user:              "openkm"
openkm_group:             "openkm"

openkm_http_port:         8080
openkm_https_port:        8443
openkm_hostname:          "docs.example.com"

openkm_db_host:           "10.0.50.12"
openkm_db_port:           5432
openkm_db_name:           "openkm"
openkm_db_user:           "openkm"

openkm_elasticsearch_url: "http://10.0.50.12:9200"

openkm_keycloak_url:      "https://id.example.com"
openkm_keycloak_realm:    "it-stack"
openkm_saml_client:       "openkm"

openkm_java_opts:         "-Xms512m -Xmx2g"
openkm_admin_user:        "okmAdmin"

openkm_nextcloud_url:     "https://cloud.example.com"
openkm_nextcloud_user:    "openkm-svc"

openkm_firewall_ports:
  - { port: "8080", proto: tcp, from: "10.0.50.0/24" }
  - { port: "8443", proto: tcp, from: "10.0.50.0/24" }
"@

Write-Role "$base\roles\taiga\defaults\main.yml" @"
---
# roles/taiga/defaults/main.yml

taiga_version:            "6.8.1"
taiga_install_dir:        "/opt/taiga"
taiga_log_dir:            "/var/log/taiga"
taiga_user:               "taiga"
taiga_group:              "taiga"

taiga_backend_port:       8000
taiga_frontend_port:      9001
taiga_events_port:        8888
taiga_hostname:           "pm.example.com"

taiga_db_host:            "10.0.50.12"
taiga_db_port:            5432
taiga_db_name:            "taiga"
taiga_db_user:            "taiga"

taiga_redis_url:          "redis://10.0.50.12:6379/0"
taiga_events_redis:       "redis://10.0.50.12:6379/1"

taiga_keycloak_url:       "https://id.example.com"
taiga_keycloak_realm:     "it-stack"
taiga_oidc_client:        "taiga"

taiga_mattermost_webhook: "https://chat.example.com/hooks/taiga-webhook"

taiga_django_workers:     3
taiga_async_workers:      2
taiga_python_version:     "3.12"

taiga_smtp_host:          "10.0.50.14"
taiga_smtp_port:          25
taiga_smtp_from:          "taiga@example.com"

taiga_firewall_ports:
  - { port: "8000", proto: tcp, from: "10.0.50.0/24" }
  - { port: "9001", proto: tcp, from: "10.0.50.0/24" }
  - { port: "8888", proto: tcp, from: "10.0.50.0/24" }
"@

Write-Role "$base\roles\snipeit\defaults\main.yml" @"
---
# roles/snipeit/defaults/main.yml

snipeit_version:          "7.0.13"
snipeit_install_dir:      "/var/www/snipeit"
snipeit_log_dir:          "/var/log/snipeit"
snipeit_user:             "www-data"
snipeit_group:            "www-data"

snipeit_http_port:        80
snipeit_https_port:       443
snipeit_hostname:         "assets.example.com"

snipeit_db_host:          "10.0.50.12"
snipeit_db_port:          3306
snipeit_db_name:          "snipeit"
snipeit_db_user:          "snipeit"

snipeit_redis_host:       "10.0.50.12"
snipeit_redis_port:       6379

snipeit_keycloak_url:     "https://id.example.com"
snipeit_keycloak_realm:   "it-stack"
snipeit_saml_client:      "snipeit"

snipeit_php_memory_limit: "512M"
snipeit_app_name:         "IT-Stack Assets"

snipeit_smtp_host:        "10.0.50.14"
snipeit_smtp_port:        25
snipeit_smtp_from:        "assets@example.com"

snipeit_odoo_api_url:     "http://10.0.50.17:8069"

snipeit_firewall_ports:
  - { port: "80",  proto: tcp, from: "10.0.50.0/24" }
  - { port: "443", proto: tcp, from: "10.0.50.0/24" }
"@

Write-Role "$base\roles\glpi\defaults\main.yml" @"
---
# roles/glpi/defaults/main.yml

glpi_version:             "10.0.15"
glpi_install_dir:         "/var/www/glpi"
glpi_log_dir:             "/var/log/glpi"
glpi_user:                "www-data"
glpi_group:               "www-data"

glpi_http_port:           80
glpi_https_port:          443
glpi_hostname:            "itsm.example.com"

glpi_db_host:             "10.0.50.12"
glpi_db_port:             3306
glpi_db_name:             "glpi"
glpi_db_user:             "glpi"

glpi_keycloak_url:        "https://id.example.com"
glpi_keycloak_realm:      "it-stack"
glpi_saml_client:         "glpi"

glpi_php_memory_limit:    "256M"
glpi_cron_interval:       1

glpi_smtp_host:           "10.0.50.14"
glpi_smtp_port:           25

glpi_zammad_api_url:      "http://10.0.50.14:3000"
glpi_snipeit_api_url:     "http://10.0.50.18"

glpi_firewall_ports:
  - { port: "80",  proto: tcp, from: "10.0.50.0/24" }
  - { port: "443", proto: tcp, from: "10.0.50.0/24" }
"@

Write-Role "$base\roles\zabbix\defaults\main.yml" @"
---
# roles/zabbix/defaults/main.yml

zabbix_version:           "7.0"
zabbix_install_dir:       "/etc/zabbix"
zabbix_log_dir:           "/var/log/zabbix"
zabbix_user:              "zabbix"
zabbix_group:             "zabbix"

zabbix_server_port:       10051
zabbix_agent_port:        10050
zabbix_web_port:          80
zabbix_hostname:          "monitoring.example.com"

zabbix_db_host:           "10.0.50.12"
zabbix_db_port:           5432
zabbix_db_name:           "zabbix"
zabbix_db_user:           "zabbix"

zabbix_keycloak_url:      "https://id.example.com"
zabbix_keycloak_realm:    "it-stack"
zabbix_saml_client:       "zabbix"

zabbix_mattermost_webhook: "https://chat.example.com/hooks/zabbix-ops-alerts"
zabbix_admin_email:       "ops@example.com"

zabbix_smtp_host:         "10.0.50.14"
zabbix_smtp_port:         25
zabbix_smtp_from:         "zabbix@example.com"

zabbix_monitored_hosts:
  - { host: "lab-id1",    ip: "10.0.50.11", group: "Identity" }
  - { host: "lab-db1",    ip: "10.0.50.12", group: "Database" }
  - { host: "lab-app1",   ip: "10.0.50.13", group: "Collaboration" }
  - { host: "lab-comm1",  ip: "10.0.50.14", group: "Communications" }
  - { host: "lab-proxy1", ip: "10.0.50.15", group: "Infrastructure" }
  - { host: "lab-pbx1",   ip: "10.0.50.16", group: "VoIP" }
  - { host: "lab-biz1",   ip: "10.0.50.17", group: "Business" }
  - { host: "lab-mgmt1",  ip: "10.0.50.18", group: "IT-Management" }

zabbix_firewall_ports:
  - { port: "10051", proto: tcp, from: "10.0.50.0/24" }
  - { port: "10050", proto: tcp, from: "10.0.50.0/24" }
  - { port: "80",    proto: tcp, from: "10.0.50.0/24" }
"@

Write-Role "$base\roles\graylog\defaults\main.yml" @"
---
# roles/graylog/defaults/main.yml

graylog_version:           "6.0"
graylog_install_dir:       "/etc/graylog"
graylog_data_dir:          "/var/lib/graylog-server"
graylog_log_dir:           "/var/log/graylog-server"
graylog_user:              "graylog"
graylog_group:             "graylog"

graylog_http_port:         9000
graylog_hostname:          "logs.example.com"

graylog_mongodb_uri:       "mongodb://localhost:27017/graylog"
graylog_elasticsearch_hosts: "http://10.0.50.12:9200"

graylog_keycloak_url:      "https://id.example.com"
graylog_keycloak_realm:    "it-stack"
graylog_oidc_client:       "graylog"

graylog_heap_size:         "2g"
graylog_message_journal_max_size: "5gb"

graylog_inputs:
  - { title: "Syslog UDP",  type: "org.graylog2.inputs.syslog.udp.SyslogUDPInput",  port: 1514 }
  - { title: "GELF UDP",    type: "org.graylog2.inputs.gelf.udp.GELFUDPInput",      port: 12201 }
  - { title: "GELF HTTP",   type: "org.graylog2.inputs.gelf.http.GELFHTTPInput",    port: 12202 }

graylog_zabbix_api_url:    "http://10.0.50.14:10051"

graylog_firewall_ports:
  - { port: "9000",  proto: tcp, from: "10.0.50.0/24" }
  - { port: "1514",  proto: udp, from: "10.0.50.0/24" }
  - { port: "12201", proto: udp, from: "10.0.50.0/24" }
  - { port: "12202", proto: tcp, from: "10.0.50.0/24" }
"@

# ── HANDLERS (all 15 roles) ───────────────────────────────────────────────────

$roles_services = @{
    nextcloud     = @{ svc = "nginx php8.3-fpm";           restart = @("restart nginx","restart php8.3-fpm") }
    mattermost    = @{ svc = "mattermost";                  restart = @("restart mattermost") }
    jitsi         = @{ svc = "jicofo jitsi-videobridge2 prosody";  restart = @("restart jicofo","restart jitsi-videobridge2","restart prosody") }
    iredmail      = @{ svc = "postfix dovecot amavis";      restart = @("restart postfix","restart dovecot","restart amavis") }
    zammad        = @{ svc = "zammad";                      restart = @("restart zammad") }
    elasticsearch = @{ svc = "elasticsearch";               restart = @("restart elasticsearch") }
    freepbx       = @{ svc = "asterisk apache2";            restart = @("restart asterisk","restart apache2") }
    suitecrm      = @{ svc = "nginx php8.3-fpm";            restart = @("restart nginx","restart php8.3-fpm") }
    odoo          = @{ svc = "odoo";                        restart = @("restart odoo") }
    openkm        = @{ svc = "openkm";                      restart = @("restart openkm") }
    taiga         = @{ svc = "taiga-backend taiga-async taiga-events nginx"; restart = @("restart taiga-backend","restart taiga-async","restart taiga-events","restart nginx") }
    snipeit       = @{ svc = "nginx php8.3-fpm";            restart = @("restart nginx","restart php8.3-fpm") }
    glpi          = @{ svc = "nginx php8.3-fpm";            restart = @("restart nginx","restart php8.3-fpm") }
    zabbix        = @{ svc = "zabbix-server zabbix-agent2"; restart = @("restart zabbix-server","restart zabbix-agent2") }
    graylog       = @{ svc = "graylog-server";              restart = @("restart graylog-server") }
}

foreach ($role in $roles_services.Keys) {
    $restartBlocks = ($roles_services[$role].restart | ForEach-Object {
        $parts = $_ -split " "
        $action = $parts[0]
        $svcName = $parts[1]
        "- name: `"$action $svcName`"`n  ansible.builtin.systemd:`n    name: $svcName`n    state: restarted"
    }) -join "`n`n"

    Write-Role "$base\roles\$role\handlers\main.yml" @"
---
# roles/$role/handlers/main.yml

$restartBlocks

- name: "reload systemd"
  ansible.builtin.systemd:
    daemon_reload: true
"@
}

Write-Output "handlers done"

# ── META (all 15 roles) ───────────────────────────────────────────────────────

$roles_meta = @{
    nextcloud     = @{ category = "collaboration";  tags = "nextcloud,files,collaboration";    desc = "Deploy Nextcloud file sync and collaboration platform" }
    mattermost    = @{ category = "collaboration";  tags = "mattermost,chat,messaging";        desc = "Deploy Mattermost team messaging platform" }
    jitsi         = @{ category = "collaboration";  tags = "jitsi,video,conferencing";         desc = "Deploy Jitsi Meet video conferencing server" }
    iredmail      = @{ category = "communications"; tags = "iredmail,email,smtp,imap";         desc = "Deploy iRedMail complete mail server stack" }
    zammad        = @{ category = "communications"; tags = "zammad,helpdesk,ticketing";        desc = "Deploy Zammad help desk and ticketing system" }
    elasticsearch = @{ category = "database";       tags = "elasticsearch,search,logging";     desc = "Deploy Elasticsearch search and analytics engine" }
    freepbx       = @{ category = "communications"; tags = "freepbx,asterisk,voip,pbx";       desc = "Deploy FreePBX/Asterisk VoIP PBX system" }
    suitecrm      = @{ category = "business";       tags = "suitecrm,crm,sales";              desc = "Deploy SuiteCRM customer relationship manager" }
    odoo          = @{ category = "business";       tags = "odoo,erp,accounting";             desc = "Deploy Odoo ERP and business management platform" }
    openkm        = @{ category = "business";       tags = "openkm,dms,documents";            desc = "Deploy OpenKM document management system" }
    taiga         = @{ category = "it-management";  tags = "taiga,projects,agile,scrum";      desc = "Deploy Taiga project management platform" }
    snipeit       = @{ category = "it-management";  tags = "snipeit,assets,inventory";        desc = "Deploy Snipe-IT asset management system" }
    glpi          = @{ category = "it-management";  tags = "glpi,itsm,servicedesk";           desc = "Deploy GLPI IT service management platform" }
    zabbix        = @{ category = "infrastructure"; tags = "zabbix,monitoring,alerting";      desc = "Deploy Zabbix infrastructure monitoring platform" }
    graylog       = @{ category = "infrastructure"; tags = "graylog,logging,siem";            desc = "Deploy Graylog centralized log management" }
}

foreach ($role in $roles_meta.Keys) {
    $m = $roles_meta[$role]
    $tagsYaml = ($m.tags -split ",") | ForEach-Object { "    - $_" }
    $tagsBlock = $tagsYaml -join "`n"

    Write-Role "$base\roles\$role\meta\main.yml" @"
---
# roles/$role/meta/main.yml

galaxy_info:
  role_name: $role
  author: it-stack-dev
  description: $($m.desc)
  license: Apache-2.0
  min_ansible_version: "2.15"
  platforms:
    - name: Ubuntu
      versions:
        - "24.04"
  galaxy_tags:
$tagsBlock
    - it-stack

dependencies:
  - role: common
"@
}

Write-Output "meta done"

# ── TASKS/MAIN.YML (all 15 roles) ─────────────────────────────────────────────

$roles_extra_tasks = @{
    nextcloud     = @("# tasks/main.yml - nextcloud")
    mattermost    = @("# tasks/main.yml - mattermost")
    jitsi         = @("# tasks/main.yml - jitsi")
    iredmail      = @("# tasks/main.yml - iredmail")
    zammad        = @("# tasks/main.yml - zammad")
    elasticsearch = @("# tasks/main.yml - elasticsearch")
    freepbx       = @("# tasks/main.yml - freepbx")
    suitecrm      = @("# tasks/main.yml - suitecrm")
    odoo          = @("# tasks/main.yml - odoo")
    openkm        = @("# tasks/main.yml - openkm")
    taiga         = @("# tasks/main.yml - taiga")
    snipeit       = @("# tasks/main.yml - snipeit")
    glpi          = @("# tasks/main.yml - glpi")
    zabbix        = @("# tasks/main.yml - zabbix")
    graylog       = @("# tasks/main.yml - graylog")
}

foreach ($role in $roles_extra_tasks.Keys) {
    Write-Role "$base\roles\$role\tasks\main.yml" @"
---
$($roles_extra_tasks[$role][0])

- name: "Import $role installation tasks"
  ansible.builtin.import_tasks: install.yml
  tags: [$role, install]

- name: "Import $role configuration tasks"
  ansible.builtin.import_tasks: configure.yml
  tags: [$role, configure]
"@
}

Write-Output "tasks/main done"
Write-Output "ALL DONE - handlers, meta, tasks/main created for all 15 roles"