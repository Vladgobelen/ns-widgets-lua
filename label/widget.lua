-- Виджет label на Lua. Просто текст по центру.

local M = {}

M.size_mode = "stretch"
M.margin = 1
M.ratio = 2.0

M.render = function(state, area, theme)
    local text = state.text or ""
    buf:text_centered(area, text, theme.fg, theme.font_size)
end

M.on_click = function(state, x, y)
    return { type = "log", msg = "label clicked" }
end

M.menu_items = function()
    return {
        { label = "Настройки label", action = { type = "log", msg = "label settings" } },
    }
end

return M