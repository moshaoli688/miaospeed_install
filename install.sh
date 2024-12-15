#!/bin/sh
# Developer: Mo Shao Li (墨少离)
# Blog: www.msl.la
# License: This script is open source. Please retain the author and license information when sharing or modifying it.
#
# This script helps with setting up services for MiaoSpeed, FRP, and other related configurations.
# It can generate service files, download the latest versions of programs, and configure them for system initialization.
# The script supports multiple init systems including systemd, SysVinit, OpenRC, Upstart, and OpenWrt.
# Additionally, it can be used to handle configuration files for MiaoSpeed and FRPC, as well as set up necessary environment variables.

MS_TOKEN=""
MS_PATH=""
MS_NOSPEED="false"
MS_UID=""
MS_PORT=""
MS_INIT=""
MS_ARCH=""
MS_WORK_DIR=""
MS_WORK_DIR_ABS=""

# Proxy server configuration, modify as needed
PROXY_URLS="https://www.demo.com/gh/,https://www.demo2.com/gh/"
# FRP server settings, modify as needed
FRP_SERVER="1.1.1.1"
FRP_SERVER_TOKEN="2.2.2.2"
FRP_SERVER_PORT="7777"
FRP_SERVER_PROTOCOL="tcp"

generate_uuid() {
  local uuid=""

  if [ -f /proc/sys/kernel/random/uuid ]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
    echo "$uuid"
    return 0
  fi

  if command -v uuidgen >/dev/null 2>&1; then
    uuid=$(uuidgen)
    echo "$uuid"
    return 0
  fi

  uuid=$(curl -s "https://www.uuidtools.com/api/generate/v1" | sed 's/\["\(.*\)"\]/\1/')

  if [ -n "$uuid" ]; then
    echo "$uuid"
    return 0
  else
    uuid="default-$(date +%s)"
    echo "$uuid"
    return 1
  fi
}

validate_port() {
  local port="$1"

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Invalid port: $port. Port must be between 1 and 65535."
    exit 1
  fi

  if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "Invalid port: $port. Port must be between 1 and 65535."
    exit 1
  fi

  # If needed, you can add additional port occupation checks here (e.g., by requesting an external API for validation)
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --uid=*)
      MS_UID="${1#*=}"
      shift
      ;;
    --port=*)
      MS_PORT="${1#*=}"
      shift
      ;;
    --token=*)
      MS_TOKEN="${1#*=}"
      shift
      ;;
    --path=*)
      MS_PATH="${1#*=}"
      shift
      ;;
    --nospeed)
      MS_NOSPEED="true"
      shift
      ;;
    --work-dir=*)
      MS_WORK_DIR="${1#*=}"
      shift
      ;;
    -h | --help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
    esac
  done
}

show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --uid=UID          Set the UID (required)"
  echo "  --port=PORT        Set the port (required)"
  echo "  --token=TOKEN      Set the token (optional)"
  echo "  --path=PATH        Set the path (optional, defaults to token)"
  echo "  --nospeed          Disable speed (optional)"
  echo "  --work-dir=DIR     Set the working directory (optional)"
  echo "  -h, --help         Show this help message"
  exit 0
}

validate_required_params() {
  if [ -z "$MS_UID" ]; then
    echo "Error: --uid is required"
    exit 1
  fi

  if [ -z "$MS_PORT" ]; then
    echo "Error: --port is required"
    exit 1
  fi
}

