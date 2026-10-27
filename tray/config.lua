-- Конфиг Lua-виджета трея.
-- Читает {"type":"tray","data":[...]} от nsbridge, рисует иконки.
--
-- Поля:
--   type      — "lua" (Lua-виджет, есть widget.lua).
--   side      — "left" | "right".
--   priority  — 0 = ближе к своему краю.
--   enabled   — true | false.
--   tooltip_enabled — показывать тултип (Title).
--
-- Длина вдоль панели НЕ задаётся здесь: виджет сам сообщает её
-- через `size:set_length(len)` в `on_socket_ready` (#items * шаг).
-- `margin` — отступ поперёк; панель даёт thickness - 2*margin.

return {
    type = "lua",
    side = "right",
    priority = 0,
    enabled = true,
    tooltip_enabled = true,
    margin = 1,
}