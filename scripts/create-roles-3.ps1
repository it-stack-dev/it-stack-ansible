param()
$base = "C:\IT-Stack\it-stack-dev\repos\meta\it-stack-ansible"

function Write-Role {
    param([string]$path, [string]$content)
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
}

# ── freepbx ───────────────────────────────────────────────────────────────────
Write-Role "$base\roles\freepbx\tasks\install.yml" @"
---
# roles/freepbx/tasks/install.yml

- name: "Install Asterisk and FreePBX dependencies"
  ansible.builtin.apt:
    name:
      - asterisk
      - asterisk-modules
      - asterisk-pjsip
      - mariadb-server
      - mariadb-client
      - apache2
      - php8.3
      - php8.3-cli
      - php8.3-mysql
      - php8.3-gd
      - php8.3-curl
      - php8.3-xml
      - php8.3-zip
      - php8.3-bcmath
      - php8.3-mbstring
      - nodejs
      - npm
      - sox
      - ffmpeg
      - lame
      - curl
      - wget
      - git
      - unixodbc
      - unixodbc-dev
    state: present
    update_cache: true

- name: "Create asterisk system user (if not exists)"
  ansible.builtin.user:
    name: "{{ freepbx_user }}"
    group: "{{ freepbx_group }}"
    shell: /usr/sbin/nologin
    system: true
    create_home: false
  ignore_errors: true

- name: "Download FreePBX {{ freepbx_version }} installer"
  ansible.builtin.get_url:
    url: "https://github.com/FreePBX/sng_freepbx_debian_install/raw/master/sng_freepbx_debian_install.sh"
    dest: /tmp/freepbx-install.sh
    mode: "0755"

- name: "Check if FreePBX is already installed"
  ansible.builtin.stat:
    path: /var/www/html/admin/bootstrap.php
  register: fpbx_installed

- name: "Run FreePBX installer (unattended)"
  ansible.builtin.command:
    cmd: "bash /tmp/freepbx-install.sh --nointeraction --testing"
    creates: /var/www/html/admin/bootstrap.php
  environment:
    ADMIN_PASSWORD: "{{ vault_freepbx_admin_pass }}"
  async: 600
  poll: 30

- name: "Open FreePBX firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "FreePBX"
  loop: "{{ freepbx_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\freepbx\tasks\configure.yml" @"
---
# roles/freepbx/tasks/configure.yml

- name: "Deploy Asterisk pjsip.conf"
  ansible.builtin.template:
    src: pjsip.conf.j2
    dest: /etc/asterisk/pjsip.conf
    owner: "{{ freepbx_user }}"
    group: "{{ freepbx_group }}"
    mode: "0640"
  notify: restart asterisk

- name: "Deploy Asterisk rtp.conf"
  ansible.builtin.template:
    src: rtp.conf.j2
    dest: /etc/asterisk/rtp.conf
    owner: "{{ freepbx_user }}"
    group: "{{ freepbx_group }}"
    mode: "0640"
  notify: restart asterisk

- name: "Configure FreePBX timezone"
  ansible.builtin.command:
    cmd: "fwconsole setting TIMEZONE {{ freepbx_timezone }}"
  changed_when: false

- name: "Enable Apache mod_rewrite"
  community.general.apache2_module:
    name: rewrite
    state: present
  notify: restart apache2

- name: "Ensure Asterisk is enabled and started"
  ansible.builtin.systemd:
    name: asterisk
    enabled: true
    state: started
"@

Write-Role "$base\roles\freepbx\templates\pjsip.conf.j2" @"
; templates/pjsip.conf.j2

[global]
type=global
user_agent=IT-Stack PBX

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:{{ freepbx_sip_port }}

[transport-tcp]
type=transport
protocol=tcp
bind=0.0.0.0:{{ freepbx_sip_port }}

