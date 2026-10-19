# Blender 云端环境

基线：Blender 4.3.2，后台运行，无需显示服务器或 GPU。脚本不修改已有模型、用户首选项或系统软件。

## 云端配置

仓库选择 `meichai/3D`，分支选择 `main`，安装脚本在仓库根目录执行：

```bash
bash cloud-blender/setup.sh
bash cloud-blender/test.sh
```

仓库文件不会自动更新云端控制台的安装脚本字段。需在环境配置中保存上述命令。

## 无管理员权限安装

优先使用 `BLENDER_BIN` 指定的程序或 PATH 中的 Blender，然后复用 `BLENDER_INSTALL_DIR`（默认 `work/blender-runtime`）中的缓存。已有程序版本不符或无法运行时直接失败，不自动替换。

没有 Blender 时默认明确失败，避免不必要的下载。允许用户目录安装：

```bash
BLENDER_ALLOW_DOWNLOAD=1 bash cloud-blender/setup.sh
bash cloud-blender/test.sh
```

下载仅支持 Linux x86_64，使用官方 4.3.2 压缩包及 SHA256 清单，无需 root、sudo 或 apt。需要 curl、tar、xz、sha256sum 和镜像提供的 Blender 动态库。若下载域名 download.blender.org 被网络策略阻止，应在环境配置中允许该域名或使用预装镜像，不能靠脚本绕过策略。此下载分支尚未经过真实联网安装验证。

安装日志每次保存为 `work/blender-setup/setup-XXXXXXXX.log`，成功后记录程序路径到 `work/blender-setup/env.sh`，供 test.sh 使用。失败退出码非零。work 目录不提交 Git；任务销毁前应从日志界面或工作区导出所需日志。

## 空仓库排查

2026-10-19 检查发现：GitHub main 已含脚本，但新工作区停留在无提交的 work 分支，且 git 连接代理端口 8080 失败。应区分远端为空和检出失败。可检查：

```bash
git status --short --branch
git remote -v
git log -5 --oneline
git ls-remote origin
```

网络恢复且工作区无待保存更改后，通过正常 fetch/checkout 检出 origin/main。不要删除已有项目来修复检出。本次通过 GitHub 连接器按固定提交读取文件；这不代表云端原生 checkout 已恢复。

## 建模与验证

`test.sh` 每次创建唯一的 `work/blender-tests/run-XXXXXXXX`，生成 50 mm 立方体的 blend、STL、OBJ、MTL、FBX、blender.log、report.json 和 report.txt，不覆盖历史结果。14 项检查涵盖源尺寸、网格封闭性、体积、三种格式导出及重新导入。

1 坐标单位 = 1 mm，场景 scale_length=0.001。STL/OBJ 导入其他软件时选毫米；FBX 写入单位元数据。回读只证明本版本 Blender 的往返结果。

`validated-report.json` 为先前成功测试的历史基线；本次执行日志和报告保留在本任务 work 目录，不公开上传。测试脚本运行在 factory-startup 的独立 Blender 进程，不读取已有模型。

## 新任务验证状态

当前会话工具没有创建 Codex 云端任务或编辑环境配置的接口，未创建新任务。本次以 UID 1000 复用 /usr/bin/blender，安装脚本成功，14 项建模与导出检查全部通过。缺少 Blender 且未允许下载时按预期以退出码 2 失败。完成了本会话云端执行及 GitHub 固定提交文件读取验证；两者不能替代新任务的原生检出与自动安装验证。

