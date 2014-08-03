
local eventful=require 'plugins.eventful'
local guidm   =require 'gui.dwarfmode'
local widgets =require 'gui.widgets'

hobby_worktable_sidebar=nil
hobby_worktable_sidebar = defclass(hobby_worktable_sidebar, guidm.WorkshopOverlay)
function hobby_worktable_sidebar:init(args)
	local owner
	if #self.workshop.parents>0 and self.workshop.parents[0].owner~=nil then
		owner=self.workshop.parents[0].owner
	end
	local owner_text = {}
	if owner then
		owner_text.text=dfhack.TranslateName(owner.name)
	else
		owner_text.text="<no owner, disabled>"
		owner_text.pen={fg=COLOR_LIGHTRED}
	end
    self:addviews{
    widgets.Panel{
        subviews = {
            widgets.Label{ text="Personal worktable", frame={t=1,l=1} },
            widgets.Label{ text={{text="Owner:"},owner_text}, frame={t=3,l=1} },
            widgets.Label{ text={{key='DESTROYBUILDING',key_sep=": ",text="Remove Building"}}, frame={b=2,l=1} },
            widgets.Label{ text={{key='LEAVESCREEN',key_sep=": ",text="Done"}}, frame={b=1,l=1} }
        }
    }
    }
end
function hobby_worktable()
	print("Hobby work!")
end
function make_job( reaction_name,unit,building )
	local newJob=df.job:new()
	newJob:assign{
	job_type=df.job_type.CustomReaction,
	reaction_name=reaction_name,
	general_refs={{new=df.general_ref_building_holderst,building_id=building.id},{new=df.general_ref_unit_workerst,unit_id=unit.id}},
	pos={x=building.centerx,y=building.centery,z=building.z},
	completion_timer=-1,
	}
	dfhack.job.linkIntoWorld(newJob,true)
	unit.path.dest:assign{x=newJob.pos.x,y=newJob.pos.y,z=newJob.pos.z}
	unit.job.current_job=newJob
	building.jobs:insert("#",newJob)
end
function personal_job(reaction_name,chance)
	local callback=function(wshop)
		--[[
		if math.random()<chance/100 then
        	return
	    end
	    ]]
	    if #wshop.parents==0 then return end
	    local owner=wshop.parents[0].owner
	    if owner==nil then return end --this works only for owned buildings
	    if owner.job.current_job~=nil then return end

	    make_job(reaction_name,owner,wshop)
	end
	return callback
end
eventful.registerSidebar("HOBBY_WORKSHOP",hobby_worktable_sidebar)
eventful.registerReaction("LUA_HOOK_HOBBY_WORKTABLE",hobby_worktable)
require("plugins.building-hacks").registerBuilding{name="HOBBY_WORKSHOP",action={500,personal_job("LUA_HOOK_HOBBY_WORKTABLE",65)},canBeRoomSubset=1}