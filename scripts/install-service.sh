#!/usr/bin/env bash
set -Eeuo pipefail

port="${1:-5078}"
[[ "$port" =~ ^[0-9]+$ ]] && (( 10#$port >= 1 && 10#$port <= 65535 )) || {
  echo "Usage: $0 [port] (port must be between 1 and 65535)" >&2
  exit 2
}

if (( EUID != 0 )); then
  echo 'Run this script as root (for example, with sudo).' >&2
  exit 1
fi

script_dir="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
publish_directory="$(cd -- "$script_dir/.." && pwd)"
application="$publish_directory/MyPostman.Api.dll"
data_directory="$publish_directory/App_Data"
service_name='mypostman.service'
service_user='mypostman'
unit_file="/etc/systemd/system/$service_name"
listen_url="http://127.0.0.1:$port"

[[ -f "$application" ]] || {
  echo "Published application not found: $application. Keep this script in the scripts directory of the published application." >&2
  exit 1
}
command -v systemctl >/dev/null || { echo 'systemd is required.' >&2; exit 1; }
command -v dotnet >/dev/null || { echo '.NET 8 runtime is required.' >&2; exit 1; }
dotnet_path="$(command -v dotnet)"

if systemctl list-unit-files "$service_name" --no-legend 2>/dev/null | grep -q "^$service_name"; then
  systemctl stop "$service_name"
fi
if ! id "$service_user" >/dev/null 2>&1; then
  useradd --system --home-dir "$data_directory" --shell /usr/sbin/nologin "$service_user"
fi
install -d -o "$service_user" -g "$service_user" -m 0750 "$data_directory"
chown -R "$service_user:$service_user" "$data_directory"

cat > "$unit_file" <<UNIT
[Unit]
Description=MyPostman API Workspace
After=network.target

[Service]
Type=notify
User=$service_user
Group=$service_user
WorkingDirectory=$publish_directory
ExecStart="$dotnet_path" "$application"
Environment="MyPostman__DataDirectory=$data_directory"
Environment="MyPostman__ListenUrl=$listen_url"
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths="$data_directory"
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now "$service_name"
echo "MyPostman service installed and running at $listen_url"
echo "Application directory: $publish_directory"
echo "Data directory: $data_directory"
