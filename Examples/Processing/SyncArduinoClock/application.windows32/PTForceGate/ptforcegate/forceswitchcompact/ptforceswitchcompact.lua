function init(virtual)
  if not virtual then
    if storage.onoff == nil then
      storage.onoff = true
    end
    if storage.updown == nil then
      storage.updown = true
    end
    if storage.leftright == nil then
      storage.leftright = true
    end
    updateAnimation()
  end
end

function onNodeConnectionChange()
  checkNodes()
  updateAnimation()
  sendData()
end

function onInboundNodeChange(args)
  checkNodes()
  updateAnimation()
  sendData()
end

function checkNodes()
  if entity.isInboundNodeConnected(0) then
    storage.onoff = entity.getInboundNodeLevel(0)
  end
  if entity.isInboundNodeConnected(1) then
    storage.updown = entity.getInboundNodeLevel(1)
  end
  if entity.isInboundNodeConnected(2) then
    storage.leftright = entity.getInboundNodeLevel(2)
  end
end

function sendData()
  entity.setOutboundNodeLevel(0, storage.onoff)
  local vert = storage.updown and {0, 1} or {0, -1}
  local horz = storage.leftright and {-1, 0} or {1, 0}
  for _,data in ipairs(entity.getOutboundNodeIds(0)) do
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {0, true, vert})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {1, true, horz})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {2, true, vert})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {3, true, horz})
    world.callScriptedEntity(data[1], "relayFunction", "setActive", {storage.onoff})
  end
end

function updateAnimation()
  entity.setAnimationState("onoff", storage.onoff and "on" or "off")
  entity.setAnimationState("leftright", storage.leftright and "left" or "right")
  entity.setAnimationState("updown", storage.updown and "up" or "down")
end

function main()

end