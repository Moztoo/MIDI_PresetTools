-- Reaper Lua Script: Panel de inserción de presets MIDI con configuración dinámica de carpeta

-- CONFIGURACIÓN GENERAL
local file_ext = ".mid"
local font_name = "Verdana"
local font_size = 18
local ini_path = reaper.GetResourcePath() .. "/MIDI_Preset_Loader.ini"

function draw_roundrect_filled(x, y, w, h, r)
    -- Rectángulo central (horizontal)
    gfx.rect(x + r, y, w - 2 * r, h, 1)

    -- Rectángulo vertical central (puente entre círculos)
    gfx.rect(x, y + r, w, h - 2 * r, 1)

    -- Esquinas redondeadas
    gfx.circle(x + r, y + r, r, 1) -- esquina superior izquierda
    gfx.circle(x + w - 1.1*r, y + r, r, 1) -- superior derecha
    gfx.circle(x + r, y + h - 1.1*r, r, 1) -- inferior izquierda
    gfx.circle(x + w - 1.1*r, y + h - 1.1*r, r, 1) -- inferior derecha
end


-- Leer o solicitar carpeta desde archivo INI
function get_midi_folder()
    local file = io.open(ini_path, "r")
    if file then
        local path = file:read("*l")
        file:close()
        if path and reaper.EnumerateFiles(path, 0) then
            return path
        end
    end

    local ret, folder = reaper.JS_Dialog_BrowseForFolder("Seleccionar carpeta de presets MIDI", reaper.GetResourcePath())
    if not ret or not folder or folder == "" then return nil end

    local save = io.open(ini_path, "w")
    if save then save:write(folder .. "\n") save:close() end
    return folder
end

local midi_folder = get_midi_folder()
if not midi_folder then
    reaper.ShowMessageBox("No se seleccionó una carpeta válida.", "Abortado", 0)
    return
end

os.execute("mkdir \"" .. midi_folder .. "\"")

-- Resto del script sigue igual...

local function natural_sort(a, b)
    local function padnum(d) return string.format("%03d", tonumber(d)) end
    local function normalize(str) return str:gsub("%d+", padnum):lower() end
    return normalize(a) < normalize(b)
end

