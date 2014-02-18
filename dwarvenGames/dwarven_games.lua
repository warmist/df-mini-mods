local eventful=require "plugins.eventful"

function getLastJobLink()
    local st=df.global.world.job_list
    while st.next~=nil do
        st=st.next
    end
    return st
end
function addNewJob(job)
    local lastLink=getLastJobLink()
    local newLink=df.job_list_link:new()
    newLink.prev=lastLink
    lastLink.next=newLink
    newLink.item=job
    job.list_link=newLink
end
function UnassignJob(job,unit,unit_pos)
    unit.job.current_job=nil
end
function makeJob(args)
    local newJob=df.job:new()
    newJob.id=df.global.job_next_id
    df.global.job_next_id=df.global.job_next_id+1
    --newJob.flags.special=true
    newJob.job_type=args.job_type
    newJob.completion_timer=-1

    newJob.pos:assign(args.pos)
    args.job=newJob
    local failed
    for k,v in ipairs(args.pre_actions or {}) do
        local ok,msg=v(args)
        if not ok then
            failed=msg
            break
        end
    end
    if failed==nil then
        AssignUnitToJob(newJob,args.unit,args.from_pos)
        for k,v in ipairs(args.post_actions or {}) do
            local ok,msg=v(args)
            if not ok then
                failed=msg
                break
            end
        end
        if failed then
            UnassignJob(newJob,args.unit)
        end
    end
    if failed==nil then
        addNewJob(newJob)
        return newJob
    else
        newJob:delete()
        return false,failed
    end
    
end
function AssignUnitToJob(job,unit,unit_pos)
    job.general_refs:insert("#",{new=df.general_ref_unit_workerst,unit_id=unit.id})
    unit.job.current_job=job
    unit_pos=unit_pos or {x=job.pos.x,y=job.pos.y,z=job.pos.z}
    unit.path.dest:assign(unit_pos)
    return true
end
function AssignBuildingRef(bld)
    return function(args)
        args.job.general_refs:insert("#",{new=df.general_ref_building_holderst,building_id=bld.id})
        bld.jobs:insert("#",args.job)
    end
end

function makeWaitJob(building,unit)
    local args={}
    args.pos={x=building.centerx,y=building.centery,z=building.z}
    args.job_type=df.job_type.CustomReaction
    args.pre_actions={
        function(args) 
            args.job.reaction_name="LUA_HOOK_WAIT_FOR_PLAYERS"
            args.job.completion_timer=math.random(100,1000) --todo think of normal value
        end
    }
    args.post_actions={AssignBuildingRef(building)}
    args.unit=unit
    local ok,msg=makeJob(args)
    if not ok then
        qerror(msg)
    end
end
function addWaitJob(wshop)
    --[[if math.random()<0.65 then
        return
    end]]
    if #wshop.jobs>0 then --already playing/waiting
        return
    end
    local DISTANCE=25
    local dsq=DISTANCE*DISTANCE
    print("Trying to add job:"..tostring(wshop))
    local dwarfs_near={}
    for k,v in pairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(v) and v.job.current_job==nil then
            local dx=wshop.centerx-v.pos.x
            local dy=wshop.centery-v.pos.y
            local dz=wshop.z-v.pos.z
            if dx*dx+dy*dy<dsq and dz==0 then --only on same level
                table.insert(dwarfs_near,v)
            end
        end
    end
    if #dwarfs_near>0 then
        print(string.format("found %d dwarfs nearby",#dwarfs_near))
        makeWaitJob(wshop,dwarfs_near[math.random(1,#dwarfs_near-1)])
    end
end
function waitDone( reaction,unit )
    --check players
    --local players=getPlayers(unit.job.current_job) todo write this
    --start playing

end
eventful.registerReaction("LUA_HOOK_WAIT_FOR_PLAYERS",waitDone)
require("plugins.building-hacks").registerBuilding{name="DWARVEN_GAMES_CHAIR",action={500,addWaitJob}}