[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:{{ freepbx_sips_port }}
cert_file=/etc/ssl/certs/it-stack.crt
priv_key_file=/etc/ssl/private/it-stack.key
method=tlsv1_2
"@

# ── suitecrm ──────────────────────────────────────────────────────────────────
Write-Role "$base\roles\suitecrm\tasks\install.yml" @"
---
# roles/suitecrm/tasks/install.yml

- name: "Install PHP 8.3 and required extensions for SuiteCRM"
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
      - php8.3-imap
      - php8.3-soap
      - php8.3-redis
      - php8.3-opcache
      - nginx
      - unzip
    state: present
    update_cache: true

- name: "Create SuiteCRM install directory"
  ansible.builtin.file:
    path: "{{ suitecrm_install_dir }}"
    state: directory
    owner: "{{ suitecrm_user }}"
    group: "{{ suitecrm_group }}"
    mode: "0750"

- name: "Check if SuiteCRM is installed"
  ansible.builtin.stat:
    path: "{{ suitecrm_install_dir }}/index.php"
  register: scrm_installed

- name: "Download SuiteCRM {{ suitecrm_version }}"
  ansible.builtin.get_url:
    url: "https://suitecrm.com/download/128/suite82/{{ suitecrm_version }}/SuiteCRM-{{ suitecrm_version }}.zip"
    dest: "/tmp/suitecrm-{{ suitecrm_version }}.zip"
    mode: "0644"
  when: not scrm_installed.stat.exists

- name: "Extract SuiteCRM archive"
  ansible.builtin.unarchive:
    src: "/tmp/suitecrm-{{ suitecrm_version }}.zip"
    dest: "{{ suitecrm_install_dir }}"
    remote_src: true
    owner: "{{ suitecrm_user }}"
    group: "{{ suitecrm_group }}"
    extra_opts: [--strip-components=1]
  when: not scrm_installed.stat.exists

- name: "Set SuiteCRM directory permissions"
  ansible.builtin.file:
    path: "{{ suitecrm_install_dir }}"
    owner: "{{ suitecrm_user }}"
    group: "{{ suitecrm_group }}"
    recurse: true
    mode: "0755"

- name: "Open SuiteCRM firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "SuiteCRM"
  loop: "{{ suitecrm_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\suitecrm\tasks\configure.yml" @"
---
# roles/suitecrm/tasks/configure.yml

- name: "Deploy Nginx vhost for SuiteCRM"
  ansible.builtin.template:
    src: suitecrm-nginx.conf.j2
    dest: /etc/nginx/sites-available/suitecrm
    mode: "0644"
  notify: restart nginx

- name: "Enable SuiteCRM Nginx site"
  ansible.builtin.file:
    src: /etc/nginx/sites-available/suitecrm
    dest: /etc/nginx/sites-enabled/suitecrm
    state: link
  notify: restart nginx

- name: "Deploy SuiteCRM config_override.php"
  ansible.builtin.template:
    src: suitecrm-config_override.php.j2
    dest: "{{ suitecrm_install_dir }}/config_override.php"
    owner: "{{ suitecrm_user }}"
    group: "{{ suitecrm_group }}"
    mode: "0600"

- name: "Set up SuiteCRM cron job"
  ansible.builtin.cron:
    name: "SuiteCRM cron"
    minute: "*/{{ suitecrm_cron_interval }}"
    user: "{{ suitecrm_user }}"
    job: "php -f {{ suitecrm_install_dir }}/cron.php > /dev/null 2>&1"
"@

Write-Role "$base\roles\suitecrm\templates\suitecrm-nginx.conf.j2" @"
# templates/suitecrm-nginx.conf.j2

server {
    listen 80;
    server_name {{ suitecrm_hostname }};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name {{ suitecrm_hostname }};

    ssl_certificate     /etc/ssl/certs/it-stack.crt;
    ssl_certificate_key /etc/ssl/private/it-stack.key;

    root   {{ suitecrm_install_dir }};
    index  index.php;

    client_max_body_size {{ suitecrm_php_upload_max }};

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include        fastcgi_params;
        fastcgi_pass   unix:/run/php/php8.3-fpm-suitecrm.sock;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
    }

    location ~ /\. { deny all; }
    location ~* \.(log|sql)\$ { deny all; }
}
"@

# ── odoo ──────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\odoo\tasks\install.yml" @"
---
# roles/odoo/tasks/install.yml

- name: "Add Odoo apt signing key"
  ansible.builtin.get_url:
    url: "https://nightly.odoo.com/odoo.key"
    dest: /etc/apt/keyrings/odoo.gpg
    mode: "0644"

- name: "Add Odoo {{ odoo_version }} apt repository"
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/odoo.gpg] https://nightly.odoo.com/{{ odoo_version }}/nightly/deb/ ./"
    filename: odoo
    state: present
    update_cache: true

- name: "Install Odoo {{ odoo_version }}"
  ansible.builtin.apt:
    name: odoo
    state: present

- name: "Create Odoo log directory"
  ansible.builtin.file:
    path: "{{ odoo_log_dir }}"
    state: directory
    owner: "{{ odoo_user }}"
    group: "{{ odoo_group }}"
    mode: "0750"

- name: "Open Odoo firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Odoo"
  loop: "{{ odoo_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\odoo\tasks\configure.yml" @"
---
# roles/odoo/tasks/configure.yml