handle_defaults() {
  MS_ARCH=$(detect_architecture)
  MS_INIT=$(detect_init_system)
  if [ -z "$MS_WORK_DIR" ]; then
    MS_WORK_DIR="/opt/miaospeed"
    echo "No work directory provided, using default directory: $MS_WORK_DIR"
  fi

  if [ -n "$MS_WORK_DIR" ]; then
    if [ ! -d "$MS_WORK_DIR" ]; then
      echo "Directory $MS_WORK_DIR does not exist. Creating it..."
      mkdir -p "$MS_WORK_DIR"
    fi
    echo "Changed working directory to: $MS_WORK_DIR"
  fi
  MS_WORK_DIR_ABS="$(cd "$MS_WORK_DIR" && pwd)"
  echo "Absolute path: $MS_WORK_DIR_ABS"
  cd "$MS_WORK_DIR" || exit 1

  if [ -z "$MS_TOKEN" ]; then
    MS_TOKEN=$(generate_uuid)
    echo "No token provided, generated token: $MS_TOKEN"
  fi

  if [ -z "$MS_PATH" ]; then
    MS_PATH="$MS_TOKEN"
    echo "No path provided, using token as path: $MS_PATH"
  fi
}

print_params() {
  echo "============================== Configuration ==============================="
  echo ""
  echo "  UID        : $MS_UID"
  echo "  PORT       : $MS_PORT"
  echo "  TOKEN      : $MS_TOKEN"
  echo "  PATH       : $MS_PATH"
  echo "  NOSPEED    : $MS_NOSPEED"
  echo "  INIT       : $MS_INIT"
  echo "  ARCH       : $MS_ARCH"
  echo "  WORK_DIR   : $MS_WORK_DIR"
  echo ""
  echo "============================================================================"
}

run_command() {
  local NOSPEED="false"
  print_params
  echo "Do you want to continue with the deployment? (y/Y to continue, any other key to cancel)"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Deployment cancelled."
    return 1
  fi
  clear
  if [ "$MS_NOSPEED" = "true" ]; then
    echo "Speed is disabled"
    NOSPEED=true
  fi
  echo "============================ Downloading FRP ==============================="
  download_latest_program "fatedier/frp" "false" "frp"
  rm -f frps
  echo "============================================================================"
  echo "========================== Downloading MiaoSpeed ==========================="
  download_latest_program "moshaoli688/miaospeed" "true" "miaospeed"
  rm -f .env.example
  echo "============================================================================"

  echo "====================== Generating Configuration Files ======================"
  generate_env_file ./.env $MS_PORT $MS_TOKEN "/$MS_PATH" "0.0.0.0" "" "" "16" "" "" "true" $NOSPEED "" "" "" ""
  generate_server_file $MS_INIT miaospeed "Miaospeed Backend" $MS_WORK_DIR_ABS/miaospeed.pro "server" $MS_WORK_DIR_ABS/.env
  enable_service $MS_INIT miaospeed
  # If you need FRP for internal network penetration, please uncomment the following line
  # generate_frpc_config ./frpc.toml $MS_UID $FRP_SERVER $FRP_SERVER_PORT $FRP_SERVER_TOKEN $FRP_SERVER_PROTOCOL "" "" "miaospeed:tcp:127.0.0.1:$MS_PORT:$MS_PORT"
  # generate_server_file $MS_INIT miaospeed_frpc "Miaospeed Frp Client " $MS_WORK_DIR_ABS/frpc "-c $MS_WORK_DIR_ABS/frpc.toml"
  # enable_service $MS_INIT miaospeed_frpc
  echo "============================================================================"

  echo "Deployment completed successfully."
  echo ""
  echo "Please copy the following configuration details and provide them to the MiaoKo administrator:"
  print_params
}
detect_architecture() {
  if ! command -v uname >/dev/null 2>&1; then
    echo "ERROR: 'uname' command not found. Unable to determine architecture." >&2
    return 1
  fi

  local arch=$(uname -m)

  case "$arch" in
  x86_64 | amd64)
    echo "amd64"
    ;;
  i386 | i686)
    echo "386"
    ;;
  aarch64 | arm64)
    echo "arm64"
    ;;
  armv7l | armv7 | armhf)
    echo "armv7"
    ;;
  armv6l | armel)
    echo "armv6"
    ;;
  mips)
    echo "mips"
    ;;
  mips64)
    echo "mips64"
    ;;
  ppc64 | ppc64le)
    echo "ppc64le"
    ;;
  riscv64)
    echo "riscv64"
    ;;
  loongarch64)
    echo "loongarch64"
    ;;
  *)
    echo "ERROR: Unsupported or unknown architecture: $arch" >&2
    return 1
    ;;
  esac

  return 0
}

