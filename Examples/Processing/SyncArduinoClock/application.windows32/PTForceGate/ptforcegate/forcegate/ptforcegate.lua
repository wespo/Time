function init(virtual)
  if not virtual then
    -- Yay load from other file
    -- Ehh, some people think 10 is too short, so lets extend it a bit
    storage.maxRange = forcegateconfig.maxRange
    storage.force = forcegateconfig.force
    if storage.active == nil then
      storage.active = true
    end
    
    -- Gate connections
    storage.connectedGates = storage.connectedGates or {}
    -- Previous gate connection directions, to prevent random gate flipping
    storage.prevDirections = storage.prevDirections or {}
    -- Number of connections, not really used(Leftover from diagonal gates code)
    storage.connectionCount = storage.connectionCount or 0
    -- Maximum number of connections, also leftover from diagonal gates code
    storage.maxConnections = 4
    -- Relative lower left corner of gate query for theta = 0
    storage.queryStart = {0.5, -0.1}
    -- Relative top right corner of gate query for theta = 0
    storage.queryEnd = {storage.maxRange, 0.1}
    -- Relative lower left corner of force region for theta = 0
    storage.forceStart = {0, -0.5}
    -- Relative top right corener of force region for theta = 0
    storage.forceEnd = {storage.maxRange, 0.5}
    -- Dummy monsters used to spawn > 1 force regions
    storage.forceMonsters = {}
    -- Set interactive to flip gate directions
    entity.setInteractive(true)
    -- Initialize gate in main (entity.id() == 0 in init)
    storage.initialized = false
  end
end

-- Try finding gates in all 4 directions
function findGates()
  for i = 0, 3, 1 do
    tryConnect(i)
  end
end

-- Connect to the specified gate in the specified direction, attempting to direct gate in direction prevForce
function connect(targetId, direction, prevForce)
  -- If I have my own prevForce, use it
  if storage.prevDirections[tostring(direction)] ~= nil then
    prevForce = storage.prevDirections[tostring(direction)]
  end
  if storage.connectedGates[tostring(direction)] ~= nil then
    -- Prev force code for versions < 1.0.3
    prevForce = storage.connectedGates[tostring(direction)].forcedirection
    -- Disconnect previous connection in this direction
    disconnect(direction)
  end
  makeConnection(targetId, direction, false, prevForce)
  return prevForce
end

-- Try connecting in this direction, ignoring gate ignoreId
function tryConnect(direction, ignoreId)
  -- Make sure there isn't already a valid connection in this direction
  if ignoreId == nil and validateDirection(direction) then
    return
  end
  -- Loading prev force stuff
  local prevforce = nil
  if storage.prevDirections[tostring(direction)] ~= nil then
    prevForce = storage.prevDirections[tostring(direction)]
  end
  if storage.connectedGates[tostring(direction)] ~= nil then
    if storage.connectedGates[tostring(direction)].gateId ~= ignoreId and validateDirection(direction) then
      return
    end
    prevforce = storage.connectedGates[tostring(direction)].forcedirection
    -- Disconnect invalid connection
    disconnect(direction)
  end

  -- Search for gates in direction
  local currentAngle = direction * math.pi / 2
  local searchArea = getDirectionArea(storage.queryStart, storage.queryEnd, direction)
  local pos = entity.position()
  searchArea[1] = {searchArea[1][1] + pos[1] + 0.5, searchArea[1][2] + pos[2] + 0.5}
  searchArea[2] = {searchArea[2][1] + pos[1] + 0.5, searchArea[2][2] + pos[2] + 0.5}
  --world.logInfo("Gate %s is trying connect in direction %s", entity.id(), direction)
  local objects = world.objectQuery(searchArea[1], searchArea[2], {withoutEntityId = entity.id(), name = "ptforcegate", inSightOf = entity.id()})
  
  objects = sortQuery(objects, direction)
  --world.logInfo("Gate %s found %s in direction %s", entity.id(), objects, direction)
  if #objects > 0 then
    local i = 1
    while objects[i] ~= nil and (objects[i] == ignoreId or not checkAxis(direction, objects[i])) do
      -- If gate is not valid, check next closest gate
      i = i + 1
    end
    if objects[i] ~= nil then
      -- Establish connection
      local targetId = objects[i]
      prevforce = world.callScriptedEntity(targetId, "connect", entity.id(), flipDirection(direction), prevforce)
      makeConnection(targetId, direction, true, prevforce)
    end
  end
