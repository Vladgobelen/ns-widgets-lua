-- Виджет часов на Lua.
-- Использует инструменты панели: now_hm(), now_hms(), buf:text_centered(),
-- fmt_time (если есть в API). Пока — простой формат через os.date.

local M = {}

M.size_mode = "stretch"
M.margin = 1
M.ratio = 2.0

M.render = function(state, area, theme)
    local text = state.last or ""
    buf:text_centered(area, text, theme.fg, theme.font_size)
end

M.update = function(state)
    state.last = os.date("%H:%M")
    -- Через сколько секунд следующая минута.
    local sec = tonumber(os.date("%S")) or 0
    local secs_left = 60 - sec
    if secs_left < 1 then secs_left = 1 end
    return secs_left * 1000
end

M.on_click = function(state, x, y)
    return { type = "log", msg = "clock clicked at " .. os.date("%H:%M:%S") }
end

M.menu_items = function()
    return {
        { label = "Настройки часов", action = { type = "log", msg = "clock settings" } },
        { label = "Скрыть часы",     action = { type = "log", msg = "clock hide" } },
    }
end

return M