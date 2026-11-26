local mp = require 'mp'
local utils = require 'mp.utils'
local settings = {}
local theme_catalog = dofile(mp.command_native({'expand-path','~~/quick-theme.lua'}))
local file = mp.command_native({'expand-path', '~~/quick-preferences.conf'})
local prefix = 'script-opts-append=quick-ui-thumbnails='

local video_defaults = {['rtx-upscaling']='no',['rtx-hdr']='no',['video-output']='auto'}
local filter_profiles = {
    no={yes='quick-rtx-hdr'},
    yes={no='quick-rtx-vsr',yes='quick-rtx-both'},
}
local output_profiles = {sdr='quick-output-sdr',hdr='quick-output-hdr'}
local video_profiles = {['quick-hdr-passthrough']={['video-output']='hdr'}}
for upscaling,profiles in pairs(filter_profiles) do
    for hdr,name in pairs(profiles) do
        video_profiles[name]={['rtx-upscaling']=upscaling,['rtx-hdr']=hdr}
    end
end
for output,name in pairs(output_profiles) do
    video_profiles[name]={['video-output']=output}
end

local function row(label, option, choices, when)
    return {label=label, option=option, choices=choices, when=when}
end

local toggle = {{'yes','On'}, {'no','Off'}}
settings.pages = {
    {name='Playback', icon='play', rows={
        row('Remember settings', 'remember-settings', toggle),
        row('Resume playback', 'save-position-on-quit', toggle),
        row('Loop current file', 'loop-file', {{'no','Off'},{'inf','On'}}),
        row('After the last file', 'keep-open', {{'yes','Keep open'},{'no','Close media'}}),
        row('Timeline thumbnails', 'thumbnails', toggle),
    }},
    {name='Video', icon='screen', rows={
        row('Hardware decoding', 'hwdec', {{'auto-safe','Automatic'},{'no','Off'},{'d3d11va','Direct3D 11'},{'nvdec','NVIDIA NVDEC'}}, 'Next file'),
        row('Always on top', 'ontop', toggle),
        row('Resize window to fit video', 'auto-window-resize', toggle),
        row('Reduce color banding', 'deband', toggle),
        row('RTX upscaling', 'rtx-upscaling', {{'yes','On (2×)'},{'no','Off'}}, 'Restart required'),
        row('RTX HDR', 'rtx-hdr', toggle, 'Restart required'),
        row('Display output', 'video-output', {{'auto','Automatic'},{'sdr','SDR'},{'hdr','HDR'}}, 'Restart required'),
    }},
    {name='Audio', icon='volume', rows={
        row('Startup volume', 'volume', {{'25','25%'},{'50','50%'},{'75','75%'},{'100','100%'}}),
        row('Start muted', 'mute', toggle),
        row('Audio track mode', 'audio-mode', {{'single','Single track'},{'mix','Mix all tracks'}}),
    }},
    {name='Subtitles', icon='captions', rows={
        row('Show subtitles', 'sub-visibility', toggle),
        row('Subtitle size', 'sub-scale', {{'0.8','Small'},{'1','Default'},{'1.2','Large'},{'1.5','Extra large'}}),
        row('Load external subtitles', 'sub-auto', {{'exact','Exact match'},{'fuzzy','Similar names'},{'all','All in folder'},{'no','Off'}}, 'Next file'),
    }},
    {name='Appearance', icon='appearance', rows={
        row('Interface theme', 'theme', theme_catalog.choices),
    }},
    {name='Advanced', icon='gear', rows={
        {label='Check for MPV updates', action=function() settings.check_updates() end},
        row('Graphics backend', 'gpu-context', {{'win','OpenGL'},{'d3d11','Direct3D 11'}}, 'Restart required'),
        row('Video sync', 'video-sync', {{'audio','Audio clock'},{'display-resample','Display refresh'}}, 'Next file'),
        row('Exclusive audio output', 'audio-exclusive', toggle, 'Restart required'),
        row('Network cache duration', 'cache-secs', {{'10','10 seconds'},{'30','30 seconds'},{'120','120 seconds'},{'3600000','MPV default'}}, 'Next file'),
        row('Screenshot format', 'screenshot-format', {{'jpg','JPEG'},{'png','PNG'},{'webp','WebP'}}),
        {label='Open mpv.conf', action=function() settings.edit() end},
    }},
}

