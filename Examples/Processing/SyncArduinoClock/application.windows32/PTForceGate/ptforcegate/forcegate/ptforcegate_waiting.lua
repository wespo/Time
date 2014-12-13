function init(virtual)
  if not virtual then
    storage.maxRange = 10
    storage.force = 20
    storage.active = storage.active or false
    storage.connectedGates = storage.connectedGates or {}
    storage.connectionCount = storage.connectionCount or 0
    storage.maxConnections = 2
    storage.initialized = false
  end
end

function findGates(ignoreIds)
  local objects = world.objectQuery(entity.position(), storage.maxRange, {withoutEntityId = entity.id(), name = "ptforcegate", order = "nearest"})
  world.logInfo("Entity %s found gates: %s", entity.id(), objects)
  for entityId,_ in pairs(ignoreIds) do
    if storage.connectedGates[entityId] ~= nil then
      storage.connectedGates[entityId] = nil
      storage.connectionCount = storage.connectionCount - 1
    end
  end
  if #objects > 0 then
    ignoreIds[tostring(entity.id())] = true
    local i = 1
    while storage.connectionCount < storage.maxConnections and i <= #objects do
      local objectId = objects[i]
      if ignoreIds[tostring(objectId)] == nil and world.callScriptedEntity(objectId, "tryConnect", entity.id(), ignoreIds) then
        makeConnection(objectId, true)
      end
      i = i + 1
    end
  end
end

function tryConnect(targetId, ignoreIds)
  if storage.connectionCount < storage.maxConnections then
    makeConnection(targetId, false)
    return true
  else
    local objects = world.objectQuery(entity.position(), storage.maxRange, {withoutEntityId = entity.id(), name = "ptforcegate", order = "nearest"})
    local connectionMade = false
    if #objects > 0 then
      local visited = {}
      local i = 1
      while i <= storage.maxConnections and i <= #objects do
        local objectId = objects[i]
        visited[tostring(objectId)] = true
        if objectId == targetId then
          makeConnection(targetId, false)
          connectionMade = true
        end
        i = i + 1
      end
      for key,_ in pairs(storage.connectedGates) do
        if visited[key] == nil then
          disconnect(key, ignoreIds)
        end
      end
    end
    return connectionMade
  end
end

function makeConnection(targetId, isOwner)
  world.logInfo("Entity %s is establishing a connection with entity %s", entity.id(), targetId)
  local pos = entity.position()
  pos = {pos[1] + 0.5, pos[2] + 0.5}

  local tarPos = world.entityPosition(targetId)
  tarPos = {tarPos[1] + 0.5, tarPos[2] + 0.5}
  
  if isOwner then
    local posDif = world.distance(tarPos, pos)
    local angle = math.atan2(posDif[2], posDif[1])
    local dist = world.magnitude(posDif)
    local animScale = {dist / 10, 1}
    
    local forceMult = storage.force / dist
    local perp = {-posDif[2], posDif[1]}
    local forceangle = math.atan2(perp[2], perp[1])
    local force = {perp[1] * forceMult, perp[2] * forceMult}
    local active = world.callScriptedEntity(targetId, "isActive")
    
    storage.connectedGates[tostring(targetId)] = {
      forceangle = forceangle, 
      force = force,
      active = active,
      isOwner = isOwner,
      angle = angle,
      animationScale = animScale
    }
  else
    local posDif = world.distance(tarPos, pos)
    
    local perp = {posDif[2], -posDif[1]}
    local forceangle = math.atan2(perp[2], perp[1])
    
    storage.connectedGates[tostring(targetId)] = {
      forceangle = forceangle, 
      active = active,
      isOwner = isOwner
    }
  end
  storage.connectionCount = storage.connectionCount + 1
  updateAnimationState()
end

function disconnect(targetId, ignore)
  storage.connectedGates[tostring(targetId)] = nil
  ignore[tostring(entity.id())] = true
  world.callScriptedEntity(targetId, "findGates", ignore)
  storage.connectionCount = storage.connectionCount - 1
  updateAnimationState()
end

function isConnectionValid(targetId)
  return storage.connectedGates[tostring(targetId)] ~= nil
end

function validateConnections()
  for targetId,data in pairs(storage.connectedGates) do
    if not world.entityExists(targetId) or not world.callScriptedEntity(targetId, "isConnectionValid", entity.id()) then
      storage.connectedGates[tostring(targetId)] = nil
      storage.connectionCount = storage.connectionCount - 1
    end
  end
end

function onNodeConnectionChange()
  checkNodes()
end

function onInboundNodeChange(args)
  checkNodes()
end

function die()
  local ignore = {}
  ignore[tostring(entity.id())] = true
  for entityId,data in pairs(storage.connectedGates) do
    disconnect(entityId, ignore)
  end
end

function onInteraction(args)

end

function updateAnimationState()
  if storage.active then
    entity.setAnimationState("gatestate", "on")
  else
    entity.setAnimationState("gatestate", "off")
  end
  local ang = 0
  local count = 1
  for id,data in pairs(storage.connectedGates) do
    ang = ang + data.forceangle
    if data.isOwner then
      entity.rotateGroup("beam" .. count, data.angle)
      entity.scaleGroup("beam" .. count, data.animationScale)
      count = count + 1
    end
  end
  for i = count, 2, 1 do
    entity.scaleGroup("beam" .. i, {0, 1})
  end
  entity.rotateGroup("direction", ang / storage.connectionCount)
end

function checkNodes()
  
end

function main()
  if not storage.initialized then
    validateConnections()
    findGates({})
    updateAnimationState()
    storage.initialized = true
  end
end

function isActive()
  return storage.active
end