- name: "Deploy Odoo configuration file"
  ansible.builtin.template:
    src: odoo.conf.j2
    dest: /etc/odoo/odoo.conf
    owner: "{{ odoo_user }}"
    group: "{{ odoo_group }}"
    mode: "0640"
  notify: restart odoo

- name: "Enable and start Odoo"
  ansible.builtin.systemd:
    name: odoo
    enabled: true
    state: started

- name: "Wait for Odoo web interface"
  ansible.builtin.uri:
    url: "http://localhost:{{ odoo_http_port }}/web/health"
    status_code: 200
  register: odoo_health
  retries: 12
  delay: 10
  until: odoo_health.status == 200
"@

Write-Role "$base\roles\odoo\templates\odoo.conf.j2" @"
[options]
; templates/odoo.conf.j2

admin_passwd = {{ vault_odoo_admin_pass }}

db_host    = {{ odoo_db_host }}
db_port    = {{ odoo_db_port }}
db_user    = {{ odoo_db_user }}
db_password = {{ vault_odoo_db_pass }}
db_name    = {{ odoo_db_name }}
db_filter  = {{ odoo_db_filter }}

http_interface = 0.0.0.0
http_port      = {{ odoo_http_port }}
gevent_port    = {{ odoo_gevent_port }}
longpolling_port = {{ odoo_gevent_port }}

workers           = {{ odoo_workers }}
max_cron_threads  = {{ odoo_max_cron_threads }}
limit_memory_hard = {{ odoo_limit_memory_hard }}
limit_memory_soft = {{ odoo_limit_memory_soft }}
limit_time_cpu    = {{ odoo_limit_time_cpu }}
limit_time_real   = {{ odoo_limit_time_real }}

logfile = {{ odoo_log_dir }}/odoo.log
log_level = info

smtp_server   = {{ odoo_smtp_host }}
smtp_port     = {{ odoo_smtp_port }}
smtp_from     = {{ odoo_smtp_from }}
"@

# ── openkm ────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\openkm\tasks\install.yml" @"
---
# roles/openkm/tasks/install.yml

- name: "Install Java 17 JRE"
  ansible.builtin.apt:
    name: openjdk-17-jre-headless
    state: present

- name: "Create OpenKM system group"
  ansible.builtin.group:
    name: "{{ openkm_group }}"
    state: present
    system: true

- name: "Create OpenKM system user"
  ansible.builtin.user:
    name: "{{ openkm_user }}"
    group: "{{ openkm_group }}"
    home: "{{ openkm_install_dir }}"
    shell: /usr/sbin/nologin
    system: true
    create_home: false

- name: "Create OpenKM directories"
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ openkm_user }}"
    group: "{{ openkm_group }}"
    mode: "0750"
  loop:
    - "{{ openkm_install_dir }}"
    - "{{ openkm_data_dir }}"
    - "{{ openkm_log_dir }}"

- name: "Check if OpenKM WAR is deployed"
  ansible.builtin.stat:
    path: "{{ openkm_install_dir }}/openkm.war"
  register: okm_war

- name: "Download OpenKM Community {{ openkm_version }}"
  ansible.builtin.get_url:
    url: "https://github.com/openkm/document-management-system/releases/download/{{ openkm_version }}/openkm-ce-{{ openkm_version }}.war"
    dest: "{{ openkm_install_dir }}/openkm.war"
    owner: "{{ openkm_user }}"
    group: "{{ openkm_group }}"
    mode: "0640"
  when: not okm_war.stat.exists

- name: "Deploy OpenKM systemd service"
  ansible.builtin.template:
    src: openkm.service.j2
    dest: /etc/systemd/system/openkm.service
    mode: "0644"
  notify: [reload systemd, restart openkm]

- name: "Open OpenKM firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "OpenKM"
  loop: "{{ openkm_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\openkm\tasks\configure.yml" @"
---
# roles/openkm/tasks/configure.yml

- name: "Deploy OpenKM datasource configuration"
  ansible.builtin.template:
    src: openkm-datasource.xml.j2
    dest: "{{ openkm_install_dir }}/conf/database.xml"
    owner: "{{ openkm_user }}"
    group: "{{ openkm_group }}"
    mode: "0640"
  notify: restart openkm

- name: "Enable and start OpenKM"
  ansible.builtin.systemd:
    name: openkm
    enabled: true
    state: started

- name: "Wait for OpenKM application server"
  ansible.builtin.uri:
    url: "http://localhost:{{ openkm_http_port }}/OpenKM"
    status_code: [200, 302]
  register: okm_health
  retries: 18
  delay: 15
  until: okm_health.status in [200, 302]
"@