detect_init_system() {
  if [ "$(detect_os)" = "darwin" ]; then
    echo "launchd"
  elif command -v systemctl >/dev/null 2>&1; then
    echo "systemd"
  elif [ -d /etc/rc.d ] || [ -f /etc/init.d/rc ]; then
    echo "sysvinit"
  elif [ -f /sbin/openrc-run ]; then
    echo "openrc"
  elif command -v initctl >/dev/null 2>&1; then
    echo "upstart"
  elif [ -d /etc/init.d ]; then
    echo "openwrt"
  else
    echo "unknown"
  fi
}
detect_os() {
  local os=$(uname -s)
  case "$os" in
  Linux) echo "linux" ;;
  Darwin) echo "darwin" ;;
  FreeBSD) echo "freebsd" ;;
  *)
    echo "ERROR: Unsupported OS: $os"
    return 1
    ;;
  esac
  return 0
}
check_cpu_support() {
  local instruction="$1"
  local os=$(uname -s)

  if [ "$os" = "Linux" ]; then
    if command -v lscpu >/dev/null 2>&1; then
      if lscpu | grep -q "$instruction"; then
        return 0
      fi
    fi
    if cat /proc/cpuinfo | grep -q "$instruction"; then
      return 0
    fi
  elif [ "$os" = "Darwin" ]; then
    if sysctl -a | grep -q "$instruction"; then
      return 0
    fi
  fi
  return 1
}

get_latest_tag() {
  local repo="$1"
  local include_pre="$2"

  if [ -z "$repo" ]; then
    echo "ERROR: Repository is required as the first argument."
    return 1
  fi

  local json=$(curl -s "https://api.github.com/repos/$repo/releases")

  if [ "$include_pre" = "true" ]; then
    echo "$json" | grep '"tag_name":' | head -n 1 | cut -f4 -d '"' | sed 's/v//g'
  else
    echo "$json" | awk '
            /"tag_name":/ { tag_name = $2 }
            /"prerelease": false/ { print tag_name }
        ' | cut -d '"' -f 2 | sed 's/v//g' | head -n 1
  fi
}

get_download_url() {
  local repo="$1"
  local tag="$2"
  local os="$3"
  local arch="$4"

  if [ -z "$repo" ] || [ -z "$tag" ] || [ -z "$os" ] || [ -z "$arch" ]; then
    echo "ERROR: Missing required arguments. Usage: get_download_url <repo> <tag> <os> <arch>" >&2
    return 1
  fi

  local json=$(curl -s "https://api.github.com/repos/$repo/releases/tags/v$tag")
  if [ -z "$json" ]; then
    echo "ERROR: Failed to fetch release data for $repo tag $tag." >&2
    return 1
  fi

  local supports_v4=""
  local supports_v3=""
  local supports_v2=""
  check_cpu_support "avx512" && supports_v4="true"
  check_cpu_support "avx2" && supports_v3="true"
  check_cpu_support "sse4_2" && supports_v2="true"
  echo "INFO: CPU support: v4=$supports_v4, v3=$supports_v3, v2=$supports_v2" >&2

  local fileurl=""

  local optimized_versions=$(echo "$json" | grep "browser_download_url" | grep "${os}_${arch}" | grep -E 'v2|v3|v4')
  if [ -n "$optimized_versions" ]; then
    echo "INFO: Optimized versions found for ${os}_${arch}." >&2

    if [ "$supports_v4" = "true" ]; then
      fileurl=$(echo "$optimized_versions" | grep "v4" | cut -d '"' -f 4)
    fi
    if [ -z "$fileurl" ] && [ "$supports_v3" = "true" ]; then
      fileurl=$(echo "$optimized_versions" | grep "v3" | cut -d '"' -f 4)
    fi
    if [ -z "$fileurl" ] && [ "$supports_v2" = "true" ]; then
      fileurl=$(echo "$optimized_versions" | grep "v2" | cut -d '"' -f 4)
    fi

    if [ -n "$fileurl" ]; then
      echo "$fileurl"
      return 0
    else
      echo "WARN: No compatible optimized version found, falling back to general version." >&2
    fi
  else
    echo "INFO: No optimized versions found for ${os}_${arch}." >&2
  fi

  local general_versions=$(echo "$json" | grep "browser_download_url" | grep "${os}_${arch}" | grep -v -E '_v[2-4]')
  if [ -n "$general_versions" ]; then
    fileurl=$(echo "$general_versions" | cut -d '"' -f 4 | head -n 1)
    if [ -n "$fileurl" ]; then
      echo "$fileurl"
      return 0
    fi
  fi
  echo $fileurl

  echo "ERROR: Failed to find a compatible download URL for ${os}_${arch}." >&2
  return 1
}

