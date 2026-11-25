local mp = require 'mp'
local utils = require 'mp.utils'
local preview = {}
local width, height, overlay_id = 192, 108, 4
local scratch = os.getenv('TEMP') or os.getenv('TMP')
local engine = mp.command_native({'expand-path','~~exe_dir/mpv.exe'})
local worker_script = mp.command_native({'expand-path','~~/quick-thumb-worker.lua'})
local sequence, active, enabled = 0, nil, false

local function read_frame(path)
    local file = io.open(path, 'rb')
    if not file then return end
    local bytes = file:read(width*height*4+1)
    file:close()
    if bytes and #bytes == width*height*4 then return bytes end
end

local function write(path, data)
    local file = io.open(path, 'wb')
    if not file then return false end
    local success = file:write(data)
    local closed = file:close()
    return success and closed
end

function preview.hide()
    if not active then return end
    if active.drawn then mp.commandv('overlay-remove', overlay_id) end
    active.drawn, active.target = nil, nil
end

local function cleanup(worker)
    for _,suffix in ipairs({'.request','.raw','.raw.tmp','.bgra'}) do os.remove(worker.base..suffix) end
end

local function stop()
    if not active then return end
    preview.hide()
    local worker = active
    active = nil
    if worker.command then mp.abort_async_command(worker.command) else cleanup(worker) end
end

local function start()
    if not enabled or not scratch or not engine or not mp.get_property_native('seekable') then return end
    if mp.get_property_native('demuxer-via-network') then return end
    local path = mp.get_property('stream-open-filename') or mp.get_property('path')
    if not path or path:match('^%a[%w+.-]*://') then return end
    if not path:match('^%a:[/\\]') and not path:match('^[/\\]') then
        path = utils.join_path(mp.get_property('working-directory', ''), path)
    end
    local info = utils.file_info(path)
    if not info or not info.is_file then return end
    local track
    for _,candidate in ipairs(mp.get_property_native('track-list',{})) do
        if candidate.type=='video' and candidate.selected and not candidate.albumart and not candidate.external then
            track = candidate.id
            break
        end
    end
    if not track or (active and active.path==path and active.track==track) then return end
    stop()
    sequence = sequence+1
    local base = utils.join_path(scratch, string.format('quickmpv-%d-%d',utils.getpid(),sequence))
    local worker = {base=base,path=path,track=track,serial=0,last_request=0}
    active = worker
    local gamma = mp.get_property('video-params/gamma','')
    local tone_map = (gamma=='pq' or gamma=='hlg') and
        'zscale=transfer=linear,format=gbrpf32le,tonemap=hable,zscale=transfer=bt709:primaries=bt709:matrix=bt709,' or ''
    local filter = '--vf=lavfi=['..tone_map..'scale=192:108:force_original_aspect_ratio=decrease:force_divisible_by=2:reset_sar=1,pad=192:108:(ow-iw)/2:(oh-ih)/2,format=bgra]'
    worker.command = mp.command_native_async({name='subprocess',playback_only=false,args={engine,
        '--no-config','--no-terminal','--load-scripts=no','--no-ytdl','--no-audio','--no-sub','--media-controls=no',
        '--pause','--keep-open=always','--hwdec=no','--vid='..track,'--vd-lavc-threads=2','--hr-seek=yes',
        '--demuxer-readahead-secs=0','--demuxer-max-bytes=512KiB','--script='..worker_script,
        '--script-opts-append=quick-thumb-worker-base='..base,filter,
        '--ovc=rawvideo','--of=image2','--ofopts=update=1,atomic_writing=1','--o='..base..'.raw','--',path}},
        function()
            worker.command = nil
            if active==worker then preview.hide();active=nil end
            cleanup(worker)
        end)
end

function preview.set_enabled(value)
    if enabled==value then return end
    enabled=value
    if enabled then start() else stop() end
end

function preview.show(seconds, duration, x, y, display_width, display_height)
    local worker = active
    if not worker then return false end
    local target = math.min(math.floor(seconds*10+.5)/10,math.max(0,duration-.05))
    local now = mp.get_time()
    if worker.target ~= target and now-worker.last_request >= .04 then
        worker.serial=worker.serial+1
        if write(worker.base..'.request', string.format('%d %.3f\n',worker.serial,target)) then
            worker.target,worker.last_request=target,now
        end
    end

    -- FFmpeg publishes complete frames atomically. Give the overlay a separate file so it never races the decoder.
    local bytes = read_frame(worker.base..'.raw')
    local updated = bytes and bytes~=worker.frame and write(worker.base..'.bgra',bytes)
    if updated then worker.frame=bytes end
    if not worker.frame then return false end
    local geometry=table.concat({x,y,display_width,display_height},':')
    if updated or geometry~=worker.drawn then
        local ok=mp.commandv('overlay-add',overlay_id,x,y,worker.base..'.bgra',0,'bgra',width,height,width*4,display_width,display_height)
        worker.drawn=ok and geometry or nil
    end
    return worker.drawn~=nil
end

mp.register_event('start-file', stop)
mp.register_event('file-loaded', start)
mp.register_event('end-file', stop)
mp.register_event('shutdown', stop)
mp.observe_property('vid','native',function()
    if active and active.track~=mp.get_property_number('vid') then stop() end
    if mp.get_property_native('video-params') then start() end
end)

return preview
