#!/usr/bin/env bash
set -euo pipefail

source_dir=$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")
config_dir="$HOME/.config"
plugin_dir="$config_dir/omarchy/plugins/local.ring-light"

omarchy plugin validate "$source_dir"
omarchy-shell shell ping

backup_dir=$(mktemp -d "$config_dir/omarchy/ring-light-backup.XXXXXX")
for config in omarchy/shell.json hypr/bindings.lua; do
  if [[ -f "$config_dir/$config" ]]; then
    cp -p -- "$config_dir/$config" "$backup_dir/$(basename -- "$config")"
  fi
done

install -d -- "$plugin_dir"
for file in RingLight.qml Service.qml BarWidget.qml README.md manifest.json; do
  install -m 644 -- "$source_dir/$file" "$plugin_dir/$file"
done

omarchy-shell shell rescanPlugins

# Placing the widget again would replace its shell.json entry and drop the
# saved borderWidth, so only add it when it is not on the bar yet.
if omarchy plugin list --json | jq -e '.[] | select(.id == "local.ring-light" and .enabled == true)' >/dev/null; then
  echo "Ring Light is already on the bar"
else
  omarchy plugin enable local.ring-light --section right --before omarchy.monitor
fi
printf 'Installed Ring Light. Config backups: %s\n' "$backup_dir"