Write-Role "$base\roles\openkm\templates\openkm.service.j2" @"
[Unit]
Description=OpenKM Document Management System
After=network.target postgresql.service elasticsearch.service

[Service]
Type=simple
User={{ openkm_user }}
Group={{ openkm_group }}
ExecStart=/usr/bin/java {{ openkm_java_opts }} -jar {{ openkm_install_dir }}/openkm.war
WorkingDirectory={{ openkm_install_dir }}
StandardOutput=append:{{ openkm_log_dir }}/openkm.log
StandardError=append:{{ openkm_log_dir }}/openkm.err
Restart=on-failure
RestartSec=15

[Install]
WantedBy=multi-user.target
"@

# ── taiga ──────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\taiga\tasks\install.yml" @"
---
# roles/taiga/tasks/install.yml

- name: "Add deadsnakes Python 3.12 PPA"
  ansible.builtin.apt_repository:
    repo: "ppa:deadsnakes/ppa"
    state: present
    update_cache: true

- name: "Install Python 3.12 and build dependencies"
  ansible.builtin.apt:
    name:
      - python3.12
      - python3.12-venv
      - python3.12-dev
      - python3-pip
      - build-essential
      - libpq-dev
      - libxml2-dev
      - libxslt1-dev
      - libffi-dev
      - libjpeg-dev
      - nginx
      - git
    state: present

- name: "Create Taiga system group"
  ansible.builtin.group:
    name: "{{ taiga_group }}"
    state: present
    system: true

- name: "Create Taiga system user"
  ansible.builtin.user:
    name: "{{ taiga_user }}"
    group: "{{ taiga_group }}"
    home: "{{ taiga_install_dir }}"
    shell: /usr/sbin/nologin
    system: true

- name: "Create Taiga directories"
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ taiga_user }}"
    group: "{{ taiga_group }}"
    mode: "0750"
  loop:
    - "{{ taiga_install_dir }}"
    - "{{ taiga_install_dir }}/back"
    - "{{ taiga_install_dir }}/front"
    - "{{ taiga_install_dir }}/media"
    - "{{ taiga_install_dir }}/static"
    - "{{ taiga_log_dir }}"

- name: "Clone taiga-back"
  ansible.builtin.git:
    repo: "https://github.com/taigaio/taiga-back.git"
    dest: "{{ taiga_install_dir }}/back"
    version: "{{ taiga_version }}"
    force: false
  become: true
  become_user: "{{ taiga_user }}"

- name: "Create Python virtualenv and install taiga-back requirements"
  ansible.builtin.pip:
    requirements: "{{ taiga_install_dir }}/back/requirements.txt"
    virtualenv: "{{ taiga_install_dir }}/venv"
    virtualenv_python: python3.12
  become: true
  become_user: "{{ taiga_user }}"

- name: "Download taiga-front-dist"
  ansible.builtin.get_url:
    url: "https://github.com/taigaio/taiga-front-dist/archive/refs/tags/{{ taiga_version }}-stable.tar.gz"
    dest: "/tmp/taiga-front-{{ taiga_version }}.tar.gz"
    mode: "0644"

- name: "Extract taiga-front-dist"
  ansible.builtin.unarchive:
    src: "/tmp/taiga-front-{{ taiga_version }}.tar.gz"
    dest: "{{ taiga_install_dir }}/front"
    remote_src: true
    owner: "{{ taiga_user }}"
    group: "{{ taiga_group }}"
    extra_opts: [--strip-components=1]

- name: "Deploy Taiga backend systemd service"
  ansible.builtin.template:
    src: taiga-backend.service.j2
    dest: /etc/systemd/system/taiga-backend.service
    mode: "0644"
  notify: reload systemd

- name: "Deploy Taiga async worker systemd service"
  ansible.builtin.template:
    src: taiga-async.service.j2
    dest: /etc/systemd/system/taiga-async.service
    mode: "0644"
  notify: reload systemd

- name: "Open Taiga firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Taiga"
  loop: "{{ taiga_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\taiga\tasks\configure.yml" @"
---
# roles/taiga/tasks/configure.yml

- name: "Deploy Taiga backend config"
  ansible.builtin.template:
    src: taiga-settings-production.py.j2
    dest: "{{ taiga_install_dir }}/back/settings/production.py"
    owner: "{{ taiga_user }}"
    group: "{{ taiga_group }}"
    mode: "0640"
  notify: restart taiga-backend

- name: "Run Taiga database migrations"
  ansible.builtin.command:
    cmd: "{{ taiga_install_dir }}/venv/bin/python manage.py migrate --noinput"
    chdir: "{{ taiga_install_dir }}/back"
  environment:
    DJANGO_SETTINGS_MODULE: settings.production
  become: true
  become_user: "{{ taiga_user }}"
  changed_when: false

