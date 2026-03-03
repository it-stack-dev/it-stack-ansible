param()
$base = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-ansible"

function Write-Role {
    param([string]$path, [string]$content)
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
}

# ── nextcloud ─────────────────────────────────────────────────────────────────
Write-Role "$base\roles\nextcloud\tasks\install.yml" @"
---
# roles/nextcloud/tasks/install.yml

- name: "Add PHP 8.3 apt repository (Ondrej)"
  ansible.builtin.apt_repository:
    repo: "ppa:ondrej/php"
    state: present
    update_cache: true

- name: "Install PHP 8.3 and required extensions"
  ansible.builtin.apt:
    name:
      - php8.3
      - php8.3-fpm
      - php8.3-gd
      - php8.3-curl
      - php8.3-zip
      - php8.3-xml
      - php8.3-mbstring
      - php8.3-pgsql
      - php8.3-intl
      - php8.3-bcmath
      - php8.3-gmp
      - php8.3-imagick
      - php8.3-redis
      - php8.3-opcache
      - nginx
      - redis-tools
    state: present

- name: "Create Nextcloud directories"
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ nextcloud_user }}"
    group: "{{ nextcloud_group }}"
    mode: "0750"
  loop:
    - "{{ nextcloud_install_dir }}"
    - "{{ nextcloud_data_dir }}"
    - "{{ nextcloud_log_dir }}"

- name: "Check if Nextcloud is already installed"
  ansible.builtin.stat:
    path: "{{ nextcloud_install_dir }}/version.php"
  register: nc_installed

- name: "Download Nextcloud {{ nextcloud_version }}"
  ansible.builtin.get_url:
    url: "https://download.nextcloud.com/server/releases/nextcloud-{{ nextcloud_version }}.tar.bz2"
    dest: "/tmp/nextcloud-{{ nextcloud_version }}.tar.bz2"
    mode: "0644"
  when: not nc_installed.stat.exists

- name: "Extract Nextcloud archive"
  ansible.builtin.unarchive:
    src: "/tmp/nextcloud-{{ nextcloud_version }}.tar.bz2"
    dest: /var/www
    remote_src: true
    owner: "{{ nextcloud_user }}"
    group: "{{ nextcloud_group }}"
  when: not nc_installed.stat.exists

- name: "Set Nextcloud directory permissions"
  ansible.builtin.file:
    path: "{{ nextcloud_install_dir }}"
    owner: "{{ nextcloud_user }}"
    group: "{{ nextcloud_group }}"
    recurse: true

- name: "Open Nextcloud firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Nextcloud"
  loop: "{{ nextcloud_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\nextcloud\tasks\configure.yml" @"
---
# roles/nextcloud/tasks/configure.yml

- name: "Deploy PHP-FPM pool config for Nextcloud"
  ansible.builtin.template:
    src: nextcloud-fpm.conf.j2
    dest: /etc/php/8.3/fpm/pool.d/nextcloud.conf
    mode: "0644"
  notify: restart php8.3-fpm

- name: "Deploy Nginx vhost for Nextcloud"
  ansible.builtin.template:
    src: nextcloud-nginx.conf.j2
    dest: /etc/nginx/sites-available/nextcloud
    mode: "0644"
  notify: restart nginx

- name: "Enable Nextcloud Nginx site"
  ansible.builtin.file:
    src: /etc/nginx/sites-available/nextcloud
    dest: /etc/nginx/sites-enabled/nextcloud
    state: link
  notify: restart nginx

- name: "Remove default Nginx site"
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: restart nginx

- name: "Run Nextcloud installation (occ maintenance:install)"
  ansible.builtin.command:
    cmd: >
      php occ maintenance:install
      --database=pgsql
      --database-host={{ nextcloud_db_host }}
      --database-name={{ nextcloud_db_name }}
      --database-user={{ nextcloud_db_user }}
      --database-pass={{ vault_nextcloud_db_pass }}
      --admin-user={{ nextcloud_admin_user }}
      --admin-pass={{ vault_nextcloud_admin_pass }}
      --data-dir={{ nextcloud_data_dir }}
    chdir: "{{ nextcloud_install_dir }}"
    creates: "{{ nextcloud_install_dir }}/config/config.php"
  become: true
  become_user: "{{ nextcloud_user }}"