download_latest_program() {
  local repo="$1"
  local include_pre="$2"
  local program_name="$3"

  tag=$(get_latest_tag "$repo" "$include_pre")
  if [ -z "$tag" ]; then
    echo "ERROR: Failed to fetch the latest tag for $program_name."
    return 1
  fi

  echo "Latest version of $program_name: $tag"

  os=$(detect_os)
  if [ $? -ne 0 ]; then
    return 1
  fi

  arch=$MS_ARCH
  if [ $? -ne 0 ]; then
    return 1
  fi

  echo "Detected OS: $os, Architecture: $arch"

  fileurl=$(get_download_url "$repo" "$tag" "$os" "$arch")

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get download URL for $program_name."
    return 1
  fi

  echo "$program_name Release URL: $fileurl"

  file_name=$(basename "$fileurl")
  output_path="./$file_name"

  try_download() {
    url="$1"
    output="$2"
    echo "Trying to download from: $url"
    curl -fSL -o "$output" "$url"
    return $?
  }

  try_download "$fileurl" "$output_path"
  if [ $? -ne 0 ]; then
    echo "Direct download failed. Trying proxies..."
    echo "$PROXY_URLS" | tr ',' '\n' | while read proxy; do
      proxy_url="${proxy}${fileurl}"
      try_download "$proxy_url" "$output_path"
      if [ $? -eq 0 ]; then
        echo "Successfully downloaded $file_name from proxy: $proxy_url"
        break
      else
        echo "Failed to download from proxy: $proxy_url"
      fi
    done
  fi

  if [ ! -f "$output_path" ]; then
    echo "ERROR: Failed to download $file_name from all sources."
    return 1
  fi

  echo "Unzipping $program_name: $file_name"
  case "$file_name" in
  *.tar.gz | *.tgz)
    if tar -tf "$output_path" | grep -q '/'; then
      tar zxf "$output_path" --strip-components=1
    else
      tar zxf "$output_path"
    fi
    ;;
  *.tar.bz2)
    if tar -tf "$output_path" | grep -q '/'; then
      tar jxf "$output_path" --strip-components=1
    else
      tar jxf "$output_path"
    fi
    ;;
  *.zip)
    if unzip -l "$output_path" | grep -q '/'; then
      unzip -q "$output_path" -d "$MS_WORK_DIR"
    else
      unzip -q "$output_path" -d "$MS_WORK_DIR"
    fi
    ;;
  *)
    echo "ERROR: Unsupported file format for $file_name"
    return 1
    ;;
  esac

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to extract $file_name"
    return 1
  fi

  echo "$program_name extracted successfully to $MS_WORK_DIR"

  rm -f "$output_path" README.md frp*.toml LICENSE
  chmod +x $program_name*

  echo "$program_name setup completed successfully."
  return 0
}

