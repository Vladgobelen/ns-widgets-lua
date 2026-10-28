-- Lua-таскбар.

local M = {}

M.size_mode = "fixed"
M.margin = 1

local ICON_SIZE = 28
local ICON_GAP = 4
local MIN_LENGTH = 32
local PIN_FILE = os.getenv("HOME") .. "/.config/nspanel/widgets/window_list_rust/pinned.json"

local function log(fmt, ...)
    io.stderr:write(string.format("[wl] " .. fmt .. "\n", ...))
end

local function load_pinned()
    local f = io.open(PIN_FILE, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    if ok and type(data) == "table" then return data end
    return {}
end

local function save_pinned(pinned)
    local f = io.open(PIN_FILE, "w")
    if not f then return false end
    f:write(json.encode(pinned))
    f:close()
    return true
end

local function find_pinned(pinned, key)
    for i, p in ipairs(pinned) do
        if p.key == key then return i, p end
    end
    return nil, nil
end

local function item_icon_path(item)
    if item.group and item.group.windows then
        for _, w in ipairs(item.group.windows) do
            if w.icon_path and w.icon_path ~= "" then
                return w.icon_path
            end
        end
    end
    if item.icon_path and item.icon_path ~= "" then
        return item.icon_path
    end
    return nil
end

local function ensure_icon(state, item)
    if state.icons[item.key] ~= nil then
        return state.icons[item.key]
    end
    local icon_path = item_icon_path(item)
    if not icon_path then
        state.icons[item.key] = false
        return false
    end
    local pixels = img:load(icon_path, ICON_SIZE, "bilinear")
    if pixels then
        state.icons[item.key] = pixels
        return pixels
    end
    state.icons[item.key] = false
    return false
end

local function groups_equal(a, b)
    if a == nil or b == nil then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        local x, y = a[i], b[i]
        if x.key ~= y.key
            or x.has_active ~= y.has_active
            or x.all_hidden ~= y.all_hidden then
            return false
        end
        local ix = item_icon_path({ group = x })
        local iy = item_icon_path({ group = y })
        if ix ~= iy then return false end
    end
    return true
end

local function build_items(state)
    local pinned = state.pinned or {}
    local groups = state.groups or {}
    local items = {}
    local seen_keys = {}

    for _, p in ipairs(pinned) do
        local live_group = nil
        for _, g in ipairs(groups) do
            if g.key == p.key then live_group = g; break end
        end
        table.insert(items, {
            key = p.key, label = p.label, group = live_group,
            cmd = p.cmd, icon_path = p.icon_path,
        })
        seen_keys[p.key] = true
    end

    for _, g in ipairs(groups) do
        if not seen_keys[g.key] then
            table.insert(items, {
                key = g.key, label = g.label, group = g,
                cmd = nil, icon_path = nil,
            })
            seen_keys[g.key] = true
        end
    end
    return items
end

local function items_equal(a, b)
    if a == nil or b == nil then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        local x, y = a[i], b[i]
        if x.key ~= y.key or x.label ~= y.label then return false end
        if (x.group == nil) ~= (y.group == nil) then return false end
        if x.group and y.group then
            if x.group.has_active ~= y.group.has_active
                or x.group.all_hidden ~= y.group.all_hidden then
                return false
            end
            if item_icon_path(x) ~= item_icon_path(y) then return false end
        elseif x.group == nil and y.group == nil then
            if item_icon_path(x) ~= item_icon_path(y) then return false end
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

local function refresh_pinned_icons(state)
    local pinned = state.pinned or {}
    local groups = state.groups or {}
    local changed = false
    for _, p in ipairs(pinned) do
        for _, g in ipairs(groups) do
            if g.key == p.key then
                local new_icon = nil
                for _, w in ipairs(g.windows or {}) do
                    if w.icon_path and w.icon_path ~= "" then
                        new_icon = w.icon_path
                        break
                    end
                end
                if new_icon and new_icon ~= p.icon_path then
                    p.icon_path = new_icon
                    changed = true
                end
                break
            end
        end
    end
    if changed then save_pinned(pinned) end
    return changed
end

M.on_socket_ready = function(state)
    if not state.pinned then state.pinned = load_pinned() end
    if not state.icons then state.icons = {} end
    if not socket then return end
    local frames = socket:read()
    for _, frame in ipairs(frames) do
        local ok, data = pcall(json.decode, frame)
        if ok and data and data.type == "groups" then
            local new_groups = data.data or {}
            if not groups_equal(state.groups, new_groups) then
                state.groups = new_groups
                state.icons = {}
                refresh_pinned_icons(state)
                local items = build_items(state)
                if not state.items or not items_equal(state.items, items) then
                    state.items = items
                    state.hovered_index = nil
                    apply_length(state, items)
                end
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

local function index_at(state, vertical, x, y)
    if not state.items then return nil end
    local n = #state.items
    if n == 0 then return nil end
    local index
    if vertical then
        index = math.floor(y / (ICON_SIZE + ICON_GAP)) + 1
    else
        index = math.floor(x / (ICON_SIZE + ICON_GAP)) + 1
    end
    if index > n then index = n end
    if index < 1 then index = 1 end
    if state.items[index] then
        return index
    end
    return nil
end

local function first_visible_window(group)
    if not group or not group.windows then return nil end
    for _, w in ipairs(group.windows) do
        if not w.is_hidden then return w end
    end
    return nil
end

local function first_window(group)
    if not group or not group.windows then return nil end
    if #group.windows > 0 then return group.windows[1] end
    return nil
end

M.render = function(state, area, theme)
    M._state = state
    dnd:update(area)

    if not state._dnd_registered then
        state._dnd_registered = true
        dnd:set_on_hover(function(x, y, accepts)
            local st = M._state
            if not st then return false end
            if not accepts then
                if st.drag_index ~= nil then
                    st.drag_index = nil
                    return true
                end
                return false
            end
            local vertical = st.vertical or false
            local idx = nil
            if x >= 0 and y >= 0 then
                idx = index_at(st, vertical, x, y)
            end
            if st.drag_index == idx then return false end
            st.drag_index = idx
            if idx then
                local item = st.items and st.items[idx]
                if item and item.group then
                    local win = first_visible_window(item.group)
                    if win and socket then
                        local msg = json.encode({ type = "activate", id = win.id })
                        socket:write(string.pack(">I4", #msg) .. msg)
                    end
                end
            end
            return true
        end)
        dnd:set_on_drop(function(x, y)
            local st = M._state
            if not st then return false end
            st.drag_index = nil
            local vertical = st.vertical or false
            if not st.items then return false end
            local idx = index_at(st, vertical, x, y)
            if not idx then return false end
            local item = st.items[idx]
            if not item or not item.group then return false end
            local win = first_visible_window(item.group) or first_window(item.group)
            if not win then return false end
            local exe = win.exe_path or ""
            if exe == "" then
                log("on_drop: exe_path empty for %s", win.class or "?")
                return false
            end
            log("on_drop -> exe=%s", exe)
            return exe
        end)
        log("dnd callbacks registered")
    end

    if not state.pinned then state.pinned = load_pinned() end
    if not state.icons then state.icons = {} end
    if not state.items then state.items = build_items(state) end

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

        local bg, fg
        if item.group == nil then
            bg = Color.rgb(0x18, 0x18, 0x18)
            fg = Color.rgb(0x40, 0x40, 0x40)
        elseif item.group.has_active then
            bg = Color.rgb(0x80, 0x80, 0x80)
            fg = theme.fg
        elseif item.group.all_hidden then
            bg = Color.rgb(0x20, 0x20, 0x20)
            fg = Color.rgb(0x50, 0x50, 0x50)
        else
            bg = Color.rgb(0x38, 0x38, 0x38)
            fg = theme.fg
        end

        if state.hovered_index == i and (item.group == nil or not item.group.has_active) then
            bg = Color.rgb(0x60, 0x60, 0x60)
        end

        if state.drag_index == i then
            bg = Color.rgb(0x40, 0x80, 0xc0)
        end

        local btn = Rect.new(btn_x, btn_y, ICON_SIZE, ICON_SIZE)
        buf:fill_rect(btn, bg)

        local pixels = ensure_icon(state, item)
        if pixels then
            buf:draw_pixels(btn_x, btn_y, ICON_SIZE, ICON_SIZE, pixels)
        else
            local label = item.label or "?"
            local tw = math.floor(font:text_width(label, theme.font_size))
            local tx = btn_x + math.floor((ICON_SIZE - tw) / 2)
            local ty = btn_y + math.floor((ICON_SIZE - theme.font_size) / 2)
            buf:draw_text(tx, ty, label, fg, theme.font_size)
        end
    end
end

M.on_click = function(state, x, y)
    local vertical = state.vertical or false
    if not state.items then return nil end
    local index = index_at(state, vertical, x, y)
    if not index then return nil end
    local item = state.items[index]
    if not item then return nil end

    if item.group == nil then
        if item.cmd and item.cmd ~= "" then os.execute(item.cmd .. " &") end
        return nil
    end

    local target = first_visible_window(item.group) or first_window(item.group)
    if not target then return nil end

    if socket then
        local msg = json.encode({ type = "toggle", id = target.id })
        socket:write(string.pack(">I4", #msg) .. msg)
    end
    return nil
end

M.on_hover = function(state, x, y)
    local new_idx = nil
    local vertical = state.vertical or false
    if x >= 0 and y >= 0 then
        new_idx = index_at(state, vertical, x, y)
    end
    if state.hovered_index == new_idx then return false end
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

    if item.group == nil then
        local lines = { item.label .. " (закрыто)" }
        if item.cmd then lines[2] = item.cmd end
        return lines
    end

    local target = nil
    for _, w in ipairs(item.group.windows or {}) do
        if not w.is_hidden and w.is_active then target = w; break end
    end
    if not target then
        for _, w in ipairs(item.group.windows or {}) do
            if not w.is_hidden then target = w; break end
        end
    end
    if not target and item.group.windows and #item.group.windows > 0 then
        target = item.group.windows[1]
    end
    if not target then return nil end

    local title = target.title or ""
    if title == "" then title = target.class or "" end
    if title == "" then title = "?" end
    local exe = target.exe_path or ""

    local lines = { title }
    if exe ~= "" then lines[2] = exe end
    return lines
end

M.menu_items = function(state, x, y)
    if not state.pinned then state.pinned = load_pinned() end
    if not state.icons then state.icons = {} end
    if not state.items then state.items = build_items(state) end

    local vertical = state.vertical or false
    local index = index_at(state, vertical, x, y)
    if not index then return {} end
    local item = state.items[index]
    if not item then return {} end

    local pinned = state.pinned or {}
    local idx, _ = find_pinned(pinned, item.key)

    local out = {}
    if idx then
        table.insert(out, { label = "Открепить", action = { type = "custom", msg = "unpin:" .. item.key } })
    else
        local exe = ""
        if item.group and item.group.windows and item.group.windows[1] then
            exe = item.group.windows[1].exe_path or ""
        end
        local icon = item_icon_path(item) or ""
        table.insert(out, {
            label = "Закрепить",
            action = { type = "custom", msg = "pin:" .. item.key .. "|" .. item.label .. "|" .. exe .. "|" .. icon },
        })
    end
    table.insert(out, { label = "Обновить", action = { type = "log", msg = "refresh" } })
    return out
end

M.on_custom_action = function(state, msg)
    local pinned = state.pinned or load_pinned()

    if msg:sub(1, 4) == "pin:" then
        local rest = msg:sub(5)
        local parts = {}
        for part in rest:gmatch("([^|]*)") do
            table.insert(parts, part)
        end
        local key = parts[1]
        local label = parts[2]
        local cmd = parts[3]
        local icon = parts[4]

        if not key or key == "" then return false end
        local idx, _ = find_pinned(pinned, key)
        if idx then return false end

        table.insert(pinned, { key = key, label = label or "?", cmd = cmd or "", icon_path = icon or "" })
        state.pinned = pinned
        save_pinned(pinned)

        local items = build_items(state)
        state.items = items
        apply_length(state, items)
        log("pinned: %s", key)
        return true
    elseif msg:sub(1, 6) == "unpin:" then
        local key = msg:sub(7)
        local idx, _ = find_pinned(pinned, key)
        if not idx then return false end

        table.remove(pinned, idx)
        state.pinned = pinned
        save_pinned(pinned)

        local items = build_items(state)
        state.items = items
        apply_length(state, items)
        log("unpinned: %s", key)
        return true
    end
    return false
end

return M