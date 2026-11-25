-- QuickMPV: original QuickTime-inspired playback UI. MIT license.
local mp = require 'mp'
local utils = require 'mp.utils'
local assdraw = require 'mp.assdraw'
local function load_module(name)
    return dofile(mp.command_native({'expand-path','~~/'..name..'.lua'}))
end
local settings = load_module('quick-settings')
local thumbnail = load_module('quick-thumbnails')
local panel = load_module('quick-panel')
local audio = load_module('quick-audio')
local stats = load_module('quick-stats')
local theme = settings.themes[settings.theme]
mp.set_property('options/background-color',theme.background_rgb)
-- Reinstalls retain mpv.conf. Apply the title-bar option for older installations too.
local custom_title = mp.set_property_native('options/title-bar',false) ~= nil
settings.apply_audio_mode = function(value) return audio.set_enabled(value=='mix') end
settings.apply_audio_mode(settings.get('audio-mode'))
thumbnail.set_enabled(settings.thumbnails)
local overlay = mp.create_osd_overlay('ass-events')
local W,H = 1200,720
local BASE_SCALE = .92
local TITLE_HEIGHT = 38
local caption_drag
local mx,my = -1,-1
local regions = {}
local last_move = mp.get_time()
local dragging,menu,dialog = nil,false,false
local alpha = 0
local render
local function prop(n,d) return mp.get_property_number(n,d or 0) end
local function bool(n) return mp.get_property_native(n,false) end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function escape(s) return tostring(s):gsub('\\','\\'..'\239\187\191'):gsub('{','\\{'):gsub('\n',' ') end
local function time(t)
    t=math.max(0,math.floor(t or 0))
    if t>=3600 then return string.format('%d:%02d:%02d',math.floor(t/3600),math.floor(t/60)%60,t%60) end
    return string.format('%d:%02d',math.floor(t/60),t%60)
end
local function open_file()
    if dialog then return end
    dialog=true
    local path=mp.command_native({'expand-path','~~/open-file.ps1'})
    mp.command_native_async({name='subprocess',args={'powershell.exe','-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',path},capture_stdout=true,capture_stderr=true,playback_only=false},function(ok,result)
        dialog=false
        if ok and result and result.status==0 and result.stdout:match('%S') then
            local files=utils.parse_json(result.stdout:gsub('^\239\187\191',''))
            if type(files)=='table' then
                for i,file in ipairs(files) do mp.commandv('loadfile',file,i==1 and 'replace' or 'append') end
            else
                mp.osd_message('Could not read the file selection. Drop a file into this window.',4)
            end
        elseif not ok or (result and result.status~=0) then mp.osd_message('Could not open file picker. Drop a file into this window.',4) end
        last_move=mp.get_time()
    end)
end
local function hit()
    for i=#regions,1,-1 do
        local r=regions[i]
        if mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h then return r end
    end
end
local function region(id,x,y,w,h,label,fn,slide)
    local r={id=id,x=x,y=y,w=w,h=h,label=label,fn=fn,slide=slide}
    regions[#regions+1]=r
    return mx>=x and mx<=x+w and my>=y and my<=y+h
end
local a
local function shape(path,color,opacity)
    a:new_event(); a:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%02X&}',color,clamp((opacity or 0)+alpha,0,255)))
    a:draw_start(); a:append('{\\p1}'..path); a:draw_stop()
end
local function rect(x,y,w,h,r,color,opacity)
    local k=.55228475; r=math.min(r,w/2,h/2)
    shape(string.format('m %f %f l %f %f b %f %f %f %f %f %f l %f %f b %f %f %f %f %f %f l %f %f b %f %f %f %f %f %f l %f %f b %f %f %f %f %f %f',x+r,y,x+w-r,y,x+w-r+k*r,y,x+w,y+r-k*r,x+w,y+r,x+w,y+h-r,x+w,y+h-r+k*r,x+w-r+k*r,y+h,x+w-r,y+h,x+r,y+h,x+r-k*r,y+h,x,y+h-r+k*r,x,y+h-r,x,y+r,x,y+r-k*r,x+r-k*r,y,x+r,y),color,opacity)
