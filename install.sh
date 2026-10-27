#!/bin/bash
# Установщик Lua-виджетов в ~/.config/nspanel/widgets/.
# Использование: ./install.sh
# Перезаписывает существующие файлы (если не хочешь — закомментируй cp).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nspanel/widgets"

mkdir -p "$TARGET"

for widget_dir in "$SCRIPT_DIR"/*/; do
    [ -d "$widget_dir" ] || continue
    name="$(basename "$widget_dir")"
    [ "$name" = "." ] && continue

    echo "Installing '$name'..."
    mkdir -p "$TARGET/$name"
    cp -v "$widget_dir/config.lua" "$TARGET/$name/config.lua"
    if [ -f "$widget_dir/widget.lua" ]; then
        cp -v "$widget_dir/widget.lua" "$TARGET/$name/widget.lua"
    fi
done

echo "Done. Widgets installed to $TARGET"
echo "Restart nspanel to apply."