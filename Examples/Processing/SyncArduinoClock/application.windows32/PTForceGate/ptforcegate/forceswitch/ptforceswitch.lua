function init(virtual)
  if not virtual then
    if storage.onoff == nil then
      storage.onoff = true
    end
    if storage.updownleft == nil then
      storage.updownleft = true
    end
    if storage.updownright == nil then
      storage.updownright = true
    end
    if storage.leftrighttop == nil then
      storage.leftrighttop = true
    end
    if storage.leftrightbottom == nil then
      storage.leftrightbottom = true
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
    storage.leftrighttop = entity.getInboundNodeLevel(1)
  end
  if entity.isInboundNodeConnected(2) then
    storage.leftrightbottom = entity.getInboundNodeLevel(2)
  end
  if entity.isInboundNodeConnected(3) then
    storage.updownleft = entity.getInboundNodeLevel(3)
  end
  if entity.isInboundNodeConnected(4) then
    storage.updownright = entity.getInboundNodeLevel(4)
  end
end

function sendData()
  entity.setOutboundNodeLevel(0, storage.onoff)
  local top = storage.leftrighttop and {-1, 0} or {1, 0}
  local bottom = storage.leftrightbottom and {-1, 0} or {1, 0}
  local left = storage.updownleft and {0, 1} or {0, -1}
  local right = storage.updownright and {0, 1} or {0, -1}
  for _,data in ipairs(entity.getOutboundNodeIds(0)) do
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {0, true, right})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {1, true, top})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {2, true, left})
    world.callScriptedEntity(data[1], "relayFunction", "flipGate", {3, true, bottom})
    world.callScriptedEntity(data[1], "relayFunction", "setActive", {storage.onoff})
  end
end

function updateAnimation()
  entity.setAnimationState("onoff", storage.onoff and "on" or "off")
  entity.setAnimationState("leftrighttop", storage.leftrighttop and "left" or "right")
  entity.setAnimationState("leftrightbottom", storage.leftrightbottom and "left" or "right")
  entity.setAnimationState("updownleft", storage.updownleft and "up" or "down")
  entity.setAnimationState("updownright", storage.updownright and "up" or "down")
end

function main()

end