end

-- Build connection table
function makeConnection(targetId, direction, isOwner, prevforce)
  --world.logInfo("Entity %s is establishing a connection with entity %s. Owner: %s", entity.id(), targetId, isOwner)
  local pos = entity.position()
  pos = {pos[1] + 0.5, pos[2] + 0.5}

  local tarPos = world.entityPosition(targetId)
  tarPos = {tarPos[1] + 0.5, tarPos[2] + 0.5}
  
  local angle = direction * math.pi / 2
  
  storage.connectedGates[tostring(direction)] = nil
  local posDif = world.distance(tarPos, pos)
  local dist = world.magnitude(posDif)
  if isOwner then
    -- Owner of gate needs more data
    local animScale = {(dist - 1) / 10, 1}
    
    local forceMult = storage.force / dist
    local perp = {posDif[2], -posDif[1]}
    local forcedirection = {perp[1] / dist, perp[2] / dist}
    if prevforce ~= nil and not vectorEqual(forcedirection, prevforce) then
      perp = {-posDif[2], posDif[1]}
      forcedirection = {perp[1] / dist, perp[2] / dist}
    end
    local force = {perp[1] * forceMult, perp[2] * forceMult}
    local forceregion = getDirectionArea(storage.forceStart, {dist, storage.forceEnd[2]}, direction)
    --world.logInfo("Generated relative force region: %s", forceregion)
    forceregion = {
      forceregion[1][1] + pos[1], forceregion[1][2] + pos[2],
      forceregion[2][1] + pos[1], forceregion[2][2] + pos[2]
    }
    --world.logInfo("Generated absolute force region from %s: %s", pos, forceregion)
    
    local active = world.callScriptedEntity(targetId, "isActive")
    
    storage.connectedGates[tostring(direction)] = {
      forcedirection = forcedirection, 
      forceregion = forceregion,
      force = force,
      active = active,
      isOwner = isOwner,
      angle = angle,
      animationScale = animScale,
      gateId = targetId
    }
    storage.prevDirections[tostring(direction)] = forcedirection
  else
    -- Not owner only needs a bit of data
    local perp = {-posDif[2], posDif[1]}
    local forcedirection = {perp[1] / dist, perp[2] / dist}
    if prevforce ~= nil and not vectorEqual(forcedirection, prevforce) then
      perp = {posDif[2], -posDif[1]}
      forcedirection = {perp[1] / dist, perp[2] / dist}
    end
    
    storage.connectedGates[tostring(direction)] = {
      forcedirection = forcedirection,
      isOwner = isOwner,
      gateId = targetId
    }
    storage.prevDirections[tostring(direction)] = forcedirection
  end
  --world.logInfo("Gate %s connection table after connect: %s", entity.id(), storage.connectedGates)
  storage.connectionCount = storage.connectionCount + 1
  updateAnimationState()
end

-- Disconnect gate in direction
function disconnect(direction, ignoreId)
  --world.logInfo("Gate %s is disconnecting direction %s, ignore id %s", entity.id(), direction, ignoreId)
  if ignoreId ~= nil then
    local data = storage.connectedGates[tostring(direction)]
    -- Tell disconnected gate to attempt a new connection, ignoring this gate
    world.callScriptedEntity(data.gateId, "tryConnect", flipDirection(direction), ignoreId)
  end
  storage.connectedGates[tostring(direction)] = nil
  storage.connectionCount = storage.connectionCount - 1
  updateAnimationState()
end

-- Checks if there is a valid gate connection in direction
function validateDirection(direction)
  return 
    storage.connectedGates[tostring(direction)] ~= nil and
    world.callScriptedEntity(storage.connectedGates[tostring(direction)].gateId, "isInitialized") == true and
    world.callScriptedEntity(storage.connectedGates[tostring(direction)].gateId, "isGateConnected", flipDirection(direction)) == true
end

