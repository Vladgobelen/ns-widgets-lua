-- Конфиг Lua-виджета таскбара (window_list_rust, но на Lua).
-- Читает группы от nsbridge, рисует иконки, клик → toggle.
--
-- Поля:
--   type             — "lua" (Lua-виджет, есть widget.lua).
--   side             — "left" | "right".
--   priority         — 0 = ближе к своему краю, дальше по возрастанию.
--   enabled          — true | false — включён ли виджет.
--   tooltip_enabled  — true | false — показывать ли тултип при hover.
--
-- Длина вдоль панели НЕ задаётся здесь: виджет сам сообщает её
-- через `size:set_length(len)` в `on_socket_ready`/`on_custom_action`
-- (#items * шаг). `margin` — отступ поперёк; панель даёт thickness - 2*margin.

return {
    type = "lua",
    side = "left",
    priority = 10,
    enabled = true,
    tooltip_enabled = true,
    margin = 1,
}