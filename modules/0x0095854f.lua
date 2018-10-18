-- ===============================================================
-- Main module of 0x0095854f mod.
-- Mod helps to reproduce FA issue when game crashes after ~30
-- minutes of intense game session.
-- 
-- Author: Spheroid
-- Creation date: 14.10.2018
-- ===============================================================
local MESSAGE_PREFIX = '<0x0095854f> '

local PERIOD_SECONDS = 0.1
local MAX_ARMIES_PER_ITERATION = 2
local UNIT_TYPES_PER_ITERATION = 2
local MIN_UNIT_COUNT_PER_SPAWN_COMMAND = 1
local MAX_UNIT_COUNT_PER_SPAWN_COMMAND = 4

local FULL_UNIT_TYPE_DIVERSITY_AT_UNIT_COUNT = 5000

local SHOW_SPAWNED_MESSAGE_PERIOD_SECONDS = 10

local ENABLED_CATEGORIES = {
	{category = categories.TECH1 - categories.STRUCTURE, proportion = 15},
	{category = categories.TECH2 - categories.STRUCTURE, proportion = 10},
	{category = categories.TECH3 - categories.STRUCTURE - categories.SUBCOMMANDER, proportion = 5},

	{category = categories.SUBCOMMANDER, proportion = 2},
	{category = categories.EXPERIMENTAL, proportion = 1},
	{category = categories.FACTORY, proportion = 1},

--	{category = categories.ALLUNITS, proportion = 1},
}

-- Skip units wich have broken scriptsets
local FORBIDDEN_UNITS = {
	'uea0001',
	'uea0003',
	'xrl0302',
	'xsc9011',
	'ual0401',
	'xrb2308',
}

local iterationEnabled = false
local lastArmyIndex = 0
local spawnedNumTotal = 0
local spawnedNumSession = 0

function ShowText(messageText)
	local PrintToScreen = import('/lua/ui/game/textdisplay.lua').PrintToScreen
	local textData = {text = messageText, location = 'center', size = 20, duration = 3}
	PrintToScreen(textData)
end

function IsForbiddenUnitId(id)
	for _, forbiddenId in FORBIDDEN_UNITS do
		if id == forbiddenId then
			return true
		end
	end
	-- Also skip 'civilian' units
	if string.sub(id, 3, 3) == 'c' then
		return true
	end

	return false
end

function GenEnabledCategoriesArray()
	local result = {}
	for _, categoryRecord in ENABLED_CATEGORIES do
		for n = 1, categoryRecord.proportion do
			table.insert(result, categoryRecord.category)
		end
	end
	return result
end

function GenFilteredUnitIdList()	
	local result = {}
	local categories = GenEnabledCategoriesArray()
	for _, category in categories do
		local idList = EntityCategoryGetUnitList(category)
		for _, id in idList do
			if IsForbiddenUnitId(id) then
				continue
			end
			table.insert(result, id)
		end
	end
	return result
end

local filteredUnitIdList = nil
function GetUnitIdList()
	if filteredUnitIdList == nil then
		filteredUnitIdList = GenFilteredUnitIdList()
	end

	return filteredUnitIdList
end

function GetUnitDiversityFactor()
	local result = spawnedNumTotal / FULL_UNIT_TYPE_DIVERSITY_AT_UNIT_COUNT
	if result < 0.0 then
		result = 0.0
	end
	if result > 1.0 then
		result = 1.0
	end

	return result
end
                              
function GetRandomUnitIdList(count, unitDiversityFactor)
	local allUnitIdList = GetUnitIdList()
	local allUnitIdListSize = table.getn(allUnitIdList)
	local unitSelectionLimit = math.floor(table.getn(allUnitIdList) * unitDiversityFactor)
	if unitSelectionLimit < 1 then
		unitSelectionLimit = 1
	end
	if unitSelectionLimit > allUnitIdListSize then
		unitSelectionLimit = allUnitIdListSize
	end

	local result = {}
	for n = 1, count do
		result[n] = allUnitIdList[Random(1, unitSelectionLimit)]
	end

	return result
end

function SpawnUnits(armyId, unitId, count)
	for n = 1, unitCount do	
		local cmd = 'CreateUnit ' .. unitId .. ' ' .. (armyId-1)
		ConExecuteSave(cmd)

		spawnedNumSession = spawnedNumSession + 1
		spawnedNumTotal = spawnedNumTotal + 1
	end
end

function GetSomeArmies(idCount)
	local armiesArray = {}
	local armies = GetArmiesTable().armiesTable	
	local maxArmyIndex = 0
	for armyId, _ in armies do
		armiesArray[maxArmyIndex] = armyId
		maxArmyIndex = maxArmyIndex + 1
	end

	local result = {}
	for n = 1, idCount do
		table.insert(result, armiesArray[lastArmyIndex])
		lastArmyIndex = lastArmyIndex + 1
		if lastArmyIndex >= maxArmyIndex then
			lastArmyIndex = 0
		end
	end

	return result
end

function X0095854f_iteration()
	local armies = GetSomeArmies(MAX_ARMIES_PER_ITERATION)
	for _, armyId in armies do
		unitIdList = GetRandomUnitIdList(UNIT_TYPES_PER_ITERATION, GetUnitDiversityFactor())
		unitCount = Random(MIN_UNIT_COUNT_PER_SPAWN_COMMAND, MAX_UNIT_COUNT_PER_SPAWN_COMMAND)
		for _, unitId in unitIdList do
			SpawnUnits(armyId, unitId, unitCount)
		end
	end
end

function X0095854f_loop()
	while(true) do
		WaitSeconds(PERIOD_SECONDS)
		if iterationEnabled then
			X0095854f_iteration()
		end
	end
end

function Init()
	local KeyMapper = import('/lua/keymap/keymapper.lua')
	local KeyDescriptions = import('/lua/keymap/keydescriptions.lua').keyDescriptions
	local categoryName = '0x0095854f'
	local actionId = '0x0095854f_toggle_spawning'
	local actionDescription = 'Toggle endless massive unit spawning'
	local defaultActionKey = 'Ctrl-F12'

	KeyMapper.SetUserKeyAction(actionId, {action = 'UI_Lua import("/Mods/0x0095854f/modules/0x0095854f.lua").ToggleSpawning()', category = categoryName, order = 100})
	KeyDescriptions[actionId] = actionDescription

	local keymap = KeyMapper.GetCurrentKeyMap(true)
	if not KeyMapper.IsKeyInMap(defaultActionKey, keymap) then
		KeyMapper.SetUserKeyMapping(defaultActionKey, nil, actionId)
	end

	ForkThread(X0095854f_loop)

	ForkThread(ShowMessageLoop)
end

function ShowToggleMessage(text)
	local message = MESSAGE_PREFIX .. text
	ShowText(message)
	LOG(message)
end

function ShowSpawnedNumMessage()
	ShowToggleMessage('Spawned: ' .. spawnedNumTotal .. ' (' .. spawnedNumSession .. ')')
end

function ShowMessageLoop()
	while(true) do
		WaitSeconds(SHOW_SPAWNED_MESSAGE_PERIOD_SECONDS)
		if iterationEnabled then
			ShowSpawnedNumMessage()
		end
	end
end      

function ToggleSpawning()
	iterationEnabled = not iterationEnabled

	if iterationEnabled then
		spawnedNumSession = 0
	end

	ShowToggleMessage('Unit spawning ' .. (iterationEnabled and 'ENABLED' or 'DISABLED'))

	if not iterationEnabled then
		ShowSpawnedNumMessage()
	end	
end
