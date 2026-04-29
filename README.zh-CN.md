# Docker LNMP（本地 PHP 开发环境）

适用于 PHP 项目的本地开发栈：

- Nginx（TLS 反向代理）
- PHP-FPM（默认 8.4，可选 8.5 和 7.4）
- MySQL
- Redis
- Mailpit（SMTP + 收件箱界面，通过 Nginx 访问）
- Ofelia（容器定时任务）
- Certbot（DNS-01 方式申请 SSL，支持 117+ 提供商）

## 快速开始

```bash
# 1. 复制并编辑环境变量文件
cp .env.sample .env
# 编辑 .env — 设置 WEB_ROOT、MYSQL_* 等凭据

# 2. 创建 Nginx 站点
make site-new NAME=my-site.conf
# 编辑 nginx/sites-available/my-site.conf
make site-enable NAME=my-site.conf

# 3. 添加 SSL 证书（手动或通过 certbot）
mkdir -p nginx/certs
# 将 *.crt 和 *.key 文件放入 nginx/certs/

# 4. 启动
make up
```

运行 `make help` 查看所有可用命令。

## 项目结构

```
.
├── compose.yml                  # 核心 LNMP 服务 + certbot
├── compose.observability.yml    # 可观测性栈（可选）
├── compose.php74.yml            # PHP 7.4 扩展
├── compose.php85.yml            # PHP 8.5 扩展
├── Makefile                     # 快捷命令
├── .env.sample                  # 环境变量模板
├── config.ini.example           # Ofelia 定时任务配置模板
│
├── certbot/                     # SSL 证书管理
│   ├── credentials/             # DNS 提供商凭据文件
│   ├── conf/                    # Let's Encrypt 状态（已 gitignore）
│
├── nginx/
│   ├── nginx.conf
│   ├── certs/                   # SSL 证书（已 gitignore）
│   ├── sites-available/         # 站点配置（已 gitignore）
│   ├── sites-enabled/           # 已启用站点（符号链接，已 gitignore）
│   └── snippets/                # 可复用配置片段
│
├── php-fpm/
│   ├── Dockerfile
│   └── conf/                    # PHP 配置（php.ini 等）
│
├── loki/                        # Loki 配置（可观测性）
├── alloy/                       # Alloy 配置（可观测性）
├── grafana/                     # Grafana 看板 + 数据源配置
├── prometheus/                  # Prometheus 配置
│
└── scripts/
    ├── db.sh                    # 数据库工具
    ├── site.sh                  # Nginx 站点管理
    ├── xdebug.sh                # Xdebug 开关
    └── logs.sh                  # 清空容器日志
```

## Compose 结构

整个栈拆分为可组合的文件：

| 文件 | 服务 | 默认启动 |
|---|---|---|
| `compose.yml` | nginx、php-fpm、mysql、mailpit、redis、ofelia、certbot | 是 |
| `compose.observability.yml` | loki、alloy、grafana、prometheus、exporters、glitchtip | 否 |
| `compose.php74.yml` | php74-fpm | 否 |
| `compose.php85.yml` | php85-fpm | 否 |

```bash
# 仅核心服务
make up

# 核心 + 可观测性
make up-obs

# 核心 + PHP 8.5
make up-php85

# 核心 + PHP 7.4
make up-php74

# 全部启动
make up-all
```

也可直接使用 `docker compose`：

```bash
docker compose up -d
docker compose -f compose.yml -f compose.observability.yml up -d
docker compose -f compose.yml -f compose.php85.yml up -d
```

## 对外暴露端口

- `443` -> Nginx
- `3306` -> MySQL

其余服务默认仅在内部网络可访问。

## 多 PHP 版本

默认 PHP 版本由 `compose.yml` 中的 `PHP_VERSION` 控制（默认 `8.4.8`）。

在 Nginx 站点配置中通过 snippet 选择 PHP 版本：

```nginx
# PHP 8.4
include snippets/php-upstream-84.conf;

# PHP 8.5
include snippets/php-upstream-85.conf;

# PHP 7.4
include snippets/php-upstream-74.conf;
```

## SSL 证书（Certbot）

Certbot 作为按需容器运行，使用 `certbot-dns-multi`（通过 lego 支持 117+ DNS 提供商）。

### 配置

1. 复制凭据模板：

```bash
cp certbot/credentials/cloudflare.ini.example certbot/credentials/cloudflare.ini
# 填入你的 API Token
chmod 600 certbot/credentials/cloudflare.ini
```

2. 申请证书：

```bash
make ssl-issue DOMAIN=example.com EMAIL=you@email.com CRED=cloudflare
```

3. 续期：

```bash
make ssl-renew
```

### 支持的 DNS 提供商

在 `certbot/credentials/` 中为你的提供商创建凭据文件，参考对应的 `.ini.example` 文件：