end
local function circle(x,y,r,c,op) rect(x-r,y-r,r*2,r*2,r,c,op) end
local function text(x,y,s,size,c,align)
    a:new_event(); a:append(string.format('{\\an%d\\pos(%f,%f)\\fnSegoe UI\\fs%d\\bord0\\shad0\\1c&H%s&\\1a&H%02X&}%s',align or 5,x,y,size,c or theme.text,alpha,escape(s)))
end
local function triangle(x,y,size,right,c)
    local d=right and 1 or -1
    shape(string.format('m %f %f l %f %f %f %f',x-d*size*.42,y-size*.6,x+d*size*.6,y,x-d*size*.42,y+size*.6),c or theme.text)
end
local function icon(kind,x,y,c,backdrop)
    c=c or theme.text
    if kind=='play' then triangle(x,y,20,true,c)
    elseif kind=='pause' then rect(x-8,y-12,5,24,1,c);rect(x+3,y-12,5,24,1,c)
    elseif kind=='back' or kind=='next' then
        local d=kind=='next'; triangle(x-5,y,12,d,c);triangle(x+5,y,12,d,c)
    elseif kind=='volume' then
        shape(string.format('m %d %d l %d %d %d %d %d %d %d %d %d %d',x-10,y-4,x-5,y-4,x+1,y-10,x+1,y+10,x-5,y+4,x-10,y+4),c)
        text(x+8,y,bool('mute') and '×' or ')',18,c)
    elseif kind=='full' then
        for _,p in ipairs({{x-10,y-10,1,1},{x+10,y-10,-1,1},{x-10,y+10,1,-1},{x+10,y+10,-1,-1}}) do
            rect(p[1]+(p[3]<0 and -7 or 0),p[2],8,2,0,c); rect(p[1],p[2]+(p[4]<0 and -7 or 0),2,8,0,c)
        end
    elseif kind=='more' then for i=-1,1 do circle(x+i*6,y,1.6,c) end
    elseif kind=='screen' or kind=='captions' then
        rect(x-12,y-9,24,18,3,c);rect(x-10,y-7,20,14,2,backdrop or theme.panel)
        if kind=='captions' then
            rect(x-7,y+1,5,2,1,c);rect(x,y+1,7,2,1,c);rect(x-7,y+4,14,2,1,c)
        else rect(x-6,y+11,12,2,1,c) end
    elseif kind=='gear' then
        for i=0,7 do
            local angle=i*math.pi/4
            circle(x+10*math.cos(angle),y+10*math.sin(angle),2.6,c)
        end
        circle(x,y,10,c);circle(x,y,4,backdrop or theme.panel)
    elseif kind=='close' then
        for i=-5,5 do circle(x+i,y+i,1.15,c);circle(x+i,y-i,1.15,c) end
    elseif kind=='minimize' then rect(x-6,y+4,12,1.6,.8,c)
    elseif kind=='maximize' then
        rect(x-6,y-6,12,12,1,c);rect(x-4.5,y-4.5,9,9,0,backdrop or theme.panel)
    elseif kind=='restore' then
        local fill=backdrop or theme.panel
        rect(x-3,y-7,11,11,1,c);rect(x-1.5,y-5.5,8,8,0,fill)
        rect(x-7,y-3,11,11,1,c);rect(x-5.5,y-1.5,8,8,0,fill)
    elseif kind=='appearance' then
        circle(x,y,10,c);circle(x,y,8,backdrop or theme.panel)
        shape(string.format('m %f %f b %f %f %f %f %f %f b %f %f %f %f %f %f l %f %f',
            x,y-9,x-5,y-9,x-9,y-5,x-9,y,x-9,y+5,x-5,y+9,x,y+9,x,y-9),c)
    elseif kind=='chevron' then
        for i=-4,4 do circle(x+2-math.abs(i),y+i,1.15,c) end
    end
