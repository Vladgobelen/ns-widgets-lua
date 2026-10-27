-- Виджет трея.
--
-- on_click/on_hover/tooltip/menu_items получают x,y ЛОКАЛЬНЫЕ для виджета.
-- index_at не вычитает area.

local M = {}

M.size_mode = "fixed"
M.margin = 1

local ICON_SIZE = 22
local ICON_GAP = 2
local MIN_LENGTH = 32

local function items_equal(a, b)
    if a == nil or b == nil then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        local x, y = a[i], b[i]
        if x.dest ~= y.dest
            or x.path ~= y.path
            or x.title ~= y.title
            or x.icon_path ~= y.icon_path
            or x.needs_attention ~= y.needs_attention
            or x.status ~= y.status then
            return false
        end
    end
    return true
end

local function compute_length(items)
    local len = #items * (ICON_SIZE + ICON_GAP)
    if len < MIN_LENGTH then len = MIN_LENGTH end
    return len
end

local function apply_length(state, items)
    local len = compute_length(items)
    if state.length ~= len then
        state.length = len
        size:set_length(len)
    end
end

M.on_socket_ready = function(state)
    if not state.icons then
        state.icons = {}
    end
    if not socket then return end
    local frames = socket:read()
    for _, frame in ipairs(frames) do
        local ok, data = pcall(json.decode, frame)
        if ok and data and data.type == "tray" then
            local new_items = data.data or {}
            if not items_equal(state.items, new_items) then
                state.items = new_items
                state.icons = {}
                state.hovered_index = nil
                apply_length(state, new_items)
            end
        end
    end
end

local function icon_x(area, vertical, index)
    if vertical then
        return area.x + math.floor((area.w - ICON_SIZE) / 2)
    end
    return area.x + (index - 1) * (ICON_SIZE + ICON_GAP)
end

local function icon_y(area, vertical, index)
    if vertical then
        return area.y + (index - 1) * (ICON_SIZE + ICON_GAP)
    end
    return area.y + math.floor((area.h - ICON_SIZE) / 2)
end

M.render = function(state, area, theme)
    if not state.icons then state.icons = {} end
    if not state.items then
        state.items = {}
    end

    local vertical = area.h > area.w
    state.vertical = vertical
    state.area = area

    local items = state.items or {}

    for i, item in ipairs(items) do
        local btn_x = icon_x(area, vertical, i)
        local btn_y = icon_y(area, vertical, i)

        if vertical then
            if btn_y + ICON_SIZE > area.y + area.h then break end
        else
            if btn_x + ICON_SIZE > area.x + area.w then break end
        end

        local bg = Color.rgb(0x30, 0x30, 0x30)
        if item.needs_attention then
            bg = Color.rgb(0x80, 0x40, 0x20)
        end
        if state.hovered_index == i then
            bg = Color.rgb(0x60, 0x60, 0x60)
        end

        local btn = Rect.new(btn_x, btn_y, ICON_SIZE, ICON_SIZE)
        buf:fill_rect(btn, bg)

        local pixels = nil
        if item.icon_path and item.icon_path ~= "" then
            local cached = state.icons[item.icon_path]
            if cached == nil then
                cached = img:load(item.icon_path, ICON_SIZE, "bilinear") or false
                state.icons[item.icon_path] = cached
            end
            if cached ~= false then
                pixels = cached
            end
        end

        if pixels then
            buf:draw_pixels(btn_x, btn_y, ICON_SIZE, ICON_SIZE, pixels)
        else
            local label = "?"
            if item.title and item.title ~= "" then
                label = item.title:sub(1, 1)
            end
            local tw = math.floor(font:text_width(label, theme.font_size))
            local tx = btn_x + math.floor((ICON_SIZE - tw) / 2)
            local ty = btn_y + math.floor((ICON_SIZE - theme.font_size) / 2)
            buf:draw_text(tx, ty, label, theme.fg, theme.font_size)
        end
    end
end

local function index_at(state, vertical, x, y)
    if not state.items then return nil end
    local index
    if vertical then
        index = math.floor(y / (ICON_SIZE + ICON_GAP)) + 1
    else
        index = math.floor(x / (ICON_SIZE + ICON_GAP)) + 1
    end
    if state.items[index] then
        return index
    end
    return nil
end

M.on_click = function(state, x, y)
    local vertical = state.vertical or false
    if not state.items then return nil end
    local index = index_at(state, vertical, x, y)
    if not index then return nil end
    local item = state.items[index]
    if not item then return nil end

    if socket then
        local msg = json.encode({
            type = "tray_click",
            dest = item.dest,
            path = item.path,
            button = 1,
            x = 0,
            y = 0,
        })
        local frame = string.pack(">I4", #msg) .. msg
        socket:write(frame)
    end
    return nil
end

M.on_hover = function(state, x, y)
    local new_idx = nil
    local vertical = state.vertical or false
    if x >= 0 and y >= 0 then
        new_idx = index_at(state, vertical, x, y)
    end
    if state.hovered_index == new_idx then
        return false
    end
    state.hovered_index = new_idx
    return true
end

M.tooltip = function(state, x, y)
    local vertical = state.vertical or false
    if x < 0 or y < 0 then return nil end
    local index = index_at(state, vertical, x, y)
    if not index then return nil end
    local item = state.items[index]
    if not item then return nil end

    local lines = {}
    if item.title and item.title ~= "" then
        lines[1] = item.title
    end
    if item.status and item.status ~= "" then
        lines[#lines + 1] = "status: " .. item.status
    end
    if #lines == 0 then
        return nil
    end
    return lines
end

M.menu_items = function(state, x, y)
    if not state.items then return {} end
    local vertical = state.vertical or false
    local index = index_at(state, vertical, x, y)
    if not index then return {} end
    local item = state.items[index]
    if not item then return {} end

    return {
        { label = "Контекстное меню", action = { type = "log", msg = "tray: context menu" } },
        { label = "Закрыть", action = { type = "log", msg = "tray: close" } },
    }
end

return M