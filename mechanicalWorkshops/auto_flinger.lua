local builds=require 'plugins.building-hacks'
local eventful= require 'plugins.eventful'
local guidm   =require 'gui.dwarfmode'
local widgets =require 'gui.widgets'
local utils=require 'utils'
--[==[
    TODO list:
        add z level each 5/10 power
        get items on/in this building too
        tweak numbers?
        add power requirement per item flinged (or trying to fling)
            thus making players produce more power or have chance of
            machines siezing up
        maybe add variation in fling power to discorouge long fling distance
        add (small?) chance that items will hit units
            could work as improvised trap/weapon
]==]
local function enum_items_in_region(min_x,min_y,max_x,max_y,z)
    local blocks={}

    for x=min_x,max_x do
    for y=min_y,max_y do
        local block=dfhack.maps.getTileBlock(x,y,z)
        if block then 
            blocks[block]=true
        end
    end
    end
    
    local item_ids={}
    for k,v in pairs(blocks) do
        for i,v in ipairs(k.items) do
            table.insert(item_ids,v)
        end
    end
    local ret={}
    for i,v in ipairs(item_ids) do
        local item=df.item.find(v)
        if item.pos.z==z and
            item.pos.x>=min_x and
            item.pos.x<=max_x and
            item.pos.y>=min_y and
            item.pos.y<=max_y then
            ret[v]=item
        end
    end
    return ret
end
local function get_create_general_ref(building)
    for k,ref in pairs(building.general_refs) do
        if ref:getType()==df.general_ref_type.LOCATION then
            return ref
        end
    end
    local ref=df.general_ref_locationst:new()
    ref.anon_1=0
    ref.anon_2=2
    building.general_refs:insert('#',ref)
    return ref
end
local function get_dir_pow(building)
    local ref=get_create_general_ref(building)
    return ref.anon_1,ref.anon_2
end
local function set_dir_pow(building,dir,pow)
    local ref=get_create_general_ref(building)
    ref.anon_1=dir
    ref.anon_2=pow
end
local function get_close_workshops(workshop)
    local ret={}
    local dirs={{x=0,y=-1,z=0},{x=1,y=0,z=0},{x=0,y=1,z=0},{x=-1,y=0,z=0}}
    for _,side in ipairs(dirs) do
        local pos={x=workshop.centerx+side.x*2,y=workshop.centery+side.y*2,z=workshop.z}
        local bld=dfhack.buildings.findAtTile(pos)
        if bld then
            table.insert(ret,bld)
        end
    end
    return ret
end
local function remove_ref( item )
    for i,v in ipairs(item.general_refs) do
        if v:getType()==df.general_ref_type.BUILDING_HOLDER then
            v:delete()
            item.general_refs:erase(i)
            return true
        end
    end
    return false
end
local function get_items( bld,tbl )
    for i=#bld.contained_items-1,0,-1 do
        local it=bld.contained_items[i]
        if it.use_mode==0 and not it.item.flags.in_job then
            local item=it.item
            table.insert(tbl,item)

            it:delete()
            bld.contained_items:erase(i)
            remove_ref(item)
            item.flags.removed=true
            --dfhack.items.remove(it.item,true)
            if not dfhack.items.moveToGround(item,{x=bld.centerx,y=bld.centery,z=bld.z}) then
                print("failed to move item")
            end
        end
    end
end
local function make_projectile( item,direction,power )
    local dirs={{x=0,y=-1,z=0},{x=1,y=0,z=0},{x=0,y=1,z=0},{x=-1,y=0,z=0}}
    local proj=dfhack.items.makeProjectile(item)
    if not proj then
        --TODO: put on ground?
        qerror("Failed to throw item:"..tostring(item))
        return
    end
    local dir=dirs[direction+1]
    proj.flags.no_impact_destroy=true
    proj.target_pos.x=proj.origin_pos.x+dir.x*power
    proj.target_pos.y=proj.origin_pos.y+dir.y*power
    proj.target_pos.z=proj.origin_pos.z+dir.z*power
    --parabolic?
    --high_flying?
    proj.min_ground_distance=power
    proj.min_hit_distance=power/3
    proj.fall_threshold=power