generate_frpc_config() {
  local config_path="$1"
  local uid="$2"
  local server="$3"
  local port="$4"
  local token="$5"
  local protocol="$6"
  local tls_cert="$7"
  local tls_key="$8"
  shift 8
  local proxies="$@"

  if [ -z "$config_path" ] || [ -z "$uid" ] || [ -z "$server" ] || [ -z "$port" ] || [ -z "$token" ]; then
    echo "Usage: generate_frpc_config <config_path> <uid> <server> <port> <token> <protocol> <tls_cert> <tls_key> <proxies>"
    echo "Example: generate_frpc_config /etc/frpc.toml user1 1.2.3.4 7000 mytoken tcp /path/to/cert.pem /path/to/key.pem 'proxy1:tcp:127.0.0.1:8080:8000'"
    return 1
  fi

  {
    echo "# frpc configuration file"
    echo "# Auto-generated by generate_frpc_config"
    echo "user = \"$uid\""
    echo "serverAddr = \"$server\""
    echo "serverPort = $port"
    echo "loginFailExit = true"
    echo "log.level = \"info\""
    echo "log.disablePrintColor = false"
    echo "auth.method = \"token\""
    echo "auth.token = \"$token\""
    echo "transport.poolCount = 2"
    echo "transport.protocol = \"$protocol\""
    echo "transport.tcpMux = true"
    if [ -n "$tls_cert" ] && [ -n "$tls_key" ]; then
      echo "transport.tls.enable = true"
      echo "transport.tls.certFile = \"$tls_cert\""
      echo "transport.tls.keyFile = \"$tls_key\""
    fi
    echo "dnsServer = \"119.29.29.29\""
    echo ""

    for proxy in $proxies; do
      local name type local_ip local_port remote_port
      name=$(echo "$proxy" | cut -d':' -f1)
      type=$(echo "$proxy" | cut -d':' -f2)
      local_ip=$(echo "$proxy" | cut -d':' -f3)
      local_port=$(echo "$proxy" | cut -d':' -f4)
      remote_port=$(echo "$proxy" | cut -d':' -f5)

      echo "[[proxies]]"
      echo "name = \"$name\""
      echo "type = \"$type\""
      echo "localIP = \"$local_ip\""
      echo "localPort = $local_port"
      echo "remotePort = $remote_port"
      echo "transport.useEncryption = true"
      echo "transport.useCompression = true"
      echo ""
    done
  } >"$config_path"

  echo "FRPC configuration file generated at $config_path"
}

generate_env_file() {
  local config_path="$1"
  local port="$2"
  local token="$3"
  local path="$4"

  # Optional parameters
  local bind="$5"            # Bind address
  local allow_ips="$6"       # Allowed IP range
  local block_ips="$7"       # Blocked IP range
  local conn_threads="$8"    # Number of threads
  local speed_limit="$9"     # Speed limit
  local pause_second="${10}" # Pause seconds after each speed task
  local mtls="${11}"         # Whether to enable MTLS (Mutual TLS)
  local no_speed="${12}"     # Whether to disable speed test feature
  local task_weight="${13}"  # Whether to enable task weight
  local mmdb="${14}"         # MaxMind DB path
  local cert="${15}"         # Custom certificate path
  local key="${16}"          # Custom key path
  local whitelist="${17}"    # Whitelist of allowed users

  if [ -z "$config_path" ] || [ -z "$port" ] || [ -z "$token" ] || [ -z "$path" ]; then
    echo "Usage: generate_env_file <config_path> <port> <token> <path> [optional parameters...]"
    echo "Example: generate_env_file /path/to/.env 8080 mytoken /connect"
    return 1
  fi

  {
    echo "# .env file for MiaoSpeed Pro Server Configuration"
    echo ""
    echo "# Bind address for the server"
    echo "BIND="${bind:-0.0.0.0}:${port}""
    echo ""
    echo "# Token used to sign requests"
    echo "TOKEN=$token"
    echo ""
    echo "# Customized websocket path"
    echo "URL_PATH=$path"
    echo ""

    [ -n "$allow_ips" ] && echo "ALLOW_IPS=$allow_ips"
    [ -n "$block_ips" ] && echo "BLOCK_IPS=$block_ips"
    [ -n "$conn_threads" ] && echo "CONNTHREAD=$conn_threads"
    [ -n "$speed_limit" ] && echo "SPEEDLIMIT=$speed_limit"
    [ -n "$pause_second" ] && echo "PAUSESECOND=$pause_second"
    [ -n "$mtls" ] && echo "MTLS=$mtls"
    [ -n "$no_speed" ] && echo "NOSPEED=$no_speed"
    [ -n "$task_weight" ] && echo "TASKWEIGHT=$task_weight"
    [ -n "$mmdb" ] && echo "MMDB=$mmdb"
    [ -n "$cert" ] && [ -n "$key" ] && echo "CERT=$cert" && echo "KEY=$key"
    [ -n "$whitelist" ] && echo "WHITELIST=$whitelist"

  } >"$config_path"

  echo "MiaoSpeed .env file generated at $config_path"
}

