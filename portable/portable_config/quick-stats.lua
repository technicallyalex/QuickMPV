local mp = require 'mp'
local stats = {enabled=false}
local lines, last_update = {}, -1

local function bitrate(value)
    if value<=0 then return nil end
    return value>=1000000 and string.format('%.2f Mb/s',value/1000000) or string.format('%.0f kb/s',value/1000)
end

local function dimensions(params)
    if params and params.w and params.h then return params.w..' × '..params.h end
end

local function add(label,value)
    if value and value~='' then lines[#lines+1]={label,value} end
end

local function refresh(mix_count)
    lines={}
    local video = mp.get_property_native('video-params')
    local source = dimensions(video)
    local output = dimensions(mp.get_property_native('video-out-params'))
    add('Resolution', source)
    if output~=source then add('Filtered video',output) end
    local fps = mp.get_property_number('container-fps',0)
    if fps<=0 then fps=mp.get_property_number('estimated-vf-fps',0) end
    if fps>0 then add('Frame rate',string.format('%.3f fps',fps):gsub('0+ fps$',' fps'):gsub('%. fps$',' fps')) end
    add('Video codec',mp.get_property('current-tracks/video/codec') or mp.get_property('video-format'))
    add('Video bitrate',bitrate(mp.get_property_number('video-bitrate',0)))
    if video and video.gamma then add('Color transfer',video.gamma:upper()) end
    if mix_count>1 then add('Audio tracks',mix_count..' mixed')
    else add('Audio codec',mp.get_property('audio-codec-name')) end
    add('Audio bitrate',bitrate(mp.get_property_number('audio-bitrate',0)))
    local audio=mp.get_property_native('audio-out-params')
    if audio and audio['samplerate'] then
        add('Audio output',string.format('%g kHz · %s',audio.samplerate/1000,audio.channels or ''))
    end
    add('Container',mp.get_property('file-format'))
    local size, duration=mp.get_property_number('file-size',0),mp.get_property_number('duration',0)
    if size>0 and duration>0 then add('Average file bitrate',bitrate(size*8/duration)) end
    if video then add('Dropped frames',mp.get_property('frame-drop-count','0')) end
end

function stats.draw(ui,width,mix_count,height,title_inset)
    local theme = ui.theme
    local now=mp.get_time()
    if now-last_update>=.5 then refresh(mix_count);last_update=now end
    local w=math.min(400,width-20)
    if w<170 then return end
    local compact=w<340
    local row_height=compact and math.min(36,math.floor((height-title_inset-62)/math.max(1,#lines))) or 25
    ui.rect(14,14+title_inset,w,44+#lines*row_height,9,theme.background,15)
    ui.text(27,34+title_inset,'Playback stats',23,theme.text,4)
    for i,line in ipairs(lines) do
        local y=62+title_inset+(i-1)*row_height
        ui.text(27,y,line[1],compact and 16 or 18,theme.muted,4)
        ui.text(compact and 27 or w+1,y+(compact and 14 or 0),line[2],compact and 16 or 19,theme.text,compact and 4 or 6)
    end
end

mp.register_event('file-loaded',function() last_update=-1 end)
return stats
