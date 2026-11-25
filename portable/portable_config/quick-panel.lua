local panel = {open=false, category=1}

function panel.toggle(settings)
    panel.open = not panel.open
    panel.selected, panel.feedback = nil, nil
    if not panel.open then return end
    panel.values = {}
    for _,page in ipairs(settings.pages) do
        for _,row in ipairs(page.rows) do
            if row.option then panel.values[row.option] = settings.get(row.option) end
        end
    end
end

function panel.draw(settings, ui, width, height, title_inset)
    local rect, text, region, button, icon, circle = ui.rect, ui.text, ui.region, ui.button, ui.icon, ui.circle
    local theme = ui.theme
    rect(0,0,width,height,0,theme.scrim,58)
    local w = math.min(width-24,850)
    local h = math.min(490,height-title_inset-16)
    local x,y = (width-w)/2,(height+title_inset-h)/2
    local sidebar = w >= 650 and 188 or 60
    local content, right = x+sidebar+14,x+w-16
    local compact = w-sidebar < 455
    local page = settings.pages[panel.category]
    local function fitted(s,size,available)
        return math.max(13,math.min(size,math.floor(available/math.max(1,#s*.51))))
    end
    rect(x-1,y-1,w+2,h+2,14,theme.line)
    rect(x,y,w,h,13,theme.panel)
    text(x+22,y+30,'Preferences',29,theme.text,4)
    button('prefs-close',x+w-49,y+10,39,39,'Close',function() panel.toggle(settings) end,'close')
    rect(x+1,y+61,w-2,1,0,theme.line)
    rect(x+sidebar,y+62,1,h-63,0,theme.line)
    for i,tab in ipairs(settings.pages) do
        local step = math.min(54,math.floor((h-82)/#settings.pages))
        local tab_y = y+76+(i-1)*step
        local tab_height = step-8
        local center = tab_y+tab_height/2
        local hovered = region('prefs-tab'..i,x+8,tab_y,sidebar-15,tab_height,tab.name,function()
            panel.category, panel.selected, panel.feedback = i, nil, nil
        end)
        local backdrop = panel.category==i and theme.selected or hovered and theme.hover or theme.panel
        if panel.category==i or hovered then rect(x+8,tab_y,sidebar-15,tab_height,7,backdrop) end
        icon(tab.icon,x+30,center,panel.category==i and theme.accent or nil,backdrop)
        if sidebar>60 then text(x+52,center,tab.name,23,theme.text,4) end
    end

    local selected = panel.selected
    if selected then
        button('prefs-back',content,y+73,32,37,'Back',function() panel.selected,panel.feedback=nil,nil end,'back')
        text(content+38,y+92,selected.label,compact and 19 or 25,theme.text,4)
        for i,choice in ipairs(selected.choices) do
            local step = math.min(49,math.floor((h-176)/#selected.choices))
            local row_y = y+125+(i-1)*step
            local center = row_y+(step-5)/2
            local current = panel.values[selected.option]==choice[1]
            local hovered = region('prefs-choice'..i,content,row_y,right-content,step-5,choice[2],function()
                local ok, message = settings.save(selected,choice[1])
                panel.feedback = message
                if ok then panel.values[selected.option],panel.selected=choice[1],nil end
            end)
            if hovered or current then rect(content,row_y,right-content,step-5,6,current and theme.selected or theme.hover) end
            circle(content+18,center,6.5,current and theme.accent or theme.track)
            if not current then circle(content+18,center,4,theme.panel) end
            local sample=settings.themes[choice[1]]
            if selected.option=='theme' and sample then
                rect(right-40,center-9,30,18,5,theme.line)
                rect(right-39,center-8,28,16,4,sample.background)
                circle(right-21,center,5,sample.accent)
            end
            local available=right-content-(selected.option=='theme' and 78 or 42)
            text(content+35,center,choice[2],fitted(choice[2],23,available),theme.text,4)
        end
    else
        text(content+8,y+91,page.name,27,theme.text,4)
        for i,row in ipairs(page.rows) do
            local step = math.min(50,math.floor((h-158)/#page.rows))
            local row_y = y+115+(i-1)*step
            local center = row_y+(step-4)/2
            local value = panel.values[row.option] or ''
            local has_label = false
            for _,choice in ipairs(row.choices or {}) do
                if choice[1]==value then value=choice[2];has_label=true;break end
            end
            if not has_label and #value>21 then value='Custom' end
            local is_switch = row.option=='remember-settings'
            local hovered = region('prefs-row'..i,content,row_y,right-content,step-4,row.label,function()
                if is_switch then
                    local next_value=settings.remember and 'no' or 'yes'
                    local ok,message=settings.save(row,next_value)
                    panel.feedback=message
                    if ok then panel.values[row.option]=next_value end
                elseif row.action then row.action()
                else panel.selected,panel.feedback=row,row.when end
            end)
            if hovered then rect(content,row_y,right-content,step-4,6,theme.hover) end
            text(content+10,center-(compact and 8 or 0),row.label,fitted(row.label,compact and 19 or 23,right-content-32),theme.text,4)
            if is_switch then
                local on=settings.remember
                rect(right-41,center-10,34,20,10,on and theme.accent or theme.track)
                circle(right-(on and 17 or 31),center,7,on and theme.on_accent or theme.text)
                if not compact then text(right-48,center,value,19,theme.muted,6) end
            else
                text(compact and content+10 or right-29,center+(compact and 8 or 0),value,
                    fitted(value,compact and 17 or 21,compact and right-content-32 or (right-content-36)*.48),theme.muted,compact and 4 or 6)
                icon('chevron',right-13,center,theme.accent_hover)
            end
        end
    end
    if panel.feedback then
        text(content+8,y+h-33,panel.feedback,fitted(panel.feedback,19,right-content-8),theme.muted,4)
    end
end

return panel
