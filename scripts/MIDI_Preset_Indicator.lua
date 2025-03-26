-- @description Indicador de Preset activo por Program Change

gfx.init("Preset Activo", 400, 130, 0, 100, 100)
gfx.setfont(1, "0xProto Nerd Font Mono", 25)

local last_preset_name = nil
local last_pc = nil
local last_ch = nil
local should_display = false
local bg_color = {0.12, 0.12, 0.12}
local color_preset = {0.2, 0.2, 0.25}
local color_chanel = {0.3, 0.22, 0.2}
local font_color = {1,1,1}

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

function draw_ui()
    gfx.set(table.unpack(bg_color))
    draw_roundrect_filled(0, 0, gfx.w, gfx.h, 3)

    gfx.set(1, 1, 1)
    gfx.x = 15
    gfx.y = 10
    if should_display and last_preset_name then
        gfx.set(table.unpack(color_preset))
        draw_roundrect_filled(gfx.x, gfx.y, gfx.w-gfx.x*2, 50, 3)
        
        gfx.x = 30
        gfx.y = gfx.y+25/2
        gfx.set(table.unpack(font_color))
        gfx.drawstr("Preset: " .. last_preset_name)
        
        gfx.x = 15
        gfx.y = 70
        
        gfx.set(table.unpack(color_chanel))
        draw_roundrect_filled(gfx.x, gfx.y, gfx.w-gfx.x*2, 50, 3)
        
        gfx.x = 30
        gfx.y = gfx.y+25/2
        gfx.set(table.unpack(font_color))
        gfx.drawstr("PC: " .. last_pc .. " | MIDI CH: " .. (last_ch + 1))
    else
        gfx.drawstr("Esperando evento PC...")
    end
    
    
end

function clean_name(str)
    local base = str:match("([^/\\]+)%.mid$") or str
    local name = base:match("^%d+_(.+)$") or base
    return name
end

function check_midi_events()
  glow_alpha = 1.0 -- reiniciar glow al máximo
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then return end

    local item_count = reaper.CountTrackMediaItems(track)
    local play_pos = reaper.GetPlayPosition()

    for i = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local end_pos = start_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        if play_pos >= start_pos and play_pos <= end_pos then
            local take = reaper.GetActiveTake(item)
            if take and reaper.TakeIsMIDI(take) then
                local _, midi_data = reaper.MIDI_GetAllEvts(take, "")
                local pos = 1

                while pos <= #midi_data - 6 do
                    local offset, flags, msg, next_pos = string.unpack("i4Bs4", midi_data, pos)
                    if msg and #msg >= 2 then
                        local status = msg:byte(1)
                        if status >= 0xC0 and status <= 0xCF then
                            local ch = status & 0x0F
                            local pc = msg:byte(2)

                            -- Evitar repeticiones si ya lo mostramos
                            if pc ~= last_pc or ch ~= last_ch then
                                last_pc = pc
                                last_ch = ch
                                -- Obtener nombre limpio del preset
                                local name = reaper.GetTakeName(take)
                                if not name or name == "" then
                                    local source = reaper.GetMediaItemTake_Source(take)
                                    name = reaper.GetMediaSourceFileName(source, "")
                                end
                                last_preset_name = clean_name(name)
                                should_display = true
                            end
                        end
                    end
                    pos = next_pos or (#midi_data + 1)
                end
            end
        end
    end
end

function main()
    if gfx.getchar() < 0 then return end

    check_midi_events()
    draw_ui()

    gfx.update()
    reaper.defer(main)
end

main()