generate_server_file() {
  local SERVICE_TYPE="$1"
  local SERVICE_NAME="$2"
  local SERVICE_DESC="$3"
  local EXEC_PATH="$4"
  local ARGS="$5"
  local ENV_FILE="$6"

  if [ -z "$SERVICE_TYPE" ] || [ -z "$SERVICE_NAME" ] || [ -z "$EXEC_PATH" ]; then
    echo "Error: Missing required arguments."
    show_usage
  fi

  if [ -z "$SERVICE_DESC" ]; then
    SERVICE_DESC="$SERVICE_NAME service"
  fi

  generate_systemd() {
    cat <<EOF >/etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=${SERVICE_DESC}
After=network.target

[Service]
Type=simple
EnvironmentFile=${ENV_FILE}
ExecStart=${EXEC_PATH} ${ARGS}
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
    echo "Systemd unit file created at /etc/systemd/system/${SERVICE_NAME}.service"
  }

  generate_openwrt() {
    cat <<EOF >/etc/init.d/${SERVICE_NAME}
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
NAME="${SERVICE_NAME}"
PROG="${EXEC_PATH}"
ARGS="${ARGS}"
ENV_FILE="${ENV_FILE}"

start_service() {
    procd_open_instance
    procd_set_param command \$PROG \$ARGS
    procd_set_param env \$(cat "\$ENV_FILE" | xargs)
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    killall \$(basename \$PROG)
}
EOF
    chmod +x /etc/init.d/${SERVICE_NAME}
    echo "OpenWrt init.d script created at /etc/init.d/${SERVICE_NAME}"
  }

  generate_sysvinit() {
    cat <<EOF >/etc/init.d/${SERVICE_NAME}
#!/bin/sh
### BEGIN INIT INFO
# Provides:          ${SERVICE_NAME}
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ${SERVICE_DESC}
# Description:       Starts the ${SERVICE_NAME} service
### END INIT INFO

case "\$1" in
    start)
        echo "Starting ${SERVICE_NAME}..."
        export \$(cat ${ENV_FILE})
        nohup ${EXEC_PATH} ${ARGS} > /var/log/${SERVICE_NAME}.log 2>&1 &
        ;;
    stop)
        echo "Stopping ${SERVICE_NAME}..."
        pkill -f "${EXEC_PATH} ${ARGS}"
        ;;
    restart)
        \$0 stop
        \$0 start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
        ;;
