local G=_G
local _ENV={}

name="Mechanical Workshops"
raws_list={"building_dragon_engine.txt"}
patch_entity=[[
    [PERMITTED_BUILDING:DRAGON_ENGINE_S]
    [PERMITTED_BUILDING:DRAGON_ENGINE_E]
    [PERMITTED_BUILDING:DRAGON_ENGINE_W]
    [PERMITTED_BUILDING:DRAGON_ENGINE_N]
]]
patch_init="dofile(dfhack.getDFPath()..'/mods/mechanicalWorkshops/mechanicalWorkshops.lua')"
function post_install()
    G.print("Mechanical workshops installed successfully")
end
function pre_install()
    G.print("Mechanical workshops installing...")
end
function pre_uninstall()
    G.print("Mechanical workshops uninstalling...")
end
function post_uninstall()
    G.print("Mechanical workshops uninstalled successfully")
end
author="warmist"
description=[[
A mechanical workshop showcase:
 * Dragon engines - lava using, dragon breath 
        shooting machines
 * More to come...
NOTICE: connecting machines must be built AFTER 
any mechanical workshop
]]
return _ENV