-- Disconnect gates that are no longer in this node's line of sight
function checkLoS()
  for direction,data in pairs(storage.connectedGates) do
    --world.logInfo("Checking LoS from %s (%s) to %s (%s)", entity.id(), entity.position(), data.gateId, world.entityPosition(data.gateId))
    if not entity.entityInSight(data.gateId) then
      --world.logInfo("LoS Check Failed: From %s to %s", entity.id(), data.gateId)
      disconnect(direction)
    end
  end
end

-- Sort nodes by distance from this node
function sortQuery(query, direction)
  local positions = {}
  for k,value in ipairs(query) do
    positions[tostring(value)] = world.entityPosition(value)
  end
  
  -- Different sorting functions for each direction
  local sortfunction = nil
  if direction == 0 then
    sortfunction = function(a, b)
      return positions[tostring(a)][1] < positions[tostring(b)][1]
    end
  elseif direction == 1 then
    sortfunction = function(a, b)
      return positions[tostring(a)][2] < positions[tostring(b)][2]
    end
  elseif direction == 2 then
    sortfunction = function(a, b)
      return positions[tostring(a)][1] > positions[tostring(b)][1]
    end
  else
    sortfunction = function(a, b)
      return positions[tostring(a)][2] > positions[tostring(b)][2]
    end
  end
  
  table.sort(query, sortfunction)

  return query
end

-- Checks if a gate is connected in this direction
function isGateConnected(direction)
  return storage.connectedGates[tostring(direction)] ~= nil
end

-- Checks if this node is initialized
function isInitialized()
  return storage.initialized
end

-- Ensures that the target node is in the right direction to connect
function checkAxis(direction, objectId)
  local pos = entity.position()
  local tarPos = world.entityPosition(objectId)
  local posDif = world.distance(tarPos, entity.position())
  if direction == 0 then
    return pos[2] == tarPos[2] and posDif[1] > 0
  elseif direction == 1 then
    return pos[1] == tarPos[1] and posDif[2] > 0
  elseif direction == 2 then
    return pos[2] == tarPos[2] and posDif[1] < 0
  else
    return pos[1] == tarPos[1] and posDif[2] < 0
  end
end

-- Flips a direction (0 = right, 1 = up, 2 = left, 3 = down)
function flipDirection(dir)
  return (dir + 2) % 4
end

-- Returns a new rectangle, rotated to direction
function getDirectionArea(qS, qE, direction)
  local oS = {}
  local oE = {}
  if direction == 0 then
    oS = {qS[1], qS[2]}
    oE = {qE[1], qE[2]}
  elseif direction == 1 then
    oS = {qS[2], qS[1]}
    oE = {qE[2], qE[1]}
  elseif direction == 2 then
    oS = {-qE[1], -qE[2]}
    oE = {-qS[1], -qS[2]}
  else
    oS = {-qE[2], -qE[1]}
    oE = {-qS[2], -qS[1]}
  end
  return {oS, oE}
end

-- Flip the connected gates
function flipGates()
  for direction = 0, 3, 1 do
    flipGate(direction, true)
  end
end

-- Flip the specified gate
function flipGate(direction, initiator, newForce)
  local data = storage.connectedGates[tostring(direction)]
  --world.logInfo("Flipping gate %s, current direction %s, newForce %s", direction, data.forcedirection, newForce)
  if data ~= nil and (newForce == nil or (newForce ~= nil and not vectorEqual(data.forcedirection, newForce))) then
    --world.logInfo("Flipping direction %s, angle %s", direction, data.forceangle)
    data.forcedirection = {-data.forcedirection[1], -data.forcedirection[2]}
    storage.prevDirections[tostring(direction)] = data.forcedirection
    if data.isOwner then
      -- Flip the force as well
      data.force = {-data.force[1], -data.force[2]}
    end
    if initiator then
      world.callScriptedEntity(data.gateId, "flipGate", flipDirection(direction, false, newForce))
    end
  elseif data == nil and newForce ~= nil then
    storage.prevDirections[tostring(direction)] = newForce
  end
  updateAnimationState()
end

-- Sets whether or not the node is active
function setActive(active)
  storage.active = active
  for direction,data in pairs(storage.connectedGates) do
    if data.isOwner then
      --data.active = active
    else
      world.callScriptedEntity(data.gateId, "setGateActive", flipDirection(direction), active)
    end
  end
  updateAnimationState()
end

