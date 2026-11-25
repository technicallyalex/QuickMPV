-- RGB values ordered by UI role. Convert to ASS BGR once when loading.
local roles = {'background','panel','hover','selected','line','track','accent','accent_hover','text','muted','scrim','on_accent'}
local themes = {
    {'c2','Navy and Periwinkle', '0B1940','14254D','253868','34477E','455986','61729E','9AA5FF','BCC4FF','EEF0FF','C3CBEF','050C24','0B1940'},
    {'violet','Violet',            '1C1327','2B1F38','3E2E53','503B6A','625178','807194','CDABFF','E2CBFF','F8F0FF','DBC9EA','100919','231231'},
    {'teal','Teal',                '0A2226','103035','1E4449','26565A','397074','59888D','6DDCCF','A0F1E6','EDFFFC','B4DAD7','041516','092527'},
    {'black','Black',              '000000','121212','262626','393939','4C4C4C','747474','F5F5F5','FFFFFF','FFFFFF','C6C6C6','000000','111111'},
    {'gray','Gray',                '303030','424242','515151','606060','727272','949494','E5E5E5','FFFFFF','FFFFFF','DFDFDF','161616','202020'},
    {'white','White',              'FAFAFA','FFFFFF','EDEDED','DFDFDF','B3B3B3','888888','292929','424242','161616','494949','202020','FFFFFF'},
}

local catalog = {choices={}, by_id={}}
for _,entry in ipairs(themes) do
    local palette = {background_rgb='#'..entry[3]}
    for i,role in ipairs(roles) do
        local rgb = entry[i+2]
        palette[role] = rgb:sub(5,6) .. rgb:sub(3,4) .. rgb:sub(1,2)
    end
    catalog.choices[#catalog.choices+1] = {entry[1],entry[2]}
    catalog.by_id[entry[1]] = palette
end

return catalog