end
function flinger_update(wshop)
    if not wshop:isUnpowered() then
        local dir,power=get_dir_pow(wshop)
        --enum close shops
        local wshops=get_close_workshops(wshop)
        --get items
        local items={}
        for i,v in ipairs(wshops) do
            get_items(v,items)
        end
        local my_items=enum_items_in_region(wshop.x1,wshop.y1,wshop.x2,wshop.y2,wshop.z)
        --merge them in
        for k,v in pairs(my_items) do
            table.insert(items,v)
        end
        --fling items
        for i,v in ipairs(items) do
            v.pos={x=wshop.centerx,y=wshop.centery,z=wshop.z}
            make_projectile(v,dir,power)
        end
    end
end
local flinger_gears={{x=1,y=0},{x=0,y=1},{x=2,y=1},{x=1,y=2}}
builds.registerBuilding{
        name="AUTO_FLINGER",
        fix_impassible=true,
        consume=15,
        gears=flinger_gears,
        action={50,flinger_update},
        animate={
            isMechanical=true,
            frames=make_frames(flinger_gears)
        }
        }

flinger_sidebar=defclass(flinger_sidebar,guidm.WorkshopOverlay)

function flinger_sidebar:init(args)
    self:update_text()
    self:addviews{
    widgets.Panel{
        subviews = {
            widgets.Label{ text="Auto flinger", frame={t=1,l=1} },
            widgets.Label{ text={{text="Direction:"},{text=self:cb_getfield("dir_text")},
                {key="CUSTOM_D",key_sep="()",on_activate=self:callback("change_dir")}
                }, frame={t=3,l=1} },
            widgets.Label{ text={{text="Distance:"},{text=self:cb_getfield("power_text")},
                {text="+",key="CUSTOM_T",key_sep="()",on_activate=self:callback("add_pow")},
                {text="-",key="CUSTOM_R",key_sep="()",on_activate=self:callback("remove_pow")}
                }, frame={t=4,l=1} },
            widgets.Label{ text={{key='DESTROYBUILDING',key_sep=": ",text="Remove Building"}}, frame={b=2,l=1} },
            widgets.Label{ text={{key='LEAVESCREEN',key_sep=": ",text="Done"}}, frame={b=1,l=1} }
        }
    }
    }
end
function flinger_sidebar:add_pow()
    local d,p=get_dir_pow(self.workshop)
    p=p+1
    if p>25 then
        p=25
    end
    builds.setPower(self.workshop,0,5+p*5)
    set_dir_pow(self.workshop,d,p)
    self:update_text()
end
function flinger_sidebar:remove_pow()
    local d,p=get_dir_pow(self.workshop)
    p=p-1
    if p<2 then
        p=2
    end
    builds.setPower(self.workshop,0,5+p*5)
    set_dir_pow(self.workshop,d,p)
    self:update_text()
end
function flinger_sidebar:update_text()
    local dirs={"N","E","S","W"}
    local d,pow=get_dir_pow(self.workshop)

    self.dir_text=dirs[d+1]
    self.power_text=tostring(pow)
end
function flinger_sidebar:change_dir()
    local d,p=get_dir_pow(self.workshop)
    d=d+1
    if d>=4 then d=0 end
    set_dir_pow(self.workshop,d,p)
    self:update_text()
end

eventful.registerSidebar("AUTO_FLINGER",flinger_sidebar)


function make_auto_workshop(name,recipes,consume_power)
    consume_power=consume_power or 20
    local function wshop_update(wshop)
        if not wshop:isUnpowered() then
            local items={}
            for i,v in ipairs(wshops) do --not sure how it got here.. maybe some item inserted later?
                get_items(v,items)
            end
            local my_items=enum_items_in_region(wshop.x1,wshop.y1,wshop.x2,wshop.y2,wshop.z)
            --merge them in
            for k,v in pairs(my_items) do
                table.insert(items,v)
            end
            --process one item

            for i,v in ipairs(items) do

            end
        end
    end
    builds.registerBuilding{
        name=name,
        fix_impassible=true,
        consume=consume_power,
        auto_gears=true,
        action={50,wshop_update},
        animate={
            isMechanical=true,
            frames=make_frames(flinger_gears)
        }
        }
end