-- Sets whether or not the gate is active
function setGateActive(direction, active)
  storage.connectedGates[tostring(direction)].active = active
  updateAnimationState()
end

-- Apply gate forces
function applyForce()
  local forceCount = 0
  for direction,data in pairs(storage.connectedGates) do
    if data.isOwner and data.active and storage.active then
      --world.logInfo("Gate %s %s is applying force %s in region %s", entity.id(), entity.position(), data.force, data.forceregion)
      forceCount = forceCount + 1
      if forceCount > 1 then
        -- Spawn dummy monsters for more than 1 forceregion
        local mId = storage.forceMonsters[forceCount - 1]
        if mId == nil or not world.entityExists(mId) or not world.callScriptedEntity(mId, "isForceMonster") then
          local pos = entity.position()
          pos = {pos[1] + 0.5, pos[2] + 0.5}
          mId = world.spawnMonster("ptforcemonster", pos)
          storage.forceMonsters[forceCount - 1] = mId
        end
        world.callScriptedEntity(mId, "setForceToApply", data.forceregion, data.force)
      else
        entity.setForceRegion(data.forceregion, data.force)
      end
    end
  end
  -- Clean up unneeded dummy monsters
  for count = forceCount, #storage.forceMonsters, 1 do
    local mId = storage.forceMonsters[count]
    if mId ~= nil then
      if world.entityExists(mId) and world.callScriptedEntity(mId, "isForceMonster") then
        world.callScriptedEntity(mId, "kill")
      end
      storage.forceMonsters[count] = nil
    end
  end
end

-- Check vector equality
function vectorEqual(u, v)
  return u[1] == v[1] and u[2] == v[2]
end

function onNodeConnectionChange()
  checkNodes()
end

function onInboundNodeChange(args)
  checkNodes()
end

-- Clean up connections on death
function die()
  for direction,data in pairs(storage.connectedGates) do
    disconnect(direction, entity.id())
  end
  storage.prevDirections = {}
  for count = 1, #storage.forceMonsters, 1 do
    local mId = storage.forceMonsters[count]
    if mId ~= nil then
      if world.entityExists(mId) and world.callScriptedEntity(mId, "isForceMonster") then
        world.callScriptedEntity(mId, "kill")
      end
      storage.forceMonsters[count] = nil
    end
  end
end

-- Flip gates on interaction
function onInteraction(args)
  --world.logInfo("Gate %s connection table: %s", entity.id(), storage.connectedGates)
  flipGates()
  --setActive(not storage.active)
end

-- Update gate graphics
function updateAnimationState()
  if storage.active then
    entity.setAnimationState("gatestate", "on")
  else
    entity.setAnimationState("gatestate", "off")
  end
  local ang = {0, 0}
  local count = 1
  -- Draw gate beams
  for direction,data in pairs(storage.connectedGates) do
    ang = {ang[1] + data.forcedirection[1], ang[2] + data.forcedirection[2]}
    if data.isOwner and data.active and storage.active then
      entity.rotateGroup("beam" .. count, data.angle)
      entity.scaleGroup("beam" .. count, data.animationScale)
      count = count + 1
    end
  end
  for i = count, storage.maxConnections, 1 do
    entity.scaleGroup("beam" .. i, {0, 1})
  end
  -- Draw direction arrow
  if vectorEqual(ang, {0, 0}) then
    entity.setAnimationState("arrowstate", "zero")
    entity.rotateGroup("direction", 0)
  else
    entity.setAnimationState("arrowstate", "normal")
    entity.rotateGroup("direction", math.atan2(ang[2], ang[1]))
  end
end

-- Toggles gate activeness with wires
function checkNodes()
  if entity.isInboundNodeConnected(0) then
    setActive(entity.getInboundNodeLevel(0))
  end
end

function main()
  if not storage.initialized then
    -- Initalize gates
    --validateConnections()
    findGates()
    updateAnimationState()
    storage.initialized = true
    --world.logInfo("Gate %s initialized connection table: %s", entity.id(), storage.connectedGates)
  end
  -- Check line of sight, find new gates, apply force
  checkLoS()
  findGates()
  applyForce()
end

function isActive()
  return storage.active
end

function relayFunction(name, args)
  return _ENV[name](unpack(args))
end