# GitHub 私有仓库发布

目标名称：`thesis-tractor-control`，可见性：Private；不自动初始化 README、license 或 gitignore，本地已有基线。

本机可在安装并登录官方 GitHub CLI 后执行以下命令；若 `origin` 已存在，先核对目标，不覆盖已有远程。

自动完成本地初始提交、标签、`dev` 分支与真实克隆检查：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/finish_repository_setup.ps1
```

该脚本需要对 `.git` 有写权限。完成本地基线后，选择以下 GitHub CLI 命令创建私有远程并推送；也可在首次执行脚本时添加 `-Publish` 完成同样操作。

命令使用 Windows 自带的 PowerShell 5.1，无需安装 `pwsh`。`-ExecutionPolicy Bypass` 仅用于这次进程，不修改系统执行策略。只检查、不创建提交时在命令末尾加 `-CheckOnly`。

```powershell
gh auth login
gh repo create thesis-tractor-control --private --source . --remote origin
git push -u origin main
git push -u origin dev
git push origin v0.1-baseline
```

也可在 GitHub 网页创建空白私有仓库后，用网页实际返回的 HTTPS 地址执行 `git remote add origin <实际地址>`，再运行上述 push 命令。不要将令牌写入脚本或远程 URL。

本项目默认以 `dev` 开发，仅在检查完成后集成至 `main`。若账号支持私有仓库分支保护，可为 `main` 开启 PR 审阅与禁止强推；实际可用性受账号套餐限制。当前未宣称已启用保护。

推送后到网页确认 Private、提交哈希、`main`/`dev` 和基线标签，并用全新目录克隆验证。忽略文件不会被上传或恢复。
