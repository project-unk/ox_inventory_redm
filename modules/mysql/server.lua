local Query = {
	SELECT_STASH = 'SELECT data FROM ox_inventory WHERE owner = ? AND name = ?',
	UPDATE_STASH = 'INSERT INTO ox_inventory (owner, name, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
	SELECT_GLOVEBOX = 'SELECT plate, glovebox FROM `{vehicle_column}` WHERE plate = ?',
	SELECT_TRUNK = 'SELECT plate, trunk FROM `{vehicle_column}` WHERE plate = ?',
	SELECT_PLAYER = 'SELECT inventory FROM `{user_column}` WHERE {charId} = ?',
	UPDATE_TRUNK = 'UPDATE `{vehicle_column}` SET trunk = ? WHERE plate = ?',
	UPDATE_GLOVEBOX = 'UPDATE `{vehicle_column}` SET glovebox = ? WHERE plate = ?',
	UPDATE_PLAYER = 'UPDATE `{user_column}` SET inventory = ? WHERE {charId} = ?',
}

do
	local playerColumn, vehicleColumn, charId

	if shared.framework == 'ox' then
		playerColumn = 'characters'
		vehicleColumn = 'vehicles'
	elseif shared.framework == 'esx' then
		playerColumn = 'users'
		vehicleColumn = 'owned_vehicles'
	elseif shared.framework == 'qbr' then
		playerColumn = 'players'
		vehicleColumn = 'player_vehicles'
		charId = 'id'
	elseif shared.framework == 'redem' then
		playerColumn = 'characters'
		vehicleColumn = 'stables'
		charId = 'identifier'
	elseif shared.framework == 'vorp' then
		playerColumn = 'characters'
		vehicleColumn = 'stables'
		charId = 'charidentifier'
	end

	for k, v in pairs(Query) do
		Query[k] = v:gsub('{user_column}', playerColumn):gsub('{vehicle_column}', vehicleColumn):gsub('{charId}', charId)
	end
end

function MySQL:loadPlayer(identifier)
	local inventory = self.prepare.await(Query.SELECT_PLAYER, { identifier })
	return inventory and json.decode(inventory)
end

function MySQL:savePlayer(owner, inventory)
	return self.prepare(Query.UPDATE_PLAYER, { inventory, owner })
end

function MySQL:saveStash(owner, dbId, inventory)
	return self.prepare(Query.UPDATE_STASH, { owner or '', dbId, inventory })
end

function MySQL:loadStash(owner, name)
	return self.prepare.await(Query.SELECT_STASH, { owner or '', name })
end

function MySQL:saveGlovebox(plate, inventory)
	return self.prepare(Query.UPDATE_GLOVEBOX, { inventory, plate })
end

function MySQL:loadGlovebox(plate)
	return self.prepare.await(Query.SELECT_GLOVEBOX, { plate })
end

function MySQL:saveTrunk(plate, inventory)
	return self.prepare(Query.UPDATE_TRUNK, { inventory, plate })
end

function MySQL:loadTrunk(plate)
	return self.prepare.await(Query.SELECT_TRUNK, { plate })
end

function MySQL:saveInventories(trunks, gloveboxes, stashes)
	if #trunks > 0 then
		self.prepare(Query.UPDATE_TRUNK, trunks)
	end

	if #gloveboxes > 0 then
		self.prepare(Query.UPDATE_GLOVEBOX, gloveboxes)
	end

	if #stashes > 0 then
		self.prepare(Query.UPDATE_STASH, stashes)
	end
end

function MySQL:selectLicense(name, owner)
	return self.scalar.await('SELECT 1 FROM user_licenses WHERE type = ? AND owner = ?', { name, owner })
end
