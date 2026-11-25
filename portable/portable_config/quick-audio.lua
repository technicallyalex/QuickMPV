local mp = require 'mp'
local audio = {enabled=false,count=0}
local owned_graph, previous_track

local function current_graph()
    return mp.get_property('lavfi-complex','')
end

local function release(restore_track)
    local graph, track = owned_graph, previous_track
    if graph and current_graph()==graph then
        if not mp.set_property('lavfi-complex','') then return nil end
        if restore_track then
            -- Force selection even when the aid option already has the desired value.
            mp.set_property('aid','no')
            mp.set_property('aid',track or 'auto')
        end
    end
    owned_graph, previous_track, audio.count = nil,nil,0
    return true
end

local function update()
    if not audio.enabled then return release(true) end
    local inputs = {}
    for _,track in ipairs(mp.get_property_native('track-list',{})) do
        local id = tonumber(track.id)
        if track.type=='audio' and id and id>0 and id%1==0 then inputs[#inputs+1]='[aid'..id..']' end
    end
    if #inputs<2 then return release(true) end
    local current = current_graph()
    if current~='' and current~=owned_graph then
        owned_graph, previous_track, audio.count = nil,nil,0
        return nil,'An MPV filter graph is already in use'
    end
    local graph = table.concat(inputs)..'amix=inputs='..#inputs..':duration=longest:normalize=1:dropout_transition=0[ao]'
    if graph==owned_graph and current==graph then return true end

    local prior = previous_track or mp.get_property('current-tracks/audio/id') or mp.get_property('options/aid','auto')
    if not mp.set_property('lavfi-complex',graph) then return nil,'Could not mix the audio tracks' end
    owned_graph, previous_track, audio.count = graph,prior,#inputs
    return true
end

function audio.set_enabled(enabled)
    audio.enabled=enabled
    return update()
end

mp.register_event('end-file',function() release(false) end)
mp.add_hook('on_preloaded',50,update)
mp.register_event('file-loaded',function()
    local ok,message=update()
    if not ok and message then mp.osd_message(message,3) end
end)
mp.observe_property('track-list/count','number',function() update() end)

return audio
