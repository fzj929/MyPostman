# MyPostman

本地运行的 API 请求工作台。后端使用 .NET 8，页面使用 Vue 3，数据保存在本地 SQLite。

## 运行

需要 .NET 8 SDK、Node.js 20.19+。

```powershell
dotnet run --project MyPostman.Api
```

开发前端时，在另一个终端运行：

```powershell
cd MyPostman.Web
npm install
npm run dev
```

开发页面地址由 Vite 输出（通常为 `http://127.0.0.1:5173`）；前端 API 请求代理到 `http://127.0.0.1:5078`。

制作单端口版本：

```powershell
cd MyPostman.Web
npm install
npm run build
cd ..
dotnet run --project MyPostman.Api
```

浏览器打开 `http://127.0.0.1:5078`。应用只监听本机地址。数据文件在 `MyPostman.Api/App_Data/workspace.db`。

## 系统服务

安装脚本会先用 Node.js 构建 Vue 页面，再通过 .NET 8 SDK 发布 API，最后注册并启动服务。需要预先安装 .NET 8 SDK、Node.js 20.19+ 和 npm；Linux 还需要 systemd，以及系统级可访问的 `dotnet` 命令。以下命令从仓库根目录执行。默认监听 `http://127.0.0.1:5078`，可在 `install` 或 `run` 后面传入其他端口，例如 `install 5080`。切换端口时重新运行 `install`。

Windows：在**管理员 PowerShell** 中安装、卸载或控制服务。

```powershell
.\scripts\manage-service.ps1 install
.\scripts\manage-service.ps1 status
.\scripts\manage-service.ps1 stop
.\scripts\manage-service.ps1 start
.\scripts\manage-service.ps1 restart
.\scripts\manage-service.ps1 uninstall
```

Linux：使用 sudo 安装、卸载或控制服务。

```bash
sudo bash scripts/manage-service.sh install
bash scripts/manage-service.sh status
sudo bash scripts/manage-service.sh stop
sudo bash scripts/manage-service.sh start
sudo bash scripts/manage-service.sh restart
sudo bash scripts/manage-service.sh uninstall
```

`run` 用于在前台直接启动服务器，不注册系统服务，也不需要管理员权限；按 Ctrl+C 停止。已在默认端口运行开发服务器或系统服务时，请先停止它，再执行 `run`。

```powershell
.\scripts\manage-service.ps1 run
```

```bash
bash scripts/manage-service.sh run
```

Windows 服务名为 `MyPostman`，程序发布在 `%ProgramFiles%\MyPostman`，SQLite 数据位于 `%ProgramData%\MyPostman`，服务以 LocalService 身份运行。Linux 服务名为 `mypostman.service`，程序发布在 `/opt/mypostman`，SQLite 数据位于 `/var/lib/mypostman`，服务以 `mypostman` 用户运行。再次执行 `install` 可更新程序。`uninstall` 只移除服务注册，保留程序文件和工作区数据。

## 功能

- HTTP 请求编辑与发送，支持参数、请求头、请求 Cookie、JSON、文本、表单和 Multipart 文件。
- Basic Auth、Bearer Token、API Key；支持集合、文件夹、请求三级配置与继承。
- 请求可选择集合及文件夹保存；历史记录保留发送时的请求参数、正文、Cookie、有效认证与环境变量快照（旧版历史只有地址）。
- 响应单独显示 Set-Cookie；请求诊断显示最终 URL、请求头与正文预览，以及准备、等待响应头、读取响应体阶段耗时。等待响应头包含 DNS/TCP/TLS/服务端处理，无法精确拆分这些子阶段。
- 自动添加 `Accept`、`User-Agent`、`Accept-Encoding` 请求头，自定义同名头可以覆盖。
- 环境变量 `{{变量名}}`、本地工作区导入导出，以及 Postman Collection v2.1 的基础导入。

认证值及历史快照以明文保存在本机 SQLite 工作区及导出的 JSON 中。请妥善保管这些文件；不要将本应用直接作为公网服务部署。

测试时可通过环境变量 `MyPostman__ListenUrl` 和 `MyPostman__DataDirectory` 指定独立端口与数据目录，避免更改已有工作区。