end
local function button(id,x,y,w,h,label,fn,kind)
    local hover=region(id,x,y,w,h,label,fn)
    if hover then rect(x,y,w,h,6,theme.hover) end
    icon(kind,x+w/2,y+h/2)
end
local function cycle_speed()
    local speeds={.5,.75,1,1.25,1.5,2}
    local current=prop('speed',1)
    for _,s in ipairs(speeds) do if s>current+.01 then mp.set_property_number('speed',s);return end end
    mp.set_property_number('speed',.5)
end
local panel_ui = {rect=rect,text=text,region=region,button=button,icon=icon,circle=circle,theme=theme}
local function toggle_stats()
    stats.enabled=not stats.enabled
    menu=false
end

local function toggle_audio_mix()
    local enabled=not audio.enabled
    local ok,message=audio.set_enabled(enabled)
    menu=false
    if not ok then
        audio.set_enabled(not enabled)
        mp.osd_message(message or 'Could not change audio track mode',3)
    elseif enabled and audio.count==0 then
        mp.osd_message('Mix all tracks enabled. This file has fewer than two audio tracks.',3)
    end
end
local function toggle_preferences()
    menu = false
    dragging = nil
    panel.toggle(settings)
end

local function toggle_maximize()
    mp.set_property_native('window-maximized',not bool('window-maximized'))
end

local function window_title(is_idle,limit)
    local title=is_idle and 'QuickMPV' or mp.get_property('media-title','QuickMPV')
    local count=0
    for offset in title:gmatch('()[%z\1-\127\194-\244][\128-\191]*') do
        if count==limit then return title:sub(1,offset-1)..'…' end
        count=count+1
    end
    return title
end

local function draw_title_bar(is_idle)
    local size=43
    local content=W-size*3
    rect(0,0,W,TITLE_HEIGHT,0,theme.panel)
    rect(0,TITLE_HEIGHT-1,W,1,0,theme.line)
    region('caption',0,0,content,TITLE_HEIGHT)
    circle(21,TITLE_HEIGHT/2,10,theme.accent)
    triangle(21.5,TITLE_HEIGHT/2,7,true,theme.on_accent)
    text(39,TITLE_HEIGHT/2,window_title(is_idle,math.max(1,math.floor((content-52)/11))),20,theme.text,4)
    local maximized=bool('window-maximized')
    local buttons={
        {'minimize','Minimize',function() mp.set_property_native('window-minimized',true) end,'minimize'},
        {'maximize',maximized and 'Restore' or 'Maximize',toggle_maximize,maximized and 'restore' or 'maximize'},
        {'close','Close',function() mp.commandv('quit') end,'close'},
    }
    for i,item in ipairs(buttons) do
        local x=content+(i-1)*size
        local hovered=region('caption-'..item[1],x,0,size,TITLE_HEIGHT,item[2],item[3])
        local fill=hovered and theme.hover or theme.panel
        if hovered then rect(x,0,size,TITLE_HEIGHT-1,0,fill) end
        icon(item[4],x+size/2,TITLE_HEIGHT/2,theme.text,fill)
    end
end

local function render_thumbnail(seek, scale)
    local seconds = clamp((mx-seek.x)/seek.w,0,1)*seek.duration
    local center = clamp(mx,124,W-124)
    local y,x = seek.y-224,center-116
    local ready = thumbnail.show(seconds,seek.duration,math.floor(x*scale),math.floor(y*scale),
        math.floor(232*scale),math.floor(130*scale))
    if ready then
        rect(x-2,y-2,236,163,8,theme.background)
        text(center,y+146,time(seconds),20,theme.text)
    else
        rect(center-43,seek.y-66,86,33,6,theme.background)
        text(center,seek.y-50,time(seconds),20,theme.text)
    end