- name: "Collect static files"
  ansible.builtin.command:
    cmd: "{{ taiga_install_dir }}/venv/bin/python manage.py collectstatic --noinput"
    chdir: "{{ taiga_install_dir }}/back"
  environment:
    DJANGO_SETTINGS_MODULE: settings.production
  become: true
  become_user: "{{ taiga_user }}"
  changed_when: false

- name: "Deploy Nginx vhost for Taiga"
  ansible.builtin.template:
    src: taiga-nginx.conf.j2
    dest: /etc/nginx/sites-available/taiga
    mode: "0644"
  notify: restart nginx

- name: "Enable Taiga Nginx site"
  ansible.builtin.file:
    src: /etc/nginx/sites-available/taiga
    dest: /etc/nginx/sites-enabled/taiga
    state: link
  notify: restart nginx

- name: "Enable and start Taiga services"
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - taiga-backend
    - taiga-async
"@

Write-Role "$base\roles\taiga\templates\taiga-backend.service.j2" @"
[Unit]
Description=Taiga Backend (Django Gunicorn)
After=network.target postgresql.service redis.service

[Service]
Type=simple
User={{ taiga_user }}
Group={{ taiga_group }}
WorkingDirectory={{ taiga_install_dir }}/back
ExecStart={{ taiga_install_dir }}/venv/bin/gunicorn \
    --workers {{ taiga_django_workers }} \
    --bind 127.0.0.1:{{ taiga_backend_port }} \
    --log-file {{ taiga_log_dir }}/gunicorn.log \
    taiga.wsgi:application
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"@

# ── snipeit ───────────────────────────────────────────────────────────────────
Write-Role "$base\roles\snipeit\tasks\install.yml" @"
---
# roles/snipeit/tasks/install.yml

- name: "Install PHP 8.3 and Snipe-IT dependencies"
  ansible.builtin.apt:
    name:
      - php8.3
      - php8.3-fpm
      - php8.3-curl
      - php8.3-mysql
      - php8.3-gd
      - php8.3-ldap
      - php8.3-zip
      - php8.3-bcmath
      - php8.3-mbstring
      - php8.3-xml
      - php8.3-tokenizer
      - php8.3-redis
      - php8.3-opcache
      - nginx
      - git
      - unzip
      - mariadb-server   # local MariaDB for Snipe-IT
    state: present

- name: "Install Composer"
  ansible.builtin.get_url:
    url: "https://getcomposer.org/installer"
    dest: /tmp/composer-setup.php
    mode: "0644"

- name: "Run Composer installer"
  ansible.builtin.command:
    cmd: "php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer"
    creates: /usr/local/bin/composer

- name: "Create Snipe-IT install directory"
  ansible.builtin.file:
    path: "{{ snipeit_install_dir }}"
    state: directory
    owner: "{{ snipeit_user }}"
    group: "{{ snipeit_group }}"
    mode: "0750"

- name: "Clone Snipe-IT v{{ snipeit_version }}"
  ansible.builtin.git:
    repo: "https://github.com/snipe/snipe-it.git"
    dest: "{{ snipeit_install_dir }}"
    version: "v{{ snipeit_version }}"
  become: true
  become_user: "{{ snipeit_user }}"

- name: "Run Composer install"
  community.general.composer:
    command: install
    working_dir: "{{ snipeit_install_dir }}"
    no_dev: true
    optimize_autoloader: true
  become: true
  become_user: "{{ snipeit_user }}"

- name: "Open Snipe-IT firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Snipe-IT"
  loop: "{{ snipeit_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\snipeit\tasks\configure.yml" @"
---
# roles/snipeit/tasks/configure.yml

- name: "Deploy Snipe-IT .env file"
  ansible.builtin.template:
    src: snipeit-env.j2
    dest: "{{ snipeit_install_dir }}/.env"
    owner: "{{ snipeit_user }}"
    group: "{{ snipeit_group }}"
    mode: "0600"
  notify: restart php8.3-fpm

- name: "Generate Snipe-IT application key"
  ansible.builtin.command:
    cmd: "php artisan key:generate --force"
    chdir: "{{ snipeit_install_dir }}"
  become: true
  become_user: "{{ snipeit_user }}"
  changed_when: false

- name: "Run Snipe-IT database migrations"
  ansible.builtin.command:
    cmd: "php artisan migrate --force"
    chdir: "{{ snipeit_install_dir }}"
  become: true
  become_user: "{{ snipeit_user }}"
  changed_when: false

