function server.hasGroup(inv, group)
	if type(group) == 'table' then
		for name, rank in pairs(group) do
			local groupRank = inv.player.groups[name]
			if groupRank and groupRank >= (rank or 0) then
				return name, groupRank
			end
		end
	else
		local groupRank = inv.player.groups[group]
		if groupRank then
			return group, groupRank
		end
	end
end

function server.setPlayerData(player)
	if not player.groups then
		shared.warning(("server.setPlayerData did not receive any groups for '%s'"):format(player?.name or GetPlayerName(player)))
	end

	return {
		source = player.source,
		name = player.name,
		groups = player.groups or {},
		sex = player.sex,
		dateofbirth = player.dateofbirth,
	}
end

if shared.framework == 'esx' then
	local ESX = exports['es_extended']:getSharedObject()

	if ESX.CreatePickup then
		error('ox_inventory requires a ESX Legacy v1.6.0 or above, refer to the documentation.')
	end

	ESX = {
		GetUsableItems = ESX.GetUsableItems,
		GetPlayerFromId = ESX.GetPlayerFromId,
		UseItem = ESX.UseItem
	}

	server.UseItem = ESX.UseItem
	server.UsableItemsCallbacks = ESX.GetUsableItems
	server.GetPlayerFromId = ESX.GetPlayerFromId

	-- Accounts that need to be synced with physical items
	server.accounts = {
		money = 0,
		black_money = 0,
	}

	function server.setPlayerData(player)
		local groups = {
			[player.job.name] = player.job.grade
		}

		return {
			source = player.source,
			name = player.name,
			groups = groups,
			sex = player.sex or player.variables.sex,
			dateofbirth = player.dateofbirth or player.variables.dateofbirth,
		}
	end

	RegisterServerEvent('ox_inventory:requestPlayerInventory', function()
		local source = source
		local player = server.GetPlayerFromId(source)

		if player then
			exports.ox_inventory:setPlayerInventory(player, player?.inventory)
		end
	end)
elseif shared.framework == 'redemrp' then
	function server.getPlayerData(source, user)
		return {
			--sex, groups, dob
			source = source,
			name = user.getName(),
			gender = user.getSessionVar('gender'),
			identifier = user.getSessionVar('charid'),
			inventory = {},
		}
	end

	AddEventHandler('redemrp:playerLoaded', function(serverId, user)
		local source = serverId
		local player = server.getPlayerData(source, user)

		if player then
			exports.ox_inventory:setPlayerInventory(player, player?.inventory)
		end
	end)
elseif shared.framework == 'qbr' then
	if GetResourceState('qbr-inventory'):find('start') then
		shared.warning('Detected [qbr-inventory], stopping resource!')
		StopResource('qbr-inventory')
	end

	function server.getPlayerData(data)
		local userData = data.PlayerData

		return {
			source = userData.source,
			name = userData.charinfo.firstname .. ' ' .. userData.charinfo.lastname,
			gender = userData.charinfo.gender,
			identifier = userData.id,
		}
	end

	AddEventHandler('QBCore:Server:PlayerLoaded', function(data)
		local player = server.getPlayerData(data)

		if player then
			exports.ox_inventory:setPlayerInventory(player)
		end
	end)
elseif shared.framework == 'vorp' then

	-- Check lua schedule, if you are interested in this part
	-- Basically we are wrapping vorp_inventory export and provide functionn for it, which emulates vorp API functions.

	function provideExport(exportName, func)
		AddEventHandler(('__cfx_export_vorp_inventory_%s'):format(exportName), function(setCB)
			setCB(func)
		end)
	end

	-- TODO: Save player inventory on drop / exit.
	-- TODO: Define missing inventory events
	-- TODO: Define all options which are used with vorpInvApi object and handle internally by ox_inventory
	-- TODO: Check inventory images and missing items from vorp_inventory.

	AddEventHandler('vorpCore:canCarryWeapons', function(serverId, amount, cb) 
		cb(true)
	end)

	AddEventHandler('vorpCore:canCarryItems', function(serverId, amount, cb) 
		cb(true) 
	end)

	AddEventHandler('vorpCore:canCarryItem', function(player, itemName, amount, cb) 
		cb(true) 
	end)

	local emulatorLoaded = false

	function server.emulatorAPI()
		if not emulatorLoaded then
			emulatorLoaded = true
			shared.warning('Loading backwards compatiblity for vorp_inventory.')
		end

		return {
			RegisterUsableItem = function(item)
				if not shared.items[item:lower()] then
					return shared.warning('Item [' .. item .. '] is not registered. -> from script [' .. GetInvokingResource() .. ']')
				end
			end,

			addItem = function(serverId, item, count)
				print('addItem' .. serverId, item, count)

				exports.ox_inventory:AddItem(serverId, item, count, nil, nil, function(success, reason)
					if success then
						print(json.encode(reason, {indent=true}))
					else
						print('Failed to addItem' .. reason .. '[' .. item .. ']')
					end
				end)
			end,

			removeItem = function(serverId, item, count)
				print('removeItem' .. serverId, item, count)
				exports.ox_inventory:RemoveItem(serverId, item, count)
			end,

			createWeapon = function(serverId, itemName, label)
				print('createWeapon ' .. serverId, itemName, label)

				exports.ox_inventory:AddItem(serverId, itemName, 1, nil, nil, function(success, reason)
					if success then
						print(json.encode(reason, {indent=true}))
					else
						print('Failed to addItem' .. reason .. '[' .. itemName .. ']')
					end
				end)
			end
		}
	end
		
	provideExport('vorp_inventoryApi', server.emulatorAPI)

	if GetResourceState('vorp_inventory'):find('start') then
		shared.warning('Detected [vorp_inventory], stopping resource!')
		StopResource('vorp_inventory')
	end

	function server.getPlayerData(source, data)
		return {
			source = source,
			name = data.firstname .. ' ' .. data.lastname,
			gender = 'male', -- TODO: Refactor
			identifier = data.charIdentifier,
		}
	end

	AddEventHandler('vorp:SelectedCharacter', function(source, data)
		local player = server.getPlayerData(source, data)

		if player then
			exports.ox_inventory:setPlayerInventory(player)
		end
	end)
end

tprint = function(tbl, indent)
    indent = indent or 0
    for k, v in pairs(tbl) do
        local tblType = type(v)
        local formatting = ("%s ^3%s:^0"):format(string.rep("  ", indent), k)

        if tblType == "table" then
            print(formatting)
            tprint(v, indent + 1)
        elseif tblType == 'boolean' then
            print(("%s^1 %s ^0"):format(formatting,v))
        elseif tblType == "function" then
            print(("%s^9 %s ^0"):format(formatting,v))
        elseif tblType == 'number' then
            print(("%s^5 %s ^0"):format(formatting,v))
        elseif tblType == 'string' then
            print(("%s ^2'%s' ^0"):format(formatting,v))
        else
            print(("%s^2 %s ^0"):format(formatting,v))
        end
    end
end