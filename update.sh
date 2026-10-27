#!/bin/bash
# update.sh — обновление Lua-виджетов.
# Если виджета нет — устанавливает его полностью (config.lua + widget.lua).
# Если виджет уже есть — обновляет только widget.lua, не трогая config.lua.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/nspanel/widgets"

mkdir -p "$TARGET"

for widget_dir in "$SCRIPT_DIR"/*/; do
    [ -d "$widget_dir" ] || continue
    name="$(basename "$widget_dir")"
    [ "$name" = "." ] && continue

    if [ ! -d "$TARGET/$name" ]; then
        # Виджета нет — устанавливаем полностью.
        echo "Installing '$name' (new)..."
        mkdir -p "$TARGET/$name"
        if [ -f "$widget_dir/config.lua" ]; then
            cp -v "$widget_dir/config.lua" "$TARGET/$name/config.lua"
        fi
        if [ -f "$widget_dir/widget.lua" ]; then
            cp -v "$widget_dir/widget.lua" "$TARGET/$name/widget.lua"
        fi
    else
        # Виджет уже есть — обновляем только widget.lua.
        if [ -f "$widget_dir/widget.lua" ]; then
            echo "Updating '$name/widget.lua'..."
            cp -v "$widget_dir/widget.lua" "$TARGET/$name/widget.lua"
        else
            echo "Skipping '$name' (no widget.lua)"
        fi
    fi
done

echo "Done. New widgets installed, existing widgets updated (configs untouched)."
echo "Restart nspanel to apply."