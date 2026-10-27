-- Конфиг Lua-виджета часов.
-- Копируется в ~/.config/nspanel/widgets/clock/config.lua при установке.
--
-- Поля:
--   type      — "lua" (Lua-виджет, есть widget.lua).
--   side      — "left" | "right".
--   priority  — 0 = ближе к своему краю, дальше по возрастанию.
--   enabled   — true | false — включён ли виджет.
--   format    — формат времени (chrono-строка): "%H:%M", "%H:%M:%S".

return {
    type = "lua",
    side = "left",
    priority = 0,
    enabled = true,
    format = "%H:%M",
}