esac
EOF
    chmod +x /etc/init.d/${SERVICE_NAME}
    echo "SysVinit script created at /etc/init.d/${SERVICE_NAME}"
  }

  generate_openrc() {
    cat <<EOF >/etc/init.d/${SERVICE_NAME}
#!/sbin/openrc-run

description="${SERVICE_DESC}"
command="${EXEC_PATH}"
command_args="${ARGS}"
pidfile="/var/run/${SERVICE_NAME}.pid"
command_background="yes"
output_log="/var/log/${SERVICE_NAME}.log"
error_log="/var/log/${SERVICE_NAME}.err"

depend() {
    need net
}
EOF
    chmod +x /etc/init.d/${SERVICE_NAME}
    echo "OpenRC script created at /etc/init.d/${SERVICE_NAME}"
  }

  generate_upstart() {
    cat <<EOF >/etc/init/${SERVICE_NAME}.conf
description "${SERVICE_DESC}"

start on runlevel [2345]
stop on runlevel [016]

respawn
setuid root
setgid root

env ENV_FILE=${ENV_FILE}
exec env \$(cat \$ENV_FILE | xargs) ${EXEC_PATH} ${ARGS}
EOF
    echo "Upstart script created at /etc/init/${SERVICE_NAME}.conf"
  }
  generate_launchd() {
    local PLIST_PATH="/Library/LaunchDaemons/${SERVICE_NAME}.plist"
    if [ ! -w "/Library/LaunchDaemons" ]; then
      echo "Error: Unable to write to /Library/LaunchDaemons. Generating the plist file in the current directory."
      PLIST_PATH="./${SERVICE_NAME}.plist"
    fi

    cat <<EOF >"$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${SERVICE_NAME}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${EXEC_PATH}</string>
      <string>${ARGS}</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
      <key>ENV_FILE</key>
      <string>${ENV_FILE}</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardErrorPath</key>
    <string>/var/log/${SERVICE_NAME}_error.log</string>

    <key>StandardOutPath</key>
    <string>/var/log/${SERVICE_NAME}_output.log</string>
  </dict>
</plist>
EOF

    echo "Launchd plist file created at $PLIST_PATH"
  }

  case "$SERVICE_TYPE" in
  systemd)
    generate_systemd
    ;;
  openwrt)
    generate_openwrt
    ;;
  sysvinit)
    generate_sysvinit
    ;;
  openrc)
    generate_openrc
    ;;
  launchd)
    generate_launchd
    ;;
  upstart)
    generate_upstart
    ;;
  *)
    echo "Error: Unsupported service type '$SERVICE_TYPE'."
    show_usage
    ;;
  esac
}
enable_service() {
  local SERVICE_TYPE="$1"
  local SERVICE_NAME="$2"

  case "$SERVICE_TYPE" in
  systemd)
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"
    echo "Systemd service '${SERVICE_NAME}' enabled and started on boot."
    systemctl --no-pager status "${SERVICE_NAME}"
    ;;
  openwrt)
    /etc/init.d/${SERVICE_NAME} enable
    /etc/init.d/${SERVICE_NAME} start
    echo "OpenWrt service '${SERVICE_NAME}' enabled and started on boot."
    /etc/init.d/${SERVICE_NAME} status
    ;;
  sysvinit)
    update-rc.d ${SERVICE_NAME} defaults
    service ${SERVICE_NAME} start
    echo "SysVinit service '${SERVICE_NAME}' enabled and started on boot."
    service ${SERVICE_NAME} status
    ;;
  openrc)
    rc-update add ${SERVICE_NAME} default
    /etc/init.d/${SERVICE_NAME} start
    echo "OpenRC service '${SERVICE_NAME}' enabled and started on boot."
    /etc/init.d/${SERVICE_NAME} status
    ;;
  upstart)
    echo "Upstart service '${SERVICE_NAME}' does not require explicit enabling for services; ensure the config is correct."
    service ${SERVICE_NAME} start
    echo "Upstart service '${SERVICE_NAME}' started."

    service ${SERVICE_NAME} status
    ;;
  launchd)
    echo "Error: launchd services cannot be enabled or started automatically through this script on macOS."
    echo "Please manually load and start the service using the following command:"
    echo "sudo launchctl load /Library/LaunchDaemons/${SERVICE_NAME}.plist"
    echo "To start the service, run:"
    echo "sudo launchctl start ${SERVICE_NAME}"
    return 1
    ;;
  *)
    echo "Error: Unsupported service type '$SERVICE_TYPE'."
    return 1
    ;;
  esac
  return 0
}

parse_args "$@"
validate_required_params
validate_port "$MS_PORT"
handle_defaults
run_command
