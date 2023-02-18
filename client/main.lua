local entities = {}
local QBCore = exports['qb-core']:GetCoreObject()
local closestZone = Config.Zones.Zones[1]
local hasLicense = false

local function checkLicense()
	local PlayerData = QBCore.Functions.GetPlayerData()
	if PlayerData.metadata["licences"] and PlayerData.metadata["licences"].hunting and QBCore.Functions.HasItem("huntinglicense") then
		hasLicense = true
		print("has hunting license")
	else
		print("no license")
		hasLicense = false
	end
end

-- create map blip zones if enabled in config
if Config.Zones.UseZones == true then
	CreateThread(function()
		checkLicense()
		if hasLicense then
			for k, v in pairs(Config.Zones.Zones) do
				local zones = AddBlipForRadius(v['coords'].x, v['coords'].y, v['coords'].z, v.radius)
				SetBlipHighDetail(zones, true)
				SetBlipColour(zones, v.zonecolour)
				SetBlipAlpha(zones, 128)
				local zones = AddBlipForCoord(v['coords'].x, v['coords'].y, v['coords'].z)
				SetBlipSprite(zones, v.id)
				SetBlipDisplay(zones, 4)
				SetBlipScale(zones, 0.6)
				SetBlipColour(zones, v.colour)
				SetBlipAsShortRange(zones, true)
				BeginTextCommandSetBlipName('STRING')
				AddTextComponentString(v.title)
				EndTextCommandSetBlipName(zones)
			end
		end
	end)
end

-- get closest zone
Citizen.CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Citizen.Wait(0)
	end

	while true do
		local playerPed = GetPlayerPed( -1)
		local x, y, z = table.unpack(GetEntityCoords(playerPed, true))
		local minDistance = 100000
		for k, v in pairs(Config.Zones.Zones) do
			dist = Vdist(v['coords'].x, v['coords'].y, v['coords'].z, x, y, z)
			if dist < minDistance then
				minDistance = dist
				closestZone = v
			end
		end
		Citizen.Wait(15000)
	end
end)

-- if within zone
Citizen.CreateThread(function()
	while not NetworkIsPlayerActive(PlayerId()) do
		Citizen.Wait(0)
	end

	while true do
		Citizen.Wait(0)
		local player = GetPlayerPed( -1)
		local pos = GetEntityCoords(player, 1)
		local ground
		local x, y, z = table.unpack(GetEntityCoords(player, true))
		local dist = Vdist(closestZone['coords'].x, closestZone['coords'].y, closestZone['coords'].z, x, y, z)

		checkLicense() -- only spawn animals if player has a license

		if dist <= closestZone['radius'] and hasLicense then
			if #entities < closestZone['count'] then
				print(#entities .. ' ' .. closestZone['count'])
				RequestModel(closestZone['ped'])
				while not HasModelLoaded(closestZone['ped']) or not HasCollisionForModelLoaded(closestZone['ped']) do
					Wait(1)
				end
			end

			posX = pos.x + math.random( -closestZone['dist'], closestZone['dist'])
			posY = pos.y + math.random( -closestZone['dist'], closestZone['dist'])
			Z = pos.z + 999.0
			heading = math.random(0, 359) + .0

			ground, posZ = GetGroundZFor_3dCoord(posX + .0, posY + .0, Z, 1)

			if (ground) and #entities < closestZone['count'] then
				ped = CreatePed(28, closestZone['ped'], posX, posY, posZ, heading, true, false)
				SetEntityAsMissionEntity(ped, true, true)
				TaskWanderStandard(ped, 10.0, 10)
				SetModelAsNoLongerNeeded(ped)
				SetPedAsNoLongerNeeded(ped) -- despawn when player no longer in the area
				table.insert(entities, ped)

				if Config.Zones.Debug then
					local blip = AddBlipForEntity(ped)
					SetBlipSprite(blip, 442) --animal blip when debug enabled
					SetBlipColour(blip, 0)
					BeginTextCommandSetBlipName("STRING")
					AddTextComponentString("spawned entity")
					EndTextCommandSetBlipName(blip)
				end
			end

			if (#entities >= closestZone['count']) then -- spawn more animals after time limit (up to spawn cap)
				Citizen.Wait(closestZone['respawn'])
				entities = {}
			end
		end
	end
end)