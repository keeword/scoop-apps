# scoop-apps

个人维护的 Scoop 第三方 bucket，用于在 Windows 上安装和更新以下应用。

| 应用 | 用途 | 支持架构 | 上游项目 |
| --- | --- | --- | --- |
| `bwssh` | 使用 Bitwarden 密钥库的 SSH agent，支持通知审批和 Windows Hello | x64 | [bwssh](https://github.com/luoxiaoxin123/bwssh) |
| `pebrel` | GPU 加速终端，支持 SSH 和分屏 | x64、ARM64 | [Pebrel](https://github.com/Kuddev/pebrel) |

## 使用

先按 [Scoop 官方安装说明](https://scoop.sh/) 安装 Scoop，并确保 Git 可用（`scoop install git`）。然后添加 bucket，选择需要的应用：

```powershell
scoop bucket add myapps https://github.com/keeword/scoop-apps
scoop install myapps/bwssh
scoop install myapps/pebrel
```

更新 bucket 和已安装应用：

```powershell
scoop update
scoop update bwssh
scoop update pebrel
```

## 添加应用

在 [`bucket/`](bucket/) 下创建 `<应用名>.json` 清单，填写版本、主页、许可证、下载地址和下载文件的 SHA-256；每个架构都需提供对应的地址和哈希。清单格式和可选字段见 [Scoop 官方清单文档](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)。不要提交示例占位值。

在仓库根目录使用 PowerShell 7.4 或更新版本运行校验：

```powershell
./scripts/Test-Bucket.ps1
./scripts/Test-Bucket.test.ps1
```

普通校验使用仓库内固定版本的 [Scoop 官方 schema](scripts/vendor/README.md)，检查字段、架构和哈希格式，以及下载地址与哈希的数量是否一致，无需联网。

发布新清单或修改下载地址、版本、哈希时，再下载所有架构的文件并核对 SHA-256：

```powershell
./scripts/Test-Bucket.ps1 -CheckDownloads
```

下载校验不会安装应用。还需在对应架构的 Windows 测试环境中试装，确认解压后能创建命令和快捷方式，并验证启动、更新、卸载及用户数据保留情况。例如测试 Pebrel：

```powershell
scoop install ./bucket/pebrel.json
pebrel
# 修改清单版本后验证更新
scoop update pebrel
scoop uninstall pebrel
```

测试 `bwssh` 时，尤其要确认更新后 SSH agent 正常工作、卸载时的 `--uninstall-cleanup` 正常执行；应在测试账户中验证，避免影响日常 SSH 配置。

## 手动更新清单

在 GitHub Actions 中手动运行工作流，调用 Scoop 官方 `checkver.ps1 -Update`，按清单中的 `checkver` 和 `autoupdate` 检查版本、更新下载地址和 SHA-256，再运行清单校验。有修改时自动创建或更新一个 PR，由维护者审核、试装后手动合并。

- 将配置推送到 GitHub 默认分支，并确保仓库启用了 Actions。
- 在仓库 **Settings → Actions → General → Workflow permissions** 启用 **Allow GitHub Actions to create and approve pull requests**。工作流使用内置 `GITHUB_TOKEN`，无需额外 Token 或 Secret；若组织策略禁止创建 PR，需由组织管理员调整。
- 手动运行：仓库 **Actions → Update app manifests → Run workflow**。工作流更新默认分支的清单。
- 自动更新统一使用 `automation/app-updates` 分支，后续运行会更新已有 PR。不要在此分支提交手工修改；没有清单变化时不会新建 PR。
- 内置 Token 创建的 PR 通常不会触发其他工作流，因此更新工作流会在创建 PR 前完成清单校验和校验脚本测试。应用功能和安装仍需手动验证。

现有两个应用均配置了 `checkver.github` 和 `autoupdate`；后续可使用 Scoop 支持的其他检查来源。维护脚本固定到 [Scoop 提交 `e6aa3b3`](https://github.com/ScoopInstaller/Scoop/tree/e6aa3b366bdee8ed138c1e0f7b85192ebdd35d0f)，直接检出并运行，无需在 runner 上安装 Scoop。

本地已安装 Scoop 时，也可在仓库根目录手动检查或更新：

```powershell
& "$(scoop prefix scoop)\bin\checkver.ps1" -Dir ./bucket
& "$(scoop prefix scoop)\bin\checkver.ps1" -Dir ./bucket -Update -ThrowError
./scripts/Test-Bucket.ps1
```

## 问题反馈

安装、下载、哈希或清单更新问题请在 [本仓库 Issues](https://github.com/keeword/scoop-apps/issues) 反馈，附上应用名、架构、Scoop 版本和错误日志。发布日志前请移除令牌等敏感信息。

应用本身的功能或运行问题请到上方应用表中的上游项目反馈。

## 许可证

本仓库原创清单、脚本和文档采用 [MIT 许可证](LICENSE)。Scoop schema 的来源和许可证见 [`scripts/vendor/`](scripts/vendor/README.md)；各应用本身遵循各自的上游许可证。
