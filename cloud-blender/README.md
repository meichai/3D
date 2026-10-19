# Blender 云端自动建模环境

已验证环境（2026-10-19）：Debian 13.6 x86_64，系统 Python 3.12.14，Debian Blender 4.3.2+dfsg-2，Blender 内部 Python 3.13.5。使用当前镜像已有的稳定发行版 4.3.2；它不是 LTS，也不宣称为最新版本。无需显示服务器、GPU、外部 bpy 包或付费服务。

## Codex Cloud 配置

关联仓库选择 `meichai/3D`。在环境的安装脚本（Setup script）填入以下内容（从仓库根目录执行）：

```bash
bash cloud-blender/setup.sh
bash cloud-blender/test.sh
```

维护脚本（Maintenance script，如有）也可运行相同命令。保存环境配置，重新创建一个任务验证。此仓库文件不会自动修改 Codex 控制台中的安装脚本字段；必须在控制台保存该字段。当前任务镜像已经有 Blender，因此本次没有下载或替换系统程序。

setup.sh 可重复执行：存在 Blender 时验证精确版本和导出算子；缺少时使用 apt 安装（需要 root 或已有免密码 sudo）。没有安装权限时明确失败，不请求密码、不修改系统权限。不支持任意无权限空白镜像自动安装。Debian 13 当前包为 4.3.2；若软件源升级版本，版本校验会失败，应先验证新版本再更新基线。首次下载分支本次未执行。软件源网络须可访问 deb.debian.org/security.debian.org；当前任务代理连接失败，不能宣称联网安装已验证。

为了可靠复用，后续任务保持相同 Debian 13 镜像及预装 Blender，或在有安装权限的初始化阶段安装 Blender。可设置 `BLENDER_BIN=/absolute/path/to/blender` 选择匹配的可执行文件。

## 建模与测试

```bash
blender --background --factory-startup --python-exit-code 1 --python your_model.py
bash cloud-blender/test.sh
```

Python 脚本在 Blender 内执行，使用内置 bpy/bmesh。系统 Python 与 Blender Python 版本不同，勿向系统 Python 安装 bpy 来代替 Blender。

测试每次创建 `work/blender-tests/run-XXXXXXXX/`，不覆盖之前的输出。生成 cube_50mm.blend、STL、OBJ、MTL、FBX、日志及 JSON/文本报告。共 14 项检查：源尺寸和网格、每种格式的文件、重新导入对象数、尺寸及网格完整性。任一失败退出码非零，已执行的项目记录成功或失败。STL 顶点合并后验证封闭性，允许导出器三角化，尺寸误差阈值 0.001 mm。

统一约定 1 个坐标单位 = 1 mm，场景 scale_length=0.001，立方体坐标尺寸为 50。STL、OBJ 无可靠物理单位，其他软件导入时选择毫米；FBX 写入单位元数据。回读验证在同版本 Blender 中完成，不代表所有第三方软件的默认单位设置。

## 已知限制

本次工作区和远端仓库均为空，未删除或覆盖模型。无 sudo、无 root；全新镜像的 apt 安装分支未验证。远端文件通过 GitHub 连接器保存；普通 git 网络连接代理失败。测试输出不提交 Git，仅提交脚本、说明及测试基线报告。Codex 控制台配置字段需用户保存；云端任务销毁后应依靠仓库和安装脚本恢复环境，而非依靠本任务磁盘。
