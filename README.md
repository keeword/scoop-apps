# scoop-apps

个人维护的 Scoop 第三方 bucket。应用清单放在 [`bucket/`](bucket/) 目录，每个应用对应一个 `<应用名>.json` 文件。

## 使用

仓库发布到 Git 服务后，将下面的地址换成实际仓库地址：

```powershell
scoop bucket add myapps https://github.com/keeword/scoop-apps
scoop install myapps/<应用名>
```

更新 bucket 和已安装应用：

```powershell
scoop update
scoop update <应用名>
```

## 添加应用

在 `bucket/` 下创建 JSON 清单，至少填写版本、下载地址和下载文件的 SHA-256。清单格式和可选字段见 [Scoop 官方清单文档](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)。不要把示例占位值提交到 `bucket/`。

可以先在本地安装 Scoop，再用以下命令验证并试装：

```powershell
./scripts/Test-Bucket.ps1
scoop install ./bucket/<应用名>.json
```

`Test-Bucket.ps1` 检查清单是否为合法 JSON，以及常见必填字段是否存在；实际下载、解压和安装仍需用 Scoop 试装确认。
