-- VLC Credit Skipper - Enhanced Version with Timestamp Segments

function descriptor()
    return {
        title = "Credit Skipper",
        version = "1.1.0",
        author = "Michael Bull + livycus",
        url = "https://github.com/michaelbull/vlc-credit-skipper + https://github.com/livycus/vlc-credit-skipper-plus",
        shortdesc = "Skip Intro/Outro Segments",
        description = "Skip specific intro and credit segments in VLC playlists.",
        capabilities = {}
    }
end

function activate()
    profiles = {}
    config_file = vlc.config.configdir() .. "/credit-skipper.conf"

    if file_exists(config_file) then
        load_all_profiles()
    end

    open_dialog()
end

function deactivate()
    dialog:delete()
end

function close()
    vlc.deactivate()
end

function meta_changed()
end

function open_dialog()
    dialog = vlc.dialog(descriptor().title)

    dialog:add_label("<center><h3>Profile</h3></center>", 1, 1, 2, 1)
    dialog:add_button("Load", populate_profile_fields, 1, 3, 1, 1)
    dialog:add_button("Delete", delete_profile, 2, 3, 1, 1)

    dialog:add_label("", 1, 4, 2, 1)
    dialog:add_label("<center><h3>Settings</h3></center>", 1, 5, 2, 1)

    dialog:add_label("Profile name:", 1, 6, 1, 1)
    profile_name_input = dialog:add_text_input("", 2, 6, 1, 1)

    dialog:add_label("Intro Start Time (s):", 1, 7, 1, 1)
    intro_start_input = dialog:add_text_input("", 2, 7, 1, 1)

    dialog:add_label("Intro End Time (s):", 1, 8, 1, 1)
    intro_end_input = dialog:add_text_input("", 2, 8, 1, 1)

    dialog:add_label("Credits Start Time (s):", 1, 9, 1, 1)
    credits_start_input = dialog:add_text_input("", 2, 9, 1, 1)

    dialog:add_label("Credits End Time (s):", 1, 10, 1, 1)
    credits_end_input = dialog:add_text_input("", 2, 10, 1, 1)

    dialog:add_button("Save", save_profile, 1, 11, 2, 1)

    dialog:add_label("", 1, 12, 2, 1)
    dialog:add_label("<center><strong>Ensure your playlist is queued<br/>before pressing start.</strong></center>", 1, 13, 2, 1)
    dialog:add_button("Start Playlist", start_playlist, 1, 14, 2, 1)

    populate_profile_dropdown()
    populate_profile_fields()
end

function populate_profile_dropdown()
    profile_dropdown = dialog:add_dropdown(1, 2, 2, 1)

    for i, profile in pairs(profiles) do
        profile_dropdown:add_value(profile.name, i)
    end
end

function populate_profile_fields()
    local profile = profiles[profile_dropdown:get_value()]

    if profile then
        profile_name_input:set_text(profile.name)
        intro_start_input:set_text(tostring(profile.intro_start or 0))
        intro_end_input:set_text(tostring(profile.intro_end or 0))
        credits_start_input:set_text(tostring(profile.credits_start or 0))
        credits_end_input:set_text(tostring(profile.credits_end or 0))
    end
end

function delete_profile()
    local dropdown_value = profile_dropdown:get_value()

    if profiles[dropdown_value] then
        profiles[dropdown_value] = nil
        save_all_profiles()
    end
end

function save_profile()
    if profile_name_input:get_text() == "" then return end

    local name = profile_name_input:get_text()
    local intro_start = tonumber(intro_start_input:get_text()) or 0
    local intro_end = tonumber(intro_end_input:get_text()) or 0
    local credits_start = tonumber(credits_start_input:get_text()) or 0
    local credits_end = tonumber(credits_end_input:get_text()) or 0

    local updated_existing = false
    for _, profile in pairs(profiles) do
        if profile.name == name then
            profile.intro_start = intro_start
            profile.intro_end = intro_end
            profile.credits_start = credits_start
            profile.credits_end = credits_end
            updated_existing = true
        end
    end

    if not updated_existing then
        table.insert(profiles, {
            name = name,
            intro_start = intro_start,
            intro_end = intro_end,
            credits_start = credits_start,
            credits_end = credits_end
        })
    end

    save_all_profiles()
end

function start_playlist()
    local playlist = vlc.playlist.get("playlist", false)
    local children = {}

    for _, child in pairs(playlist.children) do
        if child.duration ~= -1 then
            table.insert(children, {
                path = child.path,
                name = child.name,
                duration = child.duration
            })
        end
    end

    vlc.playlist.clear()

    local profile = profiles[profile_dropdown:get_value()]

    if not profile then return end

    for _, child in pairs(children) do
        local segments = {}

        local function is_valid(a, b)
            return a and b and a < b and b <= child.duration
        end

        if is_valid(0, profile.intro_start) then
            table.insert(segments, {start=0, stop=profile.intro_start})
        end
        if is_valid(profile.intro_end, profile.credits_start) then
            table.insert(segments, {start=profile.intro_end, stop=profile.credits_start})
        end
        if is_valid(profile.credits_end, child.duration) then
            table.insert(segments, {start=profile.credits_end, stop=child.duration})
        end

        for _, segment in ipairs(segments) do
            local options = {
                "start-time=" .. segment.start,
                "stop-time=" .. segment.stop
            }

            vlc.playlist.enqueue({
                {
                    path = child.path,
                    name = child.name .. string.format(" [%.0f-%.0f]", segment.start, segment.stop),
                    duration = segment.stop - segment.start,
                    options = options
                }
            })
        end
    end

    dialog:hide()
    vlc.playlist.play()
end

function save_all_profiles()
    io.output(config_file)
    for _, profile in pairs(profiles) do
        io.write(profile.name .. "=" .. profile.intro_start .. "," .. profile.intro_end .. "," .. profile.credits_start .. "," .. profile.credits_end .. "\n")
    end
    io.close()

    dialog:del_widget(profile_dropdown)
    populate_profile_dropdown()
end

function load_all_profiles()
    local lines = lines_from(config_file)

    for _, line in pairs(lines) do
        for name, a, b, c, d in string.gmatch(line, "(.+)=(%d+),(%d+),(%d+),(%d+)") do
            table.insert(profiles, {
                name = name,
                intro_start = tonumber(a),
                intro_end = tonumber(b),
                credits_start = tonumber(c),
                credits_end = tonumber(d)
            })
        end
    end
end

function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

function lines_from(file)
    local lines = {}
    for line in io.lines(file) do
        lines[#lines + 1] = line
    end
    return lines
end