- name: "Deploy Nginx vhost for Snipe-IT"
  ansible.builtin.template:
    src: snipeit-nginx.conf.j2
    dest: /etc/nginx/sites-available/snipeit
    mode: "0644"
  notify: restart nginx

- name: "Enable Snipe-IT Nginx site"
  ansible.builtin.file:
    src: /etc/nginx/sites-available/snipeit
    dest: /etc/nginx/sites-enabled/snipeit
    state: link
  notify: restart nginx
"@

Write-Role "$base\roles\snipeit\templates\snipeit-env.j2" @"
APP_NAME="{{ snipeit_app_name }}"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://{{ snipeit_hostname }}

DB_CONNECTION=mysql
DB_HOST={{ snipeit_db_host }}
DB_PORT={{ snipeit_db_port }}
DB_DATABASE={{ snipeit_db_name }}
DB_USERNAME={{ snipeit_db_user }}
DB_PASSWORD={{ vault_snipeit_db_pass }}

SESSION_DRIVER={{ 'redis' if snipeit_redis_host is defined else 'file' }}
CACHE_DRIVER={{ 'redis' if snipeit_redis_host is defined else 'file' }}
QUEUE_CONNECTION={{ 'redis' if snipeit_redis_host is defined else 'sync' }}

REDIS_HOST={{ snipeit_redis_host }}
REDIS_PORT={{ snipeit_redis_port }}

MAIL_MAILER=smtp
MAIL_HOST={{ snipeit_smtp_host }}
MAIL_PORT={{ snipeit_smtp_port }}
MAIL_FROM_ADDRESS={{ snipeit_smtp_from }}

SAML2_{{ snipeit_saml_client | upper }}_METADATA={{ snipeit_keycloak_url }}/realms/{{ snipeit_keycloak_realm }}/protocol/saml/descriptor
"@

# ── glpi ───────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\glpi\tasks\install.yml" @"
---
# roles/glpi/tasks/install.yml

- name: "Install PHP 8.3 and GLPI dependencies"
  ansible.builtin.apt:
    name:
      - php8.3
      - php8.3-fpm
      - php8.3-curl
      - php8.3-gd
      - php8.3-intl
      - php8.3-ldap
      - php8.3-mbstring
      - php8.3-mysql
      - php8.3-xml
      - php8.3-zip
      - php8.3-bz2
      - php8.3-opcache
      - nginx
      - mariadb-server   # local MariaDB for GLPI
      - unzip
    state: present

- name: "Create GLPI install directory"
  ansible.builtin.file:
    path: "{{ glpi_install_dir }}"
    state: directory
    owner: "{{ glpi_user }}"
    group: "{{ glpi_group }}"
    mode: "0750"

- name: "Check if GLPI is installed"
  ansible.builtin.stat:
    path: "{{ glpi_install_dir }}/index.php"
  register: glpi_installed

- name: "Download GLPI {{ glpi_version }}"
  ansible.builtin.get_url:
    url: "https://github.com/glpi-project/glpi/releases/download/{{ glpi_version }}/glpi-{{ glpi_version }}.tgz"
    dest: "/tmp/glpi-{{ glpi_version }}.tgz"
    mode: "0644"
  when: not glpi_installed.stat.exists

- name: "Extract GLPI archive"
  ansible.builtin.unarchive:
    src: "/tmp/glpi-{{ glpi_version }}.tgz"
    dest: /var/www
    remote_src: true
    owner: "{{ glpi_user }}"
    group: "{{ glpi_group }}"
  when: not glpi_installed.stat.exists

- name: "Rename extracted directory"
  ansible.builtin.command:
    cmd: "mv /var/www/glpi /var/www/glpi-app"
    removes: /var/www/glpi
  when: not glpi_installed.stat.exists

- name: "Set GLPI permissions"
  ansible.builtin.file:
    path: "{{ glpi_install_dir }}"
    owner: "{{ glpi_user }}"
    group: "{{ glpi_group }}"
    recurse: true

- name: "Open GLPI firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "GLPI"
  loop: "{{ glpi_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\glpi\tasks\configure.yml" @"
---
# roles/glpi/tasks/configure.yml

- name: "Deploy Nginx vhost for GLPI"
  ansible.builtin.template:
    src: glpi-nginx.conf.j2
    dest: /etc/nginx/sites-available/glpi
    mode: "0644"
  notify: restart nginx

- name: "Enable GLPI Nginx site"
  ansible.builtin.file:
    src: /etc/nginx/sites-available/glpi
    dest: /etc/nginx/sites-enabled/glpi
    state: link
  notify: restart nginx