end
render=function()
    local ow,oh=mp.get_osd_size(); if not ow or oh==0 then return end
    thumbnail.set_enabled(settings.thumbnails)
    -- Keep logical units tied to monitor DPI. Fit only when the client is too small for the compact layout.
    local dpi=prop('display-hidpi-scale',1)
    if dpi<=0 then dpi=1 end
    local scale=math.min(BASE_SCALE*dpi,ow/280,oh/405)
    W,H=math.floor(ow/scale+.5),math.floor(oh/scale+.5)
    local px,py=mp.get_mouse_pos(); mx=px/ow*W;my=py/oh*H
    a=assdraw.ass_new();regions={};alpha=0
    local next_theme=settings.themes[settings.theme]
    if next_theme~=theme then
        theme=next_theme
        panel_ui.theme=theme
        mp.set_property('options/background-color',theme.background_rgb)
    end
    local idle=bool('idle-active')
    local windowed=custom_title and not bool('fullscreen')
    local title_visible=windowed and (idle or panel.open or menu or caption_drag or bool('pause') or
        (bool('mouse-pos/hover') and my<TITLE_HEIGHT) or mp.get_time()-last_move<2.5)
    local title_inset=title_visible and TITLE_HEIGHT or 0
    if idle then rect(0,0,W,H,0,theme.background) end
    if panel.open then
        thumbnail.hide()
        panel.draw(settings,panel_ui,W,H,title_inset)
        if title_visible then draw_title_bar(idle) end
        overlay.res_x=W;overlay.res_y=H;overlay.data=a.text;overlay:update()
        return
    end
    local seek_area
    if stats.enabled and not idle then stats.draw(panel_ui,W,audio.count,H,title_inset) end
    local over_controller = not idle and bool('mouse-pos/hover') and my>=H-146 and my<=H-35 and
        math.abs(mx-W/2)<=math.min(550,W-32)/2
    local visible=idle or bool('pause') or menu or dragging or over_controller or mp.get_time()-last_move<2.5
    -- UI fades in the last quarter-second before hiding.
    if not visible then
        thumbnail.hide()
        if title_visible then draw_title_bar(idle) end
        overlay.res_x=W;overlay.res_y=H;overlay.data=a.text;overlay:update()
        return
    end
    if not idle and not bool('pause') and not menu and not dragging and not over_controller then
        alpha=math.floor(clamp((mp.get_time()-last_move-2.25)/.25,0,1)*255)
    end
    if idle then
        circle(W/2,H/2-83,42,theme.accent);triangle(W/2+2,H/2-83,30,true,theme.on_accent)
        text(W/2,H/2-4,W<370 and 'Drop a media file here' or 'Drop a video or audio file here',27,theme.muted)
        local bx=W/2-90;local by=H/2+28
        local hover=region('open',bx,by,180,46,'Open file · Ctrl+O',open_file)
        rect(bx,by,180,46,8,hover and theme.accent_hover or theme.accent);text(W/2,by+23,'Open File…',24,theme.on_accent)
    else
        local pw=math.min(550,W-32);local x=(W-pw)/2;local y=H-146
        rect(x-1,y-1,pw+2,113,13,theme.line,75);rect(x,y,pw,111,12,theme.panel,16)
        local center=x+pw/2
        if pw>=335 then
            button('back',center-82,y+11,40,36,'Back 10 seconds',function() mp.commandv('seek',-10,'relative+exact') end,'back')
            button('next',center+42,y+11,40,36,'Forward 10 seconds',function() mp.commandv('seek',10,'relative+exact') end,'next')
        end
        button('play',center-24,y+7,48,44,bool('pause') and 'Play · Space' or 'Pause · Space',function() mp.commandv('cycle','pause') end,bool('pause') and 'play' or 'pause')
        button('mute',x+15,y+14,28,30,'Mute · M',function() mp.commandv('cycle','mute') end,'volume')
        local vx=x+51;local vw=math.max(28,math.min(70,pw/7))
        if pw>=440 then
            rect(vx,y+27,vw,3,1,theme.track);rect(vx,y+27,vw*prop('volume',75)/100,3,1,theme.accent);circle(vx+vw*prop('volume',75)/100,y+28.5,4,theme.accent_hover)
            region('volume',vx-5,y+15,vw+10,28,'Volume',nil,function(xx) mp.set_property_number('volume',clamp((xx-vx)/vw,0,1)*100) end)
        end
        button('options',x+pw-82,y+14,30,30,'Speed, loop and tracks',function() menu=not menu end,'more')
        button('fullscreen',x+pw-44,y+14,30,30,'Fullscreen · F',function() mp.commandv('cycle','fullscreen') end,'full')
        local duration=prop('duration');local pos=prop('time-pos');local sx=x+20;local sw=pw-40
        rect(sx,y+65,sw,3,1,theme.track);local fraction=duration>0 and clamp(pos/duration,0,1) or 0
        rect(sx,y+65,math.max(1,sw*fraction),3,1,theme.accent);circle(sx+sw*fraction,y+66.5,4.5,theme.text)
        region('seek',sx-5,y+55,sw+10,23,'Scrub',nil,function(xx) if duration>0 then mp.commandv('seek',clamp((xx-sx)/sw,0,1)*duration,'absolute+exact') end end)
        seek_area = {x=sx,w=sw,y=y+55,duration=duration}
        text(sx,y+91,time(pos),21,theme.muted,4);text(sx+sw,y+91,'−'..time(duration-pos),21,theme.muted,6)
        if pw>=335 then text(center,y+91,prop('speed',1)~=1 and string.format('%g×',prop('speed',1)) or '',21,theme.muted) end
    end
    if menu then
        local mw=math.min(320,W-24);local xx=W-mw-12;local yy=math.max(title_inset+7,math.min(51,H*.06))
        local rows={
            {'Open File…','Ctrl+O',open_file},
            {'Playback speed',string.format('%g×',prop('speed',1)),cycle_speed},
            {'Loop',mp.get_property('loop-file')=='no' and 'Off' or 'On',function() mp.commandv('cycle-values','loop-file','inf','no') end},
            {'Audio track',audio.count>1 and 'Mixed' or tostring(mp.get_property('aid','Auto')),function()
                if audio.count>1 then audio.set_enabled(false) end
                mp.commandv('cycle','audio')
            end},
            {'Mix all audio tracks',audio.enabled and 'On' or 'Off',toggle_audio_mix},
            {'Subtitles',tostring(mp.get_property('sid','Off')),function() mp.commandv('cycle','sub') end},
            {'Previous file','',function() mp.commandv('playlist-prev','weak') end},
            {'Next file','',function() mp.commandv('playlist-next','weak') end},
            {'Actual Size','',function() mp.set_property_number('window-scale',1);menu=false end},
            {'Fit Window','',function() mp.set_property_native('window-maximized',not bool('window-maximized'));menu=false end},
            {'Always on top',bool('ontop') and 'On' or 'Off',function() mp.commandv('cycle','ontop') end},
            {'Playback stats',stats.enabled and 'On' or 'Off',toggle_stats},
            {'Preferences','Ctrl+,',toggle_preferences,'gear'},
        }
        local row_height=math.min(42,math.floor((H-yy-25)/#rows))
        local label_size=mw<285 and 20 or 24
        rect(xx-1,yy-1,mw+2,#rows*row_height+14,10,theme.line);rect(xx,yy,mw,#rows*row_height+12,9,theme.panel)
        for i,row in ipairs(rows) do
            local ry=yy+6+(i-1)*row_height
            local center=ry+row_height/2
            if region('row'..i,xx+5,ry,mw-10,row_height,row[1],row[3]) then rect(xx+5,ry,mw-10,row_height,5,theme.selected) end
            if row[4] then icon(row[4],xx+24,center) end
            text(xx+(row[4] and 44 or 16),center,row[1],label_size,theme.text,4);text(xx+mw-16,center,row[2],21,theme.muted,6)
        end
    end
    if title_visible then alpha=0;draw_title_bar(idle) end
    local r=hit()
    if not menu and settings.thumbnails and seek_area and seek_area.duration>0 and W>=250 and
        ((dragging and dragging.id=='seek') or (r and r.id=='seek' and bool('mouse-pos/hover'))) then
        render_thumbnail(seek_area,oh/H)
    else thumbnail.hide() end
    if r and r.label and r.id~='seek' and r.id~='volume' and not menu then
        local ty=r.y>H/2 and r.y-25 or r.y+r.h+24
        local tw=math.min(W-10,#r.label*10+22);local tx=clamp(r.x+r.w/2,tw/2+5,W-tw/2-5)
        rect(tx-tw/2,ty-17,tw,34,5,theme.background);text(tx,ty,r.label,21,theme.text)
    end
    overlay.res_x=W;overlay.res_y=H;overlay.data=a.text;overlay:update()
end
local function move()
    last_move=mp.get_time()
    local ow,oh=mp.get_osd_size();local x,y=mp.get_mouse_pos()
    if ow and ow>0 and oh>0 then mx=x/ow*W;my=y/oh*H end
    if caption_drag and (math.abs(mx-caption_drag.x)>3 or math.abs(my-caption_drag.y)>3) then
        caption_drag=nil
        mp.commandv('begin-vo-dragging')
    end
    if dragging and dragging.slide then dragging.slide(mx) end
    render()
end
local function click(event)
    if event.event=='down' or event.event=='press' then
        last_move=mp.get_time();render();local r=hit()
        if r then
            if r.id=='caption' and event.event=='down' then caption_drag={x=mx,y=my}
            elseif r.slide then dragging=r;r.slide(mx)
            elseif r.fn then r.fn() end
        elseif panel.open then return
        elseif menu then menu=false
        elseif not bool('idle-active') then mp.commandv('cycle','pause') end
    elseif event.event=='up' then dragging,caption_drag=nil,nil end
    render()
end
mp.add_forced_key_binding('MBTN_LEFT','quick-click',click,{complex=true})
mp.add_forced_key_binding('MBTN_LEFT_DBL','quick-double-click',function()
    render()
    local target=hit()
    if target and target.id=='caption' then caption_drag=nil;toggle_maximize()
    elseif not target and not panel.open and not menu then mp.commandv('cycle','fullscreen') end
end)
mp.add_forced_key_binding('mouse_move','quick-move',move)
mp.add_forced_key_binding('mouse_leave','quick-leave',function() mx=-1;my=-1;dragging,caption_drag=nil,nil end)
mp.register_script_message('quick-open',open_file)
mp.register_script_message('quick-stats',function() toggle_stats();render() end)
mp.register_script_message('quick-preferences',function() toggle_preferences();last_move=mp.get_time();render() end)
mp.register_script_message('quick-menu',function() if not panel.open then menu=not menu end;last_move=mp.get_time();render() end)
mp.register_script_message('quick-escape',function()
    if panel.selected then panel.selected,panel.feedback=nil,nil
    elseif panel.open then toggle_preferences()
    elseif menu then menu=false
    elseif bool('fullscreen') then mp.set_property_native('fullscreen',false) end
    last_move=mp.get_time();render()
end)
mp.register_event('file-loaded',function() last_move=mp.get_time();menu=false;mp.set_property_native('pause',false) end)
mp.register_event('end-file',function(e) if e.reason=='error' then mp.osd_message('Unable to play this file: '..(e.error or 'unsupported media'),5) end end)
for _,p in ipairs({'pause','time-pos','volume','mute','fullscreen','idle-active','media-title','speed','loop-file','osd-dimensions'}) do mp.observe_property(p,'native',function() render() end) end
mp.add_periodic_timer(.05,render)