function get_midi_files(folder)
    local files = {}
    local i = 0
    local info = reaper.EnumerateFiles(folder, i)
    while info do
        if info:lower():sub(-#file_ext) == file_ext then table.insert(files, info) end
        i = i + 1
        info = reaper.EnumerateFiles(folder, i)
    end
    table.sort(files, natural_sort)
    return files
end

function insert_midi_item(file)
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Seleccioná una pista primero.", "Error", 0)
        return
    end
    local cursor_pos = reaper.GetCursorPosition()
    reaper.SetEditCurPos(cursor_pos, false, false)
    reaper.Main_OnCommand(40289, 0) -- Unselect all items
    reaper.InsertMedia(file, 0)     -- Insert MIDI
end

-- CARGA DE ARCHIVOS Y LÓGICA UI

tooltip = nil

local all_files = get_midi_files(midi_folder)
local files = all_files
if #files == 0 then
    reaper.ShowMessageBox("No se encontraron archivos MIDI en:\n" .. midi_folder, "Sin archivos", 0)
    return
end

local width, height = 250, 600
gfx.init("MIDI Preset Loader", width, height, 0, 100, 100)
-- (ya seteado abajo)

local bg_color = {0.12, 0.12, 0.12}
local text_color = {1, 1, 1}
local hover_border = {0.6, 0.6, 0.6}
local scrollbar_color = {0.3, 0.3, 0.3}
local colors = {
    {0.2, 0.2, 0.25}, {0.25, 0.25, 0.2}, {0.3, 0.22, 0.2}
}

local search_query = ""
local search_focused = false
local blink_timer = 0
local blink_visible = true
local scroll_offset = 0
local line_height = 30
local mouse_down = false
local dragging_scrollbar = false

function filter_files()
    if search_query == "" then
        files = all_files
    else
        files = {}
        for _, f in ipairs(all_files) do
            if f:lower():find(search_query:lower(), 1, true) then
                table.insert(files, f)
            end
        end
    end
    scroll_offset = 0
end

function draw_header()
    gfx.set(0.1, 0.1, 0.1)
    gfx.rect(0, 0, width, 50, 1)
    gfx.set(1, 1, 1)
    gfx.x = 20
    gfx.y = 15
    gfx.setfont(1, font_name, font_size + 2)
    gfx.drawstr("MIDI Preset Loader")
    gfx.setfont(1, font_name, font_size)

    -- Botón para cambiar carpeta
    local btn_w, btn_h = 32, 24
    local btn_x = width - btn_w - 10
    local btn_y = 13
    gfx.set(0.2, 0.2, 0.2)
    draw_roundrect_filled(btn_x, btn_y, btn_w, btn_h,3)
    gfx.set(1, 1, 1)
    gfx.x = btn_x + 10
    gfx.y = btn_y + 3
    gfx.drawstr("☰")  -- icono estilo menú

    if gfx.mouse_cap & 1 == 1 and gfx.mouse_x > btn_x and gfx.mouse_x < btn_x + btn_w and gfx.mouse_y > btn_y and gfx.mouse_y < btn_y + btn_h and not mouse_down then
        local ok, folder = reaper.JS_Dialog_BrowseForFolder("Seleccionar nueva carpeta MIDI", reaper.GetResourcePath())
        if ok and folder and folder ~= "" then
            local save = io.open(ini_path, "w")
            if save then save:write(folder .. "") save:close() end
            midi_folder = folder
            all_files = get_midi_files(midi_folder)
            filter_files()
        end
    end
end

function draw_search_bar()
    local search_y = 50
    gfx.set(0.18, 0.18, 0.18)
    gfx.rect(10, search_y, width-20, 30, 1)
    gfx.set(0.8, 0.8, 0.8)
    gfx.circle(10, search_y + 15, 6, false)
    gfx.line(14, search_y + 19, 18, search_y + 23)
    gfx.x = 25 
    gfx.y = search_y + 6
    gfx.drawstr(search_query)
    if search_focused and blink_visible then
        local cursor_x = gfx.measurestr(search_query)
        gfx.line(25 + cursor_x, search_y + 6, 25 + cursor_x, search_y + 6 + font_size)
    end
end

function draw_file_list()
    local y = 90 - scroll_offset
    for i, file in ipairs(files) do
        local label = file:gsub("%.mid", "")
        if y > -line_height and y < height then
            local color = colors[((i - 1) % #colors) + 1]
            gfx.set(table.unpack(color))
            -- gfx.rect(10, y, width - 35, 24, 1)
            draw_roundrect_filled(10, y, width - 35, 24, 5)
            gfx.set(table.unpack(text_color))
            gfx.x = 20
            gfx.y = y + 3
            gfx.drawstr(label)

            local mouse_over = gfx.mouse_x > 10 and gfx.mouse_x < width - 30 and gfx.mouse_y > y and gfx.mouse_y < y + 24
            if mouse_over then
                gfx.set(table.unpack(hover_border))
                gfx.rect(10, y, width - 30, 24, 0)
                if gfx.mouse_cap & 1 == 1 and not mouse_down and not dragging_scrollbar then
                    insert_midi_item(midi_folder .. "/" .. file)
                end

                -- Tooltip con borde
                local file_path = midi_folder .. "/" .. file
                local f = io.open(file_path, "rb")
                if f then
                    local data = f:read("*all")
                    f:close()
                    local pc, ch = nil, nil
                    for i = 15, #data - 1 do
                        local byte = string.byte(data, i)
                        if byte >= 0xC0 and byte <= 0xCF then
                            ch = byte & 0x0F
                            pc = string.byte(data, i + 1)
                            break
                        end
                    end
                    if pc and ch then
                        local tip = "PC: " .. pc .. " | CH: " .. (ch + 1)
                        local tw, th = gfx.measurestr(tip)
                        local tx, ty = gfx.mouse_x + 10, gfx.mouse_y + 10
                        gfx.set(0, 0, 0, 0.85)
                        gfx.rect(tx - 4, ty - 2, tw + 8, th + 6, 1)
                        gfx.set(1, 1, 1)
                        gfx.x = tx
                        gfx.y = ty
                        gfx.drawstr(tip)
                        tooltip = { text = tip, x = gfx.mouse_x + 10, y = gfx.mouse_y + 10 }

                    end
                end
            end
        end
        y = y + line_height
    end
end


function draw_tooltip()
    if tooltip then
        gfx.set(0, 0, 0, 0.85)
        local tw, th = gfx.measurestr(tooltip.text)
        gfx.rect(tooltip.x - 4, tooltip.y - 2, tw + 8, th + 6, 1)
        gfx.set(1, 1, 1)
        gfx.x = tooltip.x
        gfx.y = tooltip.y
        gfx.drawstr(tooltip.text)
    end
end


function main_loop()
    local char = gfx.getchar()
    if char < 0 then gfx.quit() return end

    width, height = gfx.w, gfx.h
    local mouse_x, mouse_y = gfx.mouse_x, gfx.mouse_y
    local mouse_clicked = gfx.mouse_cap & 1 == 1

    if mouse_clicked and not mouse_down then
        if mouse_y >= 50 and mouse_y <= 80 then
            search_focused = true
        else
            search_focused = false
        end
    end

    if search_focused then
        if char >= 32 and char <= 126 then
            search_query = search_query .. string.char(char)
            filter_files()
        elseif char == 8 then
            search_query = search_query:sub(1, -2)
            filter_files()
        end
    end

    blink_timer = (blink_timer + 1) % 60
    blink_visible = blink_timer < 30

    local total_height = #files * line_height
    local preset_area_top = 90
    local preset_area_height = height - preset_area_top
    local max_scroll = math.max(0, total_height - preset_area_height)
    

    local wheel = gfx.mouse_wheel
    if wheel ~= 0 and not dragging_scrollbar then
        scroll_offset = math.min(math.max(0, scroll_offset - wheel * 10), max_scroll)
        gfx.mouse_wheel = 0
    end

    if dragging_scrollbar and not mouse_clicked then
        dragging_scrollbar = false
    elseif dragging_scrollbar and mouse_clicked then
        local bar_height = height * (height / total_height)
        local scroll_area = height - bar_height
        local relative_y = math.min(math.max(0, mouse_y - preset_area_top), scroll_area)
        scroll_offset = (relative_y / scroll_area) * max_scroll
    end

    gfx.set(table.unpack(bg_color))
    gfx.rect(0, 0, width, height, 1)
    draw_file_list()
    draw_header()
    draw_search_bar()

    if max_scroll > 0 then
        local bar_height = height * (height / total_height)
        local bar_y = preset_area_top + (scroll_offset / max_scroll) * (height - preset_area_top - bar_height)
        gfx.set(table.unpack(scrollbar_color))
        gfx.rect(width - 12, bar_y, 8, bar_height, 1)
        if mouse_clicked and not mouse_down then
            if mouse_x > width - 12 and mouse_x < width - 4 and mouse_y > bar_y and mouse_y < bar_y + bar_height then
                dragging_scrollbar = true
            end
        end
    end

    mouse_down = mouse_clicked
    draw_tooltip()
    gfx.update()
    reaper.defer(main_loop)
end

filter_files()
main_loop()