- Cloudflare (`cloudflare.ini`)
- DigitalOcean (`digitalocean.ini`)
- Porkbun (`porkbun.ini`)
- GoDaddy (`godaddy.ini`)
- Route53、Google Cloud、Namecheap，以及 110+ 更多提供商，详见 [lego](https://go-acme.github.io/lego/dns/)

## Mailpit 邮件集成

PHP 通过 Mailpit sendmail 桥接发送邮件：

```ini
sendmail_path = "/usr/local/bin/mailpit sendmail --smtp-addr=mailpit:1025"
```

Mailpit 服务仅在内部网络可访问。如需查看收件箱，通过 Nginx vhost 代理 `mailpit:8025`。

## 可观测性

可观测性栈包含：

- **Loki** — 日志聚合
- **Alloy** — 日志采集（替代 Promtail）
- **Grafana** — 监控面板 + 日志查询
- **Prometheus** — 指标采集
- **Exporters** — mysqld、redis、nginx 指标
- **GlitchTip** — 兼容 Sentry 协议的错误追踪

### 快速启动

```bash
# 从 .example 文件复制并配置可观测性配置
cp loki/config.yaml.example loki/config.yaml
cp alloy/config.alloy.example alloy/config.alloy
cp prometheus/prometheus.yml.example prometheus/prometheus.yml
# 按项目路径和标签编辑各文件

make up-obs
```

通过配置好的 Nginx vhost（代理到 `grafana:3000`）访问 Grafana。

## 数据库工具（`scripts/db.sh`）

```bash
./scripts/db.sh list                                    # 列出所有数据库
./scripts/db.sh shell                                   # 打开 MySQL 交互终端
./scripts/db.sh shell my_project_db                     # 打开指定数据库的终端
./scripts/db.sh export my_project_db                    # 导出到 sql/
./scripts/db.sh ensure my_project_db                    # 创建数据库 + 用户
./scripts/db.sh import ./sql/dump.sql.gz my_project_db  # 导入
./scripts/db.sh copy my_project_db my_project_db_copy   # 克隆
```

查看所有选项：`./scripts/db.sh help`

## Nginx 站点管理（`scripts/site.sh`）

```bash
make site-list                    # 列出可用/已启用站点
make site-new NAME=my-site.conf   # 从模板创建站点配置
make site-enable NAME=my-site.conf
make site-disable NAME=my-site.conf
```

## Xdebug（`scripts/xdebug.sh`）

Xdebug 默认关闭，无需手动编辑配置文件即可切换：

```bash
make xdebug-on      # 启用 + 重启 php-fpm
make xdebug-off     # 禁用 + 重启 php-fpm
make xdebug-status  # 查看当前状态
```

IDE 配置：主机 `host.docker.internal`，端口 `9003`，idekey `VSCODE`。

## 日志轮转

php-fpm 镜像内置 `logrotate`。复制示例策略文件并配置 Ofelia 定时执行：

```bash
cp php-fpm/conf/logrotate.d/app.example php-fpm/conf/logrotate.d/myapp
# 编辑 php-fpm/conf/logrotate.d/myapp 中的路径
```

`config.ini.example` 中已包含现成的 Ofelia `logrotate` 任务。更新 `config.ini` 后：

```bash
docker compose restart ofelia

# 手动执行（验证用）
docker exec -u www-data php-fpm \
  /usr/sbin/logrotate -f \
  -s /var/www/myapp/var/log/.logrotate-state \
  /usr/local/etc/logrotate.d/myapp
```

## 健康检查

核心服务均在 Compose 中配置了健康检查：

- `nginx`
- `php-fpm`（启用 php74/php85 时同样适用）
- `mysql`
- `redis`
- `mailpit`

这有助于改善启动顺序，并可通过 `docker compose ps` 直观查看服务状态。

## 环境变量

完整参考见 `.env.sample`。关键变量：

| 变量 | 说明 |
|---|---|
| `WEB_ROOT` | 本地项目根路径 |
| `PHP_VERSION` | 默认 PHP 版本（8.4.8） |
| `MYSQL_*` | 数据库凭据 |
| `NGINX_VERSION` | Nginx 镜像标签 |
| `GRAFANA_ADMIN_PASSWORD` | Grafana 管理员密码（可观测性） |

## 故障排查

- **Nginx 502/Bad Gateway**
  - 检查 `php-fpm` 容器是否健康：`make ps`
  - 检查 vhost 是否使用了正确的 upstream snippet（`84/85/74`）。

- **数据库连接失败**
  - 确认 `.env` 中的凭据与 `MYSQL_DATABASE` 和应用配置一致。
  - 确认 `mysql` 容器状态健康，且主机 `3306` 端口未被占用。

- **邮件未显示**
  - 确认应用使用 PHP `mail()` 或 SMTP 发送到 `mailpit:1025`。
  - 确认 Mailpit vhost 已代理到 `mailpit:8025`。

## 许可证

MIT 许可证。详见 [LICENSE](LICENSE)。
