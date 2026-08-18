# sharkSMS 前后端部署教程

## 后端部署说明

1. **安装宝塔面板**  
   参考宝塔官方安装命令进行安装。

2. **安装运行依赖环境**  
   在宝塔面板的软件商店中安装以下组件：  
   - MySQL 8.0+  
   - Redis 8.0+  
   - Node.js 版本管理器
   - PHP 7.4

3. **安装 Node 环境**  
   - 在宝塔面板中，依次进入「软件商店」→「已安装」，找到「Node.js 版本管理器」并点击「设置」
   - 点击「更新版本列表」，在列表中找到 **v22.12.0** 并点击安装
   - 等待安装完成后，将该版本设置为「命令行版本」即可

4. **拉取 sharkSMS 源文件并解压**  
   - 打开宝塔面板的「文件」，切换到 **/www/wwwroot/** 目录，点击「终端」
   - 执行以下命令拉取 sharkSMS 源文件：  
     ```bash
     git clone https://github.com/SharkMesh/sharksms.git
     ```
   - 执行以下命令确认服务器架构版本：
     ```bash
     uname -m
     ```
   - **选择对应的安装包：**
     - 如果输出为 `x86_64`，请选择 `sharksms-linux-x64.zip` 解压
     - 如果输出为 `aarch64` 或 `arm64`，请选择 `sharksms-linux-arm64.zip` 解压
     - 另一个无用的文件可以直接删除

5. **修改配置文件并部署后端**  
   - 切换到对应安装包解压后的目录，例如 `/www/wwwroot/sharksms-linux-x64`，并点击「终端」
   - 在终端中执行以下命令生成配置文件 `.env` ：
     ```bash
     cp .env.example .env
     ```
   - 关闭终端，打开.env文件并修改配置，完成后保存
   - 再次打开终端，执行以下命令安装依赖：
     ```bash
     pnpm install
     ```
   - 执行以下命令初始化数据库：
     ```bash
     npm run initDB
     ```
   - 看到 `数据库表初始化成功` 后关闭终端
   - 在宝塔面板中找到 「网站」，切换分类后 「Node项目」，点击「添加项目」
   - 两种部署方式 `单进程` 和 `PM2多进程` 任选一种即可 (推荐 `PM2多进程`)
   **单进程**  
   ![单进程部署截图](img/ScreenShot_2026-08-18_161839_275.png)  
   **PM2多进程**  
   ![PM2多进程部署截图](img/ScreenShot_2026-08-18_161930_666.png)
   - 选择任意一种部署方式，配置好，点击确认即可
   - 切记放行端口 `3000` 即可访问后端接口
   - 至此，sharkSMS 后端部署完成

## 前端部署说明

1. **添加网站**  
   - 在宝塔面板中，依次点击「网站」→「PHP项目」→「添加站点」
   - 填写域名
   - 选择根目录，刚才拉取的项目目录中的 `frontend` 目录作为根目录
   - 点击确认即可
   - 然后找到 `frontend` 相对目录下的 `frontend/res/config.js` 文件，修改后端接口基础URL，为你的后端接口URL即可 如：`http://你的服务器IP:3000`
   - 至此，sharkSMS 前端部署完成

## 常见问题说明

**域名证书问题**
- 如前端部署并开启了SSL证书，则需要同步开启后端服务的SSL证书，并在 `frontend/res/config.js` 文件中修改后端接口基础URL为带 `https://` 的基础URL即可，多进程模式可使用反向代理实现

**agent端连接问题**
- 如agent端连接失败，则需要检查后端服务器的mysql服务 `3306` 端口是否放行，后端数据库是否开启 agent端IP 访问权限

**后端无法启动问题**
- 请确认当前服务器是否经过授权，若未授权，则需要先授权后端服务，授权后即可启动后端服务

## agent端常用命令

- **查看服务状态**：`systemctl status sms_agent`
- **停止开机自启**：`sudo systemctl disable sms_agent`
- **开启开机自启**：`sudo systemctl enable sms_agent`
- **查看程序版本**：`/opt/sms_agent/sms_agent -v`
- **查看节点日志**：`journalctl -u sms_agent -f`
- **查看开机启动状态**：`systemctl is-enabled sms_agent`
- **agent端配置文件位置**: `/opt/sms_agent/.env`

## agent端参数说明
| 参数 | 说明 | 示例 |
| :--- | :--- | :--- |
| `--db-user` | MySQL 用户名 | `root` |
| `--db-pass` | MySQL 密码 | `password` |
| `--db-name` | 数据库名 | `sms_db` |
| `--mem-limit` | 内存硬限制 (G) | `1G` |
| `--cpu-limit` | CPU 使用率限制 | `50%` |
| `--agent-id` | Agent 唯一标识 | `node-01` |
| `--skip-redis` | 不自动安装 Redis | - |
| `--update` | 仅更新二进制文件 | - |