local function read()
    local lines = {}
    local input = io.open(file, 'r')
    if not input then return lines end
    for line in input:lines() do lines[#lines+1] = line:gsub('\r$','') end
    input:close()
    return lines
end

local function key_for(option)
    if option == 'audio-mode' then return 'script-opts-append=quick-ui-audio-mode=' end
    if option == 'remember-settings' then return 'script-opts-append=quick-ui-remember-settings=' end
    if option == 'theme' then return 'script-opts-append=quick-ui-theme=' end
    return option == 'thumbnails' and prefix or option .. '='
end

local session_changes = {}

local function saved_video_options(lines)
    local options = {}
    for option,value in pairs(video_defaults) do options[option]=value end
    for _,line in ipairs(lines) do
        local profiles=line:match('^profile=(.*)$')
        if profiles then
            for name in profiles:gmatch('[^,]+') do
                local profile=video_profiles[name:match('^%s*(.-)%s*$')]
                if profile then
                    for option,value in pairs(profile) do options[option]=value end
                end
            end
        end
    end
    return options
end

function settings.get(option)
    if session_changes[option] then return session_changes[option] end
    local lines = read()
    if video_defaults[option] then return saved_video_options(lines)[option] end
    local key = key_for(option)
    local found
    for _,line in ipairs(lines) do
        if line:sub(1,#key) == key then found = line:sub(#key+1) end
    end
    if option == 'theme' then return theme_catalog.by_id[found] and found or 'c2' end
    if found then return found end
    if option == 'audio-mode' then return 'single' end
    if option == 'thumbnails' or option == 'remember-settings' then return 'yes' end
    if option == 'volume' then return settings.initial_volume end
    if option == 'mute' then return settings.initial_mute end
    local current = mp.get_property('options/'..option, '')
    local number = tonumber(current)
    return number and tostring(number):gsub('%.0$','') or current
end

settings.initial_volume = mp.get_property('options/volume', '75')
settings.initial_mute = mp.get_property('options/mute', 'no')
settings.thumbnails = settings.get('thumbnails') ~= 'no'
settings.remember = settings.get('remember-settings') ~= 'no'
settings.theme = settings.get('theme')
settings.themes = theme_catalog.by_id

local function store(changes)
    local saved = read()
    local updates,video = {},nil
    for option,value in pairs(changes) do
        if video_defaults[option] then
            video=video or saved_video_options(saved)
            video[option]=value
        else updates[key_for(option)]=value end
    end
    local lines,profiles = {},{}
    for _,line in ipairs(saved) do
        local key = line:match('^(script%-opts%-append=[^=]+=)') or line:match('^([^=]+=)')
        if key=='profile=' and video then
            local custom={}
            for name in line:sub(9):gmatch('[^,]+') do
                if not video_profiles[name:match('^%s*(.-)%s*$')] then custom[#custom+1]=name end
            end
            if #custom>0 then profiles[#profiles+1]='profile='..table.concat(custom,',') end
        elseif key=='profile=' then profiles[#profiles+1]=line
        elseif not key or updates[key]==nil then lines[#lines+1]=line end
    end
    for key,value in pairs(updates) do lines[#lines+1]=key..value end
    for _,line in ipairs(profiles) do lines[#lines+1]=line end
    if video then
        local filter=filter_profiles[video['rtx-upscaling']][video['rtx-hdr']]
        local output=output_profiles[video['video-output']]
        if filter then lines[#lines+1]='profile='..filter end
        if output then lines[#lines+1]='profile='..output end
    end
    local temp = file .. '.' .. utils.getpid() .. '.tmp'
    local previous = temp .. '.bak'
    local output = io.open(temp, 'wb')
    if not output then return nil, 'Could not save preferences' end
    local wrote = output:write(table.concat(lines, '\n') .. '\n')
    local closed = output:close()
    if not wrote or not closed then
        os.remove(temp)
        return nil, 'Could not save preferences'
    end
    if not os.rename(temp, file) then
        -- The Windows C runtime cannot rename over an existing file.
        if not os.rename(file, previous) then
            os.remove(temp)
            return nil, 'Could not save preferences'
        end
        if not os.rename(temp, file) then
            os.rename(previous, file)
            os.remove(temp)
            return nil, 'Could not save preferences'
        end
        os.remove(previous)
    end
    return true
end

function settings.save(row, value)
    if row.option=='theme' and not theme_catalog.by_id[value] then return nil,'Unknown interface theme' end
    if row.option=='remember-settings' then
        local enabled=value=='yes'
        local changes={['remember-settings']=value}
        if enabled then
            for option,pending in pairs(session_changes) do changes[option]=pending end
        end
        local ok,message=store(changes)
        if not ok then return nil,message end
        settings.remember=enabled
        if enabled then session_changes={} end
        return true,enabled and 'Preferences saved' or 'Changes apply to this session only'
    end
    if not settings.remember and row.when=='Restart required' then
        return nil,'Enable Remember settings first'
    end
    local previous = session_changes[row.option]
    if settings.remember then
        local ok,message=store({[row.option]=value})
        if not ok then return nil,message end
    else session_changes[row.option]=value end

    if row.option == 'thumbnails' then
        settings.thumbnails = value == 'yes'
    elseif row.option == 'theme' then
        settings.theme = value
    elseif row.option == 'audio-mode' then
        local ok,message=settings.apply_audio_mode(value)
        if not ok and message then return true,message end
    elseif row.when ~= 'Restart required' then
        local ok = mp.set_property('options/'..row.option, value)
        if not ok then
            if not settings.remember then session_changes[row.option]=previous;return nil,'Requires saving and restarting' end
            return true,'Restart QuickMPV to apply'
        end
    end
    if row.when=='Restart required' then return true,'Restart QuickMPV to apply' end
    if row.when=='Next file' then return true,'Applies to the next file' end
    return true,settings.remember and 'Saved' or 'Applied for this session'
end

function settings.edit()
    local path = mp.command_native({'expand-path', '~~/mpv.conf'})
    return mp.command_native({name='subprocess', args={'notepad.exe', path}, detach=true, playback_only=false})
end

function settings.check_updates()
    local path=mp.command_native({'expand-path','~~/update-mpv.ps1'})
    local result=mp.command_native({name='subprocess',detach=true,playback_only=false,
        args={'powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',path}})
    if not result or result.status~=0 then mp.osd_message('Could not open MPV updater',3) end
end

return settings
