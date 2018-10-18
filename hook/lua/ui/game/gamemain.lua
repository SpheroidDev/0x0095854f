-- ===============================================================
-- Mod loading hook
-- 
-- Author: Spheroid
-- Creation date: 14.10.2018
-- ===============================================================
local modModules = '/Mods/0x0095854f/modules/'

local OriginalCreateUI = CreateUI 
function CreateUI(isReplay) 
	OriginalCreateUI(isReplay)
	if not isReplay then
		import(modModules .. '0x0095854f.lua').Init()
	end
end