- name: "Set up GLPI cron job"
  ansible.builtin.cron:
    name: "GLPI cron"
    minute: "*"
    user: "{{ glpi_user }}"
    job: "php {{ glpi_install_dir }}/front/cron.php &>/dev/null"

- name: "Deploy GLPI downstream config"
  ansible.builtin.template:
    src: glpi-downstream.php.j2
    dest: "{{ glpi_install_dir }}/inc/downstream.php"
    owner: "{{ glpi_user }}"
    group: "{{ glpi_group }}"
    mode: "0640"
"@

Write-Role "$base\roles\glpi\templates\glpi-nginx.conf.j2" @"
# templates/glpi-nginx.conf.j2

server {
    listen 80;
    server_name {{ glpi_hostname }};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name {{ glpi_hostname }};

    ssl_certificate     /etc/ssl/certs/it-stack.crt;
    ssl_certificate_key /etc/ssl/private/it-stack.key;

    root   {{ glpi_install_dir }};
    index  index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include        fastcgi_params;
        fastcgi_pass   unix:/run/php/php8.3-fpm-glpi.sock;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 120;
    }

    location ~ ^/(config|files|scripts|vendor)/ { deny all; }
}
"@

# ── zabbix ────────────────────────────────────────────────────────────────────
Write-Role "$base\roles\zabbix\tasks\install.yml" @"
---
# roles/zabbix/tasks/install.yml

- name: "Download Zabbix {{ zabbix_version }} apt repository package"
  ansible.builtin.get_url:
    url: "https://repo.zabbix.com/zabbix/{{ zabbix_version }}/ubuntu/pool/main/z/zabbix-release/zabbix-release_{{ zabbix_version }}-2+ubuntu24.04_all.deb"
    dest: "/tmp/zabbix-release.deb"
    mode: "0644"

- name: "Install Zabbix apt repository"
  ansible.builtin.apt:
    deb: /tmp/zabbix-release.deb
    state: present

- name: "Update apt cache after adding Zabbix repo"
  ansible.builtin.apt:
    update_cache: true

- name: "Install Zabbix server, frontend, agent"
  ansible.builtin.apt:
    name:
      - zabbix-server-pgsql
      - zabbix-frontend-php
      - zabbix-nginx-conf
      - zabbix-agent2
      - zabbix-sql-scripts
      - php8.3-pgsql
    state: present

- name: "Create Zabbix log directory"
  ansible.builtin.file:
    path: "{{ zabbix_log_dir }}"
    state: directory
    owner: "{{ zabbix_user }}"
    group: "{{ zabbix_group }}"
    mode: "0750"

- name: "Open Zabbix firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Zabbix"
  loop: "{{ zabbix_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\zabbix\tasks\configure.yml" @"
---
# roles/zabbix/tasks/configure.yml

- name: "Deploy zabbix_server.conf"
  ansible.builtin.template:
    src: zabbix_server.conf.j2
    dest: /etc/zabbix/zabbix_server.conf
    owner: root
    group: "{{ zabbix_group }}"
    mode: "0640"
  notify: restart zabbix-server

- name: "Import Zabbix initial schema (once)"
  ansible.builtin.shell:
    cmd: >
      zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz
      | psql -h {{ zabbix_db_host }} -U {{ zabbix_db_user }} {{ zabbix_db_name }}
    creates: /var/lib/zabbix/.schema_imported
  environment:
    PGPASSWORD: "{{ vault_zabbix_db_pass }}"
  register: schema_import

- name: "Mark schema as imported"
  ansible.builtin.file:
    path: /var/lib/zabbix/.schema_imported
    state: touch
    mode: "0644"
  when: schema_import.changed

- name: "Configure Zabbix Nginx vhost"
  ansible.builtin.template:
    src: zabbix-nginx.conf.j2
    dest: /etc/nginx/conf.d/zabbix.conf
    mode: "0644"
  notify: restart nginx

- name: "Enable and start Zabbix services"
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - zabbix-server
    - zabbix-agent2
    - nginx
"@

Write-Role "$base\roles\zabbix\templates\zabbix_server.conf.j2" @"
# templates/zabbix_server.conf.j2

LogFile={{ zabbix_log_dir }}/zabbix_server.log
LogFileSize=0
PidFile=/run/zabbix/zabbix_server.pid

DBHost={{ zabbix_db_host }}
DBName={{ zabbix_db_name }}
DBUser={{ zabbix_db_user }}
DBPassword={{ vault_zabbix_db_pass }}
DBPort={{ zabbix_db_port }}

ListenPort={{ zabbix_server_port }}

