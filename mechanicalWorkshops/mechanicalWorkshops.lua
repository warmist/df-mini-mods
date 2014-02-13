local builds=require 'plugins.building-hacks'
local dragon_engine_dirs={
    S={gear={x=0,y=0},spew={x=0,y=5,dx=0,dy=1,mx=0,my=3}}, --spew place, direction, magma place
    N={gear={x=0,y=4},spew={x=0,y=-1,dx=0,dy=-1,mx=0,my=1}},
    W={gear={x=4,y=0},spew={x=-1,y=0,dx=-1,dy=0,mx=1,my=0}},
    E={gear={x=0,y=0},spew={x=5,y=0,dx=1,dy=0,mx=3,my=0}},
    }
function getMagma(pos)
    local flags=dfhack.maps.getTileFlags(pos)
    return flags.liquid_type, flags.flow_size
end
function removeLiquid(pos)
    local flags=dfhack.maps.getTileFlags(pos)
    flags.flow_size=0
    dfhack.maps.enableBlockUpdates(dfhack.maps.getBlock(pos.x/16,pos.y/16,pos.z),true)
end
function makeSpewFire(spew)
    return function(wshop)
        if not wshop:isUnpowered() then
            if math.random() >0.7 then --30% chance not to fire, for a bit of random look
                return
            end
            local pos={x=wshop.x1,y=wshop.y1,z=wshop.z}
            local mPos={x=pos.x+spew.mx,y=pos.y+spew.my,z=pos.z}
            local sPos={x=pos.x+spew.x,y=pos.y+spew.y,z=pos.z}
            --check for magma
            local isMagma,amount=getMagma(mPos)
            if amount>0 then
                local flowType
                if isMagma then
                    flowType=df.flow_type.Dragonfire
                    local flow=dfhack.maps.spawnFlow(sPos,flowType,6,-1,120*amount/7)
                    flow.dest={x=sPos.x+spew.dx*5,y=sPos.y+spew.dy*5,z=sPos.z}
                    
                else
                    
                    for i=0,math.ceil(amount/1.3) do
                        dfhack.maps.spawnFlow({x=sPos.x+spew.dx*i,y=sPos.y+spew.dy*i,z=sPos.z},df.flow_type.Mist,6,-1,120*(amount-i)/7)
                    end
                    
                end
                --consume the liquid
                removeLiquid(mPos)
            end
        end
    end
end
function registerDragonEngine(dir,data)
    builds.registerBuilding{
        name="DRAGON_ENGINE_"..dir,
        fix_impassible=true,
        consume=25,
        gears={data.gear},
        action={50,makeSpewFire(data.spew)},
        animate={
            isMechanical=true,
            frames={
            {{x=data.gear.x,y=data.gear.y,42,7,0,0}}, --first frame, 1 changed tile
            {{x=data.gear.x,y=data.gear.y,15,7,0,0}} -- second frame, same
            }
        }
        }
    print("Registered mechanical workshop:".."DRAGON_ENGINE_"..dir)
end
for k,v in pairs(dragon_engine_dirs) do
    registerDragonEngine(k,v)
end