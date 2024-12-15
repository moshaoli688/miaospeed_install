# miaospeed_install

## 简介 / Description

**miaospeed_install** 是一款用于简化 MiaoSpeed 网络测速服务安装和配置的自动化脚本。该仓库包含了帮助用户在不同操作系统上轻松安装 MiaoSpeed、FRP 及相关服务的脚本，支持多种 init 系统，包括 systemd、SysVinit、OpenRC、Upstart 和 OpenWrt。

**miaospeed_install** is an automation script designed to simplify the installation and configuration of MiaoSpeed, a high-performance network speed testing service. The repository contains scripts that allow users to easily set up MiaoSpeed, FRP, and related services on various operating systems, supporting multiple init systems like systemd, SysVinit, OpenRC, Upstart, and OpenWrt.

## 特性 / Features

- **自动化安装 / Automated Setup**：简化 MiaoSpeed 和相关组件的安装。
- **跨平台支持 / Cross-Platform Support**：支持 Linux、macOS 和其他类 Unix 系统。
- **可自定义配置 / Customizable Configuration**：允许用户配置服务器设置、端口和安全功能等多个参数。
- **服务管理 / Service Management**：自动生成适用于 systemd、OpenRC、SysVinit 和其他 init 系统的服务文件。

## 安装方法 / Installation

1. **下载并运行脚本 / Download and Run the Script:**

   ```sh
   curl -sL https://raw.githubusercontent.com/MiaoMagic/miaospeed_install/refs/heads/master/install.sh -o install.sh && sh install.sh --uid=<UID> --port=<PORT>
   ```

2. **或者手动下载并运行 / Alternatively, download and run manually:**

   ```sh
   curl -sL https://raw.githubusercontent.com/MiaoMagic/miaospeed_install/refs/heads/master/install.sh -o install.sh
   sh install.sh --uid=<UID> --port=<PORT>
   ```
## 配置 / Configuration

通过脚本提供的命令行参数，您可以配置以下内容：

- **--uid**：指定 UID（必填）
- **--port**：指定端口（必填）
- **--token**：设置 Token（可选）
- **--path**：设置 WebSocket 路径（可选）
- **--nospeed**：禁用测速功能（可选）
- **--work-dir**：设置工作目录（可选）

## 支持的操作系统 / Supported Operating Systems

- **Linux** (systemd, SysVinit, OpenRC, Upstart, OpenWrt)
- **macOS** (launchd)

## 版权 / License

该项目使用 [MIT License](LICENSE)，自由使用、修改和分发。
