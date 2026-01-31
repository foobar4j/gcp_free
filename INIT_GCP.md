# GCP 服务器一键初始化

本脚本用于快速初始化 GCP 等云服务器，包含以下功能：

1. 开启 root 用户密码登录 SSH
2. 可选安装 1Panel 管理面板
3. 可选安装 x-ui-yg 脚本（用于科学上网）

## 一键安装

```bash
curl -Ls https://raw.githubusercontent.com/foobar4j/gcp_free/main/init_gcp.sh | bash
```

## 使用步骤

1. 登录到你的 GCP 服务器（通过 Cloud Shell 或 SSH）
2. 执行一键安装命令
3. 按照脚本提示完成配置

## 脚本功能说明

### 步骤 1/3：配置 Root 用户 SSH 登录

- 自动修改 `/etc/ssh/sshd_config` 配置文件
- 启用 root 用户登录
- 启用密码认证
- 重启 SSH 服务
- 提示设置 root 用户密码

### 步骤 2/3：安装服务器管理面板（可选）

- 询问是否安装 1Panel 管理面板
- 选择 `y` 则自动安装 1Panel
- 选择 `n` 则跳过此步骤

### 步骤 3/3：安装科学上网管理脚本（可选）

- 询问是否安装 x-ui-yg 管理脚本
- 选择 `y` 则自动执行 x-ui-yg 安装脚本（交互式）
- 选择 `n` 则跳过此步骤

## 注意事项

1. 脚本必须以 root 用户身份运行
2. 安装完成后，如果安装了需要开放端口的服务（如 1Panel、x-ui-yg），请务必在云服务商（GCP）的防火墙/安全组规则中放行相应的端口
3. 设置 root 密码时请使用强密码

## 手动下载使用

如果无法使用一键安装命令，可以手动下载脚本：

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/foobar4j/gcp_free/main/init_gcp.sh

# 添加执行权限
chmod +x init_gcp.sh

# 运行脚本
sudo bash init_gcp.sh
```