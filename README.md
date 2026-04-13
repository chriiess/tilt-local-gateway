# Tilt Microservices Dev Kit

用 Tilt 管理本地go微服务开发环境，统一启动后端/前端服务，并自动生成 Nginx 网关路由。

- 平台：macOS
- 适用场景：go微服务本地联调
- 唯一入口命令：`./devmesh`

## Quick Start

```bash
brew install tilt jq nginx
./devmesh init
./devmesh validate
./devmesh up
```

访问地址：
- Tilt UI: http://localhost:10350
- API 网关: http://localhost:17001
- Demo 前端: http://localhost:18080

## 内置 Demo（两个最小项目）

`./devmesh init` 会自动生成可直接运行的 `config.json`，默认使用内置 demo：

- `demo/projects/go-hello`：Go API 服务（`/api/hello/*`）
- `demo/projects/web-hello`：静态前端页面（按钮调用后端 API）

体验流程：

```bash
./devmesh init
./devmesh validate
./devmesh up
```

打开 `http://localhost:18080`，点击页面按钮即可看到后端响应。

如需直接生成“完整配置模板”，可使用：

```bash
./devmesh init --full
```

## 常用命令

```bash
./devmesh init                # 生成本地 config.json（demo 可运行）
./devmesh init --full         # 生成完整版配置模板（需按项目实际修改）
./devmesh validate            # 校验配置和环境依赖
./devmesh up [services]       # 启动所有/指定服务
./devmesh down                # 停止所有服务
./devmesh restart [services]  # 重启所有/指定服务
./devmesh status              # 查看服务状态
./devmesh logs <service>      # 查看服务日志
./devmesh ports               # 检查端口占用
./devmesh cleanup             # 安全清理（仅清理本工具启动的进程）
./devmesh setup-nginx         # 可选：手动配置 Nginx 80 端口权限
./devmesh setup-hosts         # 可选：手动配置本地域名映射
./devmesh up -c=./config.json # 指定配置文件
```

## 配置说明

主配置文件为 `config.json`，模板为 `config.demo.example`。

### 顶层字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `code_root` | string | 是 | 代码根目录，必须为绝对路径 |
| `gateway.port` | number | 是 | API 网关端口 |
| `gateway.headers` | object | 否 | 注入到代理请求的 Header |
| `go_services` | object | 否 | Go 服务集合 |
| `frontend_services` | object | 否 | 前端服务集合 |

### Go 服务字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `path` | string | 是 | 服务目录，相对 `code_root` 或绝对路径 |
| `port` | number | 是 | 服务监听端口 |
| `route` | string | 否 | 网关路径，支持逗号分隔多个路由 |
| `domain` | string | 否 | 支持主机名或 `http/https` URL，支持逗号分隔多个 |
| `config` | string | 否 | 服务配置文件路径 |
| `config_arg` | string/null | 否 | 配置参数形式，如 `-c`、`-config=`、`--gf.gcfg.file=` |
| `enabled` | boolean | 是 | 是否启用 |

### 前端服务字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `path` | string | 是 | 前端项目目录 |
| `port` | number | 是 | 前端服务端口 |
| `start_command` | string | 否 | 启动命令，默认 `npm run serve` |
| `node_version` | string | 否 | Node 版本（通过 nvm 切换） |
| `static_path` | string | 否 | dist静态资源目录，启用则不使用start_command启动 |
| `route` | string | 否 | 网关路径，支持逗号分隔多个 |
| `domain` | string | 否 | 支持主机名或 `http/https` URL，支持逗号分隔多个 |
| `enabled` | boolean | 是 | 是否启用 |

### Demo 默认配置示例

```json
{
  "code_root": "__CODE_ROOT__",
  "gateway": {
    "port": 17001,
    "headers": {
      "x-demo-user": "tilt-demo"
    }
  },
  "go_services": {
    "go-hello": {
      "path": "./go-hello",
      "port": 18081,
      "route": "/api/hello",
      "enabled": true
    }
  },
  "frontend_services": {
    "web-hello": {
      "path": "./web-hello",
      "port": 18080,
      "static_path": "./dist",
      "route": "/demo",
      "enabled": true
    }
  }
}
```

### 完整配置示范

```json
{
  "code_root": "/Users/you/workspace",
  "gateway": {
    "port": 17001,
    "headers": {
      "x-env": "local",
      "x-debug": "true"
    }
  },
  "go_services": {
    "user-api": {
      "path": "./services/user-api",
      "port": 18081,
      "route": "/api/user,/api/profile",
      "domain": "user.local.dev,https://user.local.test",
      "config": "./configs/dev.yaml",
      "config_arg": "-config=",
      "enabled": true
    },
    "order-api": {
      "path": "/Users/you/workspace/services/order-api",
      "port": 18082,
      "route": "/api/order",
      "config": "./conf/local.toml",
      "config_arg": "--gf.gcfg.file=",
      "enabled": true
    },
    "legacy-api": {
      "path": "./services/legacy-api",
      "port": 18083,
      "route": "/api/legacy",
      "config": "./config/dev.yaml",
      "config_arg": null,
      "enabled": false
    }
  },
  "frontend_services": {
    "admin-web": {
      "path": "./frontends/admin-web",
      "port": 18080,
      "start_command": "pnpm dev",
      "node_version": "20",
      "route": "/admin,/dashboard",
      "domain": "admin.local.dev,http://admin.local.test",
      "enabled": true
    },
    "portal-static": {
      "path": "./frontends/portal",
      "port": 18084,
      "static_path": "./dist",
      "route": "/portal",
      "domain": "portal.local.dev",
      "enabled": true
    }
  }
}
```

## 域名模式（可选）

域名模式用于通过 `http://service-name` 直接访问服务，依赖：
- Nginx 监听 80 端口
- 本地 hosts 映射

启用方式（推荐）：

```bash
./devmesh up
```

如果检测到已配置 `domain` 且系统尚未准备好（sudoers/hosts），`devmesh` 会提示二次确认，输入 `Y` 后自动执行准备步骤。

也可以手动执行（可选）：

```bash
./devmesh setup-nginx
./devmesh setup-hosts
./devmesh validate
./devmesh up
```

说明：
- `domain` 支持 `host`、`http://host`、`https://host`，会自动提取主机名。
- 多域名使用逗号分隔。

## 推荐实践

- `route` 必须以 `/` 开头，例如 `/api/user`。
- 先跑 `./devmesh validate`，再跑 `./devmesh up`。
- 如配置了 `domain`，`up/ui` 会自动检测并提示是否执行 `setup-nginx`、`setup-hosts`。

## 常见问题

- `config.json 中未配置 code_root`：请填写绝对路径，不要使用 `~`。
- `端口冲突`：运行 `./devmesh ports` 定位占用进程。
- `配置了 domain 但不生效`：重新执行 `./devmesh up`，按提示授权自动执行 `setup-nginx` 与 `setup-hosts`。

## License

MIT