StartPollers=5
StartIPMIPollers=0
StartPollersUnreachable=1
StartTrappers=5
StartPingers=1
StartDiscoverers=1
StartHTTPPollers=1
StartAlertHandlers=3

CacheSize=128M
HistoryCacheSize=64M
HistoryIndexCacheSize=16M
TrendCacheSize=32M
ValueCacheSize=0

Timeout=4
TrapperTimeout=300
UnreachablePeriod=45
UnavailableDelay=60
UnreachableDelay=15

AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts

LogSlowQueries=3000
SocketDir=/run/zabbix
"@

# ── graylog ───────────────────────────────────────────────────────────────────
Write-Role "$base\roles\graylog\tasks\install.yml" @"
---
# roles/graylog/tasks/install.yml

- name: "Install MongoDB prerequisites"
  ansible.builtin.apt:
    name:
      - gnupg
      - wget
      - curl
    state: present

- name: "Add MongoDB apt signing key"
  ansible.builtin.get_url:
    url: "https://pgp.mongodb.com/server-7.0.asc"
    dest: /etc/apt/keyrings/mongodb.gpg
    mode: "0644"

- name: "Add MongoDB 7.0 apt repository"
  ansible.builtin.apt_repository:
    repo: "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse"
    filename: mongodb-org-7.0
    state: present
    update_cache: true

- name: "Install MongoDB"
  ansible.builtin.apt:
    name: mongodb-org
    state: present

- name: "Enable and start MongoDB"
  ansible.builtin.systemd:
    name: mongod
    enabled: true
    state: started

- name: "Add Graylog apt signing key"
  ansible.builtin.get_url:
    url: "https://downloads.graylog.org/repo/packages/graylog-6.0-repository_latest.deb"
    dest: /tmp/graylog-repo.deb
    mode: "0644"

- name: "Install Graylog apt repository"
  ansible.builtin.apt:
    deb: /tmp/graylog-repo.deb
    state: present

- name: "Update apt cache after adding Graylog repo"
  ansible.builtin.apt:
    update_cache: true

- name: "Install Graylog server"
  ansible.builtin.apt:
    name: graylog-server
    state: present

- name: "Open Graylog firewall ports"
  community.general.ufw:
    rule: allow
    port: "{{ item.port | string }}"
    proto: "{{ item.proto }}"
    src: "{{ item.from }}"
    comment: "Graylog"
  loop: "{{ graylog_firewall_ports }}"
  tags: [firewall]
"@

Write-Role "$base\roles\graylog\tasks\configure.yml" @"
---
# roles/graylog/tasks/configure.yml

- name: "Generate Graylog password secret"
  ansible.builtin.command:
    cmd: "pwgen -N 1 -s 96"
  register: graylog_password_secret
  changed_when: false

- name: "Generate Graylog SHA256 admin password"
  ansible.builtin.command:
    cmd: "sh -c 'echo -n {{ vault_graylog_admin_pass }} | sha256sum | cut -d\" \" -f1'"
  register: graylog_admin_sha256
  changed_when: false

- name: "Deploy Graylog server.conf"
  ansible.builtin.template:
    src: graylog-server.conf.j2
    dest: /etc/graylog/server/server.conf
    owner: "{{ graylog_user }}"
    group: "{{ graylog_group }}"
    mode: "0640"
  notify: restart graylog-server

- name: "Enable and start Graylog"
  ansible.builtin.systemd:
    name: graylog-server
    enabled: true
    state: started

- name: "Wait for Graylog web API"
  ansible.builtin.uri:
    url: "http://localhost:{{ graylog_http_port }}/api"
    status_code: 200
  register: graylog_api
  retries: 18
  delay: 10
  until: graylog_api.status == 200
"@

Write-Role "$base\roles\graylog\templates\graylog-server.conf.j2" @"
# templates/graylog-server.conf.j2

is_master = true
node_id_file = /var/lib/graylog-server/node-id

password_secret = {{ vault_graylog_password_secret }}
root_password_sha2 = {{ vault_graylog_admin_sha256 }}
root_username = admin

http_bind_address = 0.0.0.0:{{ graylog_http_port }}
http_external_uri = https://{{ graylog_hostname }}/

elasticsearch_hosts = {{ graylog_elasticsearch_hosts }}
mongodb_uri = {{ graylog_mongodb_uri }}

message_journal_max_size = {{ graylog_message_journal_max_size }}

# Zabbix integration (log-based alerts via script)
# alert_receivers.0 = zabbix:{{ graylog_zabbix_api_url }}
"@

Write-Output "ALL PHASE 3+4 ROLES INSTALL/CONFIGURE/TEMPLATES DONE"