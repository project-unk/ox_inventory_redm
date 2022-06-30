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