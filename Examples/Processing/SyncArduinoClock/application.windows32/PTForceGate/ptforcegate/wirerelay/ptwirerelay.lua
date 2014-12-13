function init(virtual)
  if not virtual then
    if storage.state == nil then
      storage.state = false
    end
    onNodeConnectionChange()
  end
end

function onNodeConnectionChange(source)
  local outbound = entity.getOutboundNodeIds(0)
  storage.outboundIds = {}
  for _,data in ipairs(outbound) do
    storage.outboundIds[#storage.outboundIds + 1] = data[1]
  end
  checkInput()
  
  local id = entity.id()
  for _,data in ipairs(entity.getInboundNodeIds(0)) do
    if data[1] ~= source and data[1] ~= id then
      world.callScriptedEntity(data[1], "onNodeConnectionChange", id)
    end
  end
end

function onInboundNodeChange(args)
  checkInput()
end

function checkInput()
  local out = storage.state
  if entity.isInboundNodeConnected(0) then
    out = entity.getInboundNodeLevel(0)
  end
  setState(out)
end

function setState(state)
  if state == true then
    entity.setAnimationState("switchState", "on")
  else
    entity.setAnimationState("switchState", "off")
  end
  entity.setOutboundNodeLevel(0, state)
  storage.state = state
end

function relayFunction(name, args, source)
  --world.logInfo("Relay %s is relaying function %s with args %s from %s...", entity.id(), name, args, source)
  if name == "setActive" then
    setState(unpack(args))
  end
  local out = nil
  local id = entity.id()
  for _,entityId in ipairs(storage.outboundIds) do
    if entityId ~= source and entityId ~= id then
      --world.logInfo("Relay %s relayed function %s with args %s to %s", id, name, args, entityId)
      out = world.callScriptedEntity(entityId, "relayFunction", name, args, id)
    end
  end
  return out
end

function main()
end