- name: "Set Nextcloud trusted domain"
  ansible.builtin.command:
    cmd: "php occ config:system:set trusted_domains 0 --value={{ nextcloud_hostname }}"
    chdir: "{{ nextcloud_install_dir }}"
  become: true
  become_user: "{{ nextcloud_user }}"

- name: "Configure Redis session caching"
  ansible.builtin.command:
    cmd: "php occ config:system:set {{ item.key }} --value={{ item.value }}"
    chdir: "{{ nextcloud_install_dir }}"
  become: true
  become_user: "{{ nextcloud_user }}"
  loop:
    - { key: "memcache.locking", value: "\\\\OC\\\\Memcache\\\\Redis" }
    - { key: "memcache.distributed", value: "\\\\OC\\\\Memcache\\\\Redis" }
    - { key: "redis host", value: "{{ nextcloud_redis_host }}" }
    - { key: "redis port", value: "{{ nextcloud_redis_port }}" }

- name: "Set up Nextcloud cron job"
  ansible.builtin.cron:
    name: "Nextcloud cron"
    minute: "*/{{ nextcloud_cron_interval }}"
    user: "{{ nextcloud_user }}"
    job: "php -f {{ nextcloud_install_dir }}/cron.php"
"@

Write-Role "$base\roles\nextcloud\templates\nextcloud-nginx.conf.j2" @"
# templates/nextcloud-nginx.conf.j2

upstream php-handler {
    server unix:/run/php/php8.3-fpm-nextcloud.sock;
}

server {
    listen 80;
    server_name {{ nextcloud_hostname }};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name {{ nextcloud_hostname }};

    ssl_certificate     /etc/ssl/certs/it-stack.crt;
    ssl_certificate_key /etc/ssl/private/it-stack.key;

    root {{ nextcloud_install_dir }};
    index index.php index.html;

    client_max_body_size {{ nextcloud_max_upload_size }};
    fastcgi_buffers 64 4K;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
    add_header Referrer-Policy "no-referrer";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Permitted-Cross-Domain-Policies "none";
    add_header X-Robots-Tag "none";
    add_header X-XSS-Protection "1; mode=block";

    location = /robots.txt { allow all; log_not_found off; access_log off; }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:\$|/) { deny all; }
    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) { deny all; }

    location / {
        rewrite ^ /index.php;
    }

    location ~ ^\/(?:index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+|.+\/richdocumentscode\/proxy)\.php(?:\$|\/) {
        fastcgi_split_path_info ^(.+?\.php)(\/.*|\$);
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass php-handler;
        fastcgi_read_timeout 3600;
    }

    location ~ \.(?:css|js|woff2?|svg|gif|map)\$ {
        try_files \$uri /index.php\$request_uri;
        expires 6M;
        add_header Cache-Control "public";
    }

    location ~ \.(?:png|html|ttf|ico|jpg|jpeg|bcmap|mp4|webm)\$ {
        try_files \$uri /index.php\$request_uri;
    }
}
"@

# ── mattermost ────────────────────────────────────────────────────────────────
Write-Role "$base\roles\mattermost\tasks\install.yml" @"
---
# roles/mattermost/tasks/install.yml

- name: "Create mattermost system group"
  ansible.builtin.group:
    name: "{{ mattermost_group }}"
    state: present
    system: true

- name: "Create mattermost system user"
  ansible.builtin.user:
    name: "{{ mattermost_user }}"
    group: "{{ mattermost_group }}"
    home: "{{ mattermost_install_dir }}"
    shell: /usr/sbin/nologin
    system: true
    create_home: false

- name: "Create Mattermost directories"
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ mattermost_user }}"
    group: "{{ mattermost_group }}"
    mode: "0750"
  loop:
    - "{{ mattermost_install_dir }}"
    - "{{ mattermost_data_dir }}"
    - "{{ mattermost_log_dir }}"

- name: "Check if Mattermost {{ mattermost_version }} is installed"
  ansible.builtin.stat:
    path: "{{ mattermost_install_dir }}/mattermost-{{ mattermost_version }}/bin/mattermost"
  register: mm_bin

- name: "Download Mattermost {{ mattermost_version }}"
  ansible.builtin.get_url:
    url: "https://releases.mattermost.com/{{ mattermost_version }}/mattermost-{{ mattermost_version }}-linux-amd64.tar.gz"
    dest: "/tmp/mattermost-{{ mattermost_version }}.tar.gz"
    mode: "0644"
  when: not mm_bin.stat.exists

- name: "Extract Mattermost archive"
  ansible.builtin.unarchive:
    src: "/tmp/mattermost-{{ mattermost_version }}.tar.gz"
    dest: "{{ mattermost_install_dir }}"
    remote_src: true
    owner: "{{ mattermost_user }}"
    group: "{{ mattermost_group }}"
    extra_opts: [--transform, "s/^mattermost/mattermost-{{ mattermost_version }}/"]
  when: not mm_bin.stat.exists

- name: "Symlink mattermost/current → versioned directory"
  ansible.builtin.file:
    src: "{{ mattermost_install_dir }}/mattermost-{{ mattermost_version }}"
    dest: "{{ mattermost_install_dir }}/current"
    state: link
    owner: "{{ mattermost_user }}"
    group: "{{ mattermost_group }}"

- name: "Deploy Mattermost systemd service"
  ansible.builtin.template:
    src: mattermost.service.j2
    dest: /etc/systemd/system/mattermost.service
    mode: "0644"
  notify: [reload systemd, restart mattermost]

- name: "Open Mattermost firewall port"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Mattermost"
  loop: "{{ mattermost_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\mattermost\tasks\configure.yml" @"
---
# roles/mattermost/tasks/configure.yml

- name: "Deploy Mattermost config.json"
  ansible.builtin.template:
    src: mattermost-config.json.j2
    dest: "{{ mattermost_install_dir }}/current/config/config.json"
    owner: "{{ mattermost_user }}"
    group: "{{ mattermost_group }}"
    mode: "0600"
  notify: restart mattermost

- name: "Ensure Mattermost service is enabled and started"
  ansible.builtin.systemd:
    name: mattermost
    enabled: true
    state: started

- name: "Wait for Mattermost API to respond"
  ansible.builtin.uri:
    url: "http://localhost:{{ mattermost_port }}/api/v4/system/ping"
    status_code: 200
  register: mm_ping
  retries: 12
  delay: 10
  until: mm_ping.status == 200
"@

Write-Role "$base\roles\mattermost\templates\mattermost.service.j2" @"
[Unit]
Description=Mattermost Team Messaging
After=network.target postgresql.service

[Service]
Type=notify
User={{ mattermost_user }}
Group={{ mattermost_group }}
ExecStart={{ mattermost_install_dir }}/current/bin/mattermost
WorkingDirectory={{ mattermost_install_dir }}/current
Restart=always
RestartSec=10
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
"@

# ── jitsi ─────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\jitsi\tasks\install.yml" @"
---
# roles/jitsi/tasks/install.yml

- name: "Add Jitsi apt signing key"
  ansible.builtin.get_url:
    url: "https://download.jitsi.org/jitsi-key.gpg.key"
    dest: /etc/apt/keyrings/jitsi.gpg
    mode: "0644"

- name: "Add Jitsi apt repository"
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/jitsi.gpg] https://download.jitsi.org stable/"
    filename: jitsi
    state: present
    update_cache: true

- name: "Pre-configure Jitsi hostname debconf"
  ansible.builtin.debconf:
    name: jitsi-meet
    question: jitsi-meet/jvb-hostname
    vtype: string
    value: "{{ jitsi_xmpp_domain }}"

- name: "Pre-configure Jitsi SSL type debconf"
  ansible.builtin.debconf:
    name: jitsi-meet
    question: jitsi-meet/cert-choice
    vtype: select
    value: "Generate a new self-signed certificate"

- name: "Install Jitsi Meet"
  ansible.builtin.apt:
    name:
      - jitsi-meet
      - jitsi-videobridge2
      - jicofo
      - prosody
      - coturn
    state: present
    install_recommends: false

- name: "Open Jitsi firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Jitsi"
  loop: "{{ jitsi_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\jitsi\tasks\configure.yml" @"
---
# roles/jitsi/tasks/configure.yml

- name: "Deploy Prosody configuration"
  ansible.builtin.template:
    src: prosody.cfg.lua.j2
    dest: "/etc/prosody/conf.d/{{ jitsi_xmpp_domain }}.cfg.lua"
    mode: "0644"
  notify: restart prosody

- name: "Deploy Jitsi Meet interface config"
  ansible.builtin.template:
    src: interface_config.js.j2
    dest: /etc/jitsi/meet/{{ jitsi_xmpp_domain }}-interface_config.js
    mode: "0644"

- name: "Deploy coturn configuration"
  ansible.builtin.template:
    src: coturn.conf.j2
    dest: /etc/turnserver.conf
    mode: "0644"

- name: "Enable and start Jitsi services"
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - prosody
    - jicofo
    - jitsi-videobridge2
"@

Write-Role "$base\roles\jitsi\templates\prosody.cfg.lua.j2" @"
-- templates/prosody.cfg.lua.j2
-- Jitsi Meet Prosody configuration

VirtualHost "{{ jitsi_xmpp_domain }}"
    authentication = "token"
    app_id = "{{ jitsi_oidc_client }}"
    app_secret = "{{ vault_jitsi_jwt_secret }}"
    modules_enabled = {
        "bosh";
        "pubsub";
        "ping";
        "speakerstats";
        "conference_duration";
    }
    c2s_require_encryption = false

Component "conference.{{ jitsi_xmpp_domain }}" "muc"
    storage = "memory"
    modules_enabled = {
        "muc_meeting_id";
        "muc_domain_mapper";
    }
    admins = { "focus@{{ jitsi_xmpp_auth_domain }}" }
    muc_room_allow_persistent = false

Component "jvb.{{ jitsi_xmpp_domain }}"
    component_secret = "{{ vault_jitsi_jvb_secret }}"

VirtualHost "{{ jitsi_xmpp_auth_domain }}"
    modules_enabled = { "limits_exception"; }
    authentication = "internal_hashed"
"@

# ── iredmail ──────────────────────────────────────────────────────────────────
Write-Role "$base\roles\iredmail\tasks\install.yml" @"
---
# roles/iredmail/tasks/install.yml

- name: "Set system hostname for iRedMail"
  ansible.builtin.hostname:
    name: "{{ iredmail_hostname }}"

- name: "Ensure /etc/hosts contains FQDN"
  ansible.builtin.lineinfile:
    path: /etc/hosts
    line: "{{ ansible_default_ipv4.address }} {{ iredmail_hostname }} {{ iredmail_hostname.split('.')[0] }}"
    state: present

- name: "Install iRedMail prerequisites"
  ansible.builtin.apt:
    name:
      - wget
      - ssl-cert
      - postfix
      - postfix-pgsql
      - dovecot-core
      - dovecot-imapd
      - dovecot-pop3d
      - dovecot-pgsql
      - dovecot-sieve
      - amavisd-new
      - spamassassin
      - clamav
      - clamav-daemon
      - unzip
    state: present
    update_cache: true

- name: "Create iRedMail install directory"
  ansible.builtin.file:
    path: "{{ iredmail_install_dir }}"
    state: directory
    mode: "0700"

- name: "Download iRedMail {{ iredmail_version }}"
  ansible.builtin.get_url:
    url: "https://github.com/iredmail/iRedMail/archive/refs/tags/{{ iredmail_version }}.tar.gz"
    dest: "/tmp/iredmail-{{ iredmail_version }}.tar.gz"
    mode: "0644"

- name: "Extract iRedMail"
  ansible.builtin.unarchive:
    src: "/tmp/iredmail-{{ iredmail_version }}.tar.gz"
    dest: "{{ iredmail_install_dir }}"
    remote_src: true

- name: "Open iRedMail firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "iRedMail"
  loop: "{{ iredmail_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\iredmail\tasks\configure.yml" @"
---
# roles/iredmail/tasks/configure.yml

- name: "Deploy Postfix main.cf"
  ansible.builtin.template:
    src: postfix-main.cf.j2
    dest: /etc/postfix/main.cf
    mode: "0644"
  notify: restart postfix

- name: "Deploy Postfix PostgreSQL lookup tables"
  ansible.builtin.template:
    src: "{{ item }}.j2"
    dest: "/etc/postfix/{{ item }}"
    mode: "0640"
    owner: root
    group: postfix
  loop:
    - pgsql-virtual-mailbox-domains.cf
    - pgsql-virtual-mailbox-users.cf
    - pgsql-virtual-alias-maps.cf
  notify: restart postfix

- name: "Deploy Dovecot configuration"
  ansible.builtin.template:
    src: dovecot.conf.j2
    dest: /etc/dovecot/dovecot.conf
    mode: "0644"
  notify: restart dovecot

- name: "Enable and start mail services"
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - postfix
    - dovecot
    - amavis
    - clamav-daemon

- name: "Update ClamAV virus database"
  ansible.builtin.command:
    cmd: freshclam
  register: freshclam_result
  failed_when: freshclam_result.rc != 0 and "locked" not in freshclam_result.stderr
  changed_when: freshclam_result.rc == 0
"@

Write-Role "$base\roles\iredmail\templates\postfix-main.cf.j2" @"
# templates/postfix-main.cf.j2

smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no

# TLS parameters
smtpd_use_tls = yes
smtpd_tls_cert_file = /etc/ssl/certs/it-stack.crt
smtpd_tls_key_file  = /etc/ssl/private/it-stack.key
smtpd_tls_security_level = may
smtp_tls_security_level = may
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database  = btree:\${data_directory}/smtp_scache

myhostname       = {{ iredmail_hostname }}
mydomain         = {{ iredmail_domain }}
myorigin         = \$mydomain
inet_interfaces  = all
inet_protocols   = ipv4

mydestination    = \$myhostname, localhost
relay_domains    =
mynetworks       = 127.0.0.0/8 {{ it_stack_network }}

virtual_mailbox_domains = pgsql:/etc/postfix/pgsql-virtual-mailbox-domains.cf
virtual_mailbox_maps    = pgsql:/etc/postfix/pgsql-virtual-mailbox-users.cf
virtual_alias_maps      = pgsql:/etc/postfix/pgsql-virtual-alias-maps.cf

virtual_transport       = dovecot
dovecot_destination_recipient_limit = 1

smtpd_sasl_auth_enable = yes
smtpd_sasl_type        = dovecot
smtpd_sasl_path        = private/auth

message_size_limit = {{ iredmail_max_message_size }}
mailbox_size_limit = 0
"@

# ── zammad ────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\zammad\tasks\install.yml" @"
---
# roles/zammad/tasks/install.yml

- name: "Install Zammad dependencies"
  ansible.builtin.apt:
    name:
      - curl
      - gnupg
      - apt-transport-https
    state: present

- name: "Add Zammad apt signing key"
  ansible.builtin.get_url:
    url: "https://dl.packager.io/srv/zammad/zammad/key"
    dest: /etc/apt/keyrings/zammad.gpg
    mode: "0644"

- name: "Add Zammad apt repository"
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/zammad.gpg] https://dl.packager.io/srv/deb/zammad/zammad/stable/ubuntu 24.04 main"
    filename: zammad
    state: present
    update_cache: true

- name: "Install Zammad {{ zammad_version }}"
  ansible.builtin.apt:
    name: "zammad={{ zammad_version }}-1"
    state: present
  environment:
    ZAMMAD_DB_ADAPTER: postgresql
    ZAMMAD_DB_HOST: "{{ zammad_db_host }}"
    ZAMMAD_DB_NAME: "{{ zammad_db_name }}"
    ZAMMAD_DB_USER: "{{ zammad_db_user }}"
    ZAMMAD_DB_PASS: "{{ vault_zammad_db_pass }}"
    ZAMMAD_ES_URL: "{{ zammad_elasticsearch_url }}"

- name: "Open Zammad firewall port"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Zammad"
  loop: "{{ zammad_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\zammad\tasks\configure.yml" @"
---
# roles/zammad/tasks/configure.yml

- name: "Configure Zammad FQDN"
  ansible.builtin.command:
    cmd: "zammad run rails r \"Setting.set('fqdn', '{{ zammad_fqdn }}')\""
  become: true
  become_user: "{{ zammad_user }}"
  changed_when: false

- name: "Configure Zammad HTTP type"
  ansible.builtin.command:
    cmd: "zammad run rails r \"Setting.set('http_type', '{{ zammad_http_type }}')\""
  become: true
  become_user: "{{ zammad_user }}"
  changed_when: false

- name: "Rebuild Zammad Elasticsearch index"
  ansible.builtin.command:
    cmd: "zammad run rails r \"SearchIndexBackend.create_index\""
  become: true
  become_user: "{{ zammad_user }}"
  changed_when: false

- name: "Ensure Zammad service is enabled and started"
  ansible.builtin.systemd:
    name: zammad
    enabled: true
    state: started

- name: "Wait for Zammad to respond on port {{ zammad_port }}"
  ansible.builtin.uri:
    url: "http://localhost:{{ zammad_port }}/"
    status_code: [200, 302]
  register: zammad_health
  retries: 18
  delay: 10
  until: zammad_health.status in [200, 302]
"@

# ── elasticsearch ─────────────────────────────────────────────────────────────
Write-Role "$base\roles\elasticsearch\tasks\install.yml" @"
---
# roles/elasticsearch/tasks/install.yml

- name: "Add Elasticsearch apt signing key"
  ansible.builtin.get_url:
    url: "https://artifacts.elastic.co/GPG-KEY-elasticsearch"
    dest: /etc/apt/keyrings/elasticsearch.gpg
    mode: "0644"

- name: "Add Elasticsearch {{ elasticsearch_version.split('.')[0] }}.x apt repository"
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/elasticsearch.gpg] https://artifacts.elastic.co/packages/{{ elasticsearch_version.split('.')[0] }}.x/apt stable main"
    filename: elasticsearch
    state: present
    update_cache: true

- name: "Install Elasticsearch {{ elasticsearch_version }}"
  ansible.builtin.apt:
    name: "elasticsearch={{ elasticsearch_version }}"
    state: present

- name: "Create Elasticsearch data and log directories"
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ elasticsearch_user }}"
    group: "{{ elasticsearch_group }}"
    mode: "0750"
  loop:
    - "{{ elasticsearch_data_dir }}"
    - "{{ elasticsearch_log_dir }}"

- name: "Pin Elasticsearch package version"
  ansible.builtin.copy:
    content: |
      Package: elasticsearch
      Pin: version {{ elasticsearch_version }}
      Pin-Priority: 1001
    dest: /etc/apt/preferences.d/elasticsearch
    mode: "0644"

- name: "Open Elasticsearch firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Elasticsearch"
  loop: "{{ elasticsearch_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\elasticsearch\tasks\configure.yml" @"
---
# roles/elasticsearch/tasks/configure.yml

- name: "Deploy elasticsearch.yml"
  ansible.builtin.template:
    src: elasticsearch.yml.j2
    dest: /etc/elasticsearch/elasticsearch.yml
    owner: root
    group: "{{ elasticsearch_group }}"
    mode: "0660"
  notify: restart elasticsearch

- name: "Configure JVM heap size"
  ansible.builtin.template:
    src: jvm.options.j2
    dest: /etc/elasticsearch/jvm.options.d/heap.options
    owner: root
    group: "{{ elasticsearch_group }}"
    mode: "0660"
  notify: restart elasticsearch

- name: "Enable and start Elasticsearch"
  ansible.builtin.systemd:
    name: elasticsearch
    enabled: true
    state: started

- name: "Wait for Elasticsearch to respond"
  ansible.builtin.uri:
    url: "http://localhost:{{ elasticsearch_http_port }}/_cluster/health"
    status_code: 200
  register: es_health
  retries: 12
  delay: 10
  until: es_health.status == 200
"@

Write-Role "$base\roles\elasticsearch\templates\elasticsearch.yml.j2" @"
# templates/elasticsearch.yml.j2

cluster.name: {{ elasticsearch_cluster_name }}
node.name:    {{ elasticsearch_node_name }}

path.data: {{ elasticsearch_data_dir }}
path.logs: {{ elasticsearch_log_dir }}

network.host: 0.0.0.0
http.port:    {{ elasticsearch_http_port }}
transport.port: {{ elasticsearch_transport_port }}

discovery.type: {{ elasticsearch_discovery_type }}

xpack.security.enabled: {{ elasticsearch_xpack_security | lower }}
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

# Bootstrap checks
bootstrap.memory_lock: true

# ILM
action.auto_create_index: ".monitoring-*,.watches,.triggered_watches,.watcher-history-*,.ml-*,+*"
"@

Write-Role "$base\roles\elasticsearch\templates\jvm.options.j2" @"
# templates/jvm.options.j2
-Xms{{ elasticsearch_heap_min }}
-Xmx{{ elasticsearch_heap_size }}
"@

Write-Output "phase2 + elasticsearch install/configure/templates done"