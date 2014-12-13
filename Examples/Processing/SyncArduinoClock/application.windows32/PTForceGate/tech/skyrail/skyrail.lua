function init()
  data.lastJump = false
  data.lastToggle = false
  data.onrail = false
  data.direction = 0
  --data.speed = 0
  data.deltaspeed = 0
  data.active = false
  data.leaveTimer = 0
end

function uninit()
  if data.active and data.onrail then
    leaveRail()
  end
  tech.setParentAppearance("normal")
  data.lastJump = false
  data.lastToggle = false
  data.onrail = false
  data.direction = 0
  --data.speed = 0
  data.deltaspeed = 0
  data.active = false
  data.leaveTimer =0
end

function input(args)
  --Jump takes priority over all
  if args.moves["jump"] and data.onrail then
    data.lastJump = true
    return "SkyrailDisembark"
  end
  data.lastJump = args.moves["jump"]
  
  --Then special
  if args.moves["special"] == 1 and not data.lastToggle then
   data.lastToggle = true
   return "SkyrailToggle"
  end
  data.lastToggle = args.moves["special"] == 1
  
  --Then moving left/right when on a rail
  if data.onrail then
    if args.moves["right"] then
      return "SkyrailSpeedRight"
    end
    if args.moves["left"] then
      return "SkyrailSpeedLeft"
    end
  end
  
  return nil
end

function update(args)
  if data.active then 
    tech.setAnimationState("skyrail", "on")

    --Toggling the hook mode on/off
    if args.actions["SkyrailToggle"] then
      data.active = false
      if data.onrail then 
        leaveRail()
      end
    end 
    
    --If on the rail
    if data.onrail then
      --State Update
      local acceleration = tech.parameter("acceleration")   
      
      --Input Update
      testWallCollision()
      if args.actions["SkyrailDisembark"] then     
        data.leaveTimer = tech.parameter("railLeaveTime")
        leaveRail()
      else
        if args.actions["SkyrailSpeedLeft"] then
          updateSpeed(-acceleration * args.dt)
          tech.control({0,0},0,true,true)
        elseif args.actions["SkyrailSpeedRight"] then
          updateSpeed(acceleration * args.dt)
          tech.control({0,0},0,true,true)       
        end
        
        --Rail movement update    
        railupdate(args)
      end
    else
      --Not currently on the rail, look for rail to land on.
      offrailupdate(args) 
    end
  else
    data.onrail = false
    tech.setAnimationState("skyrail", "off")

    --Toggling the hook mode on/off
    if args.actions["SkyrailToggle"] then
      data.active = true
    end 
  end

  if data.onrail then
    tech.setParentAppearance("fall")
  else
    tech.setParentAppearance("normal")
  end
end

--Simple wall collision test by considering measured velocity
function testWallCollision()
  local minspeed = tech.parameter("minSpeed")
  
  if world.magnitude(tech.measuredVelocity()) < minspeed then
    --data.deltaspeed = minspeed - data.speed
    --data.speed = minspeed
  end
end

--Called to apply a temstep scaled acceleration to the speed
function updateSpeed(acceleration)  
  local minspeed = tech.parameter("minSpeed")
  --data.speed = data.speed + acceleration * data.direction
  data.deltaspeed = acceleration
  local vel = tech.measuredVelocity()
  if vel[1] + data.deltaspeed < 0 then
    data.direction = -1
  else
    data.direction = 1
  end
  --[[
  if data.speed + data.deltaspeed < minspeed then
    data.deltaspeed = minspeed - delta.speed
    --data.speed = minspeed
    data.direction = -data.direction
  end
  --]]
end

--Called to disembark the rail. Effects + state updates here!
function leaveRail()
  data.onrail = false
end

--Called to embark the rail. Effects + state updates here!
function joinRail(rail)
  data.onrail = true
  --data.direction =0
  --data.speed =0
  data.deltaspeed = 0
  
  --Determine direction (if any)
  local vel = tech.measuredVelocity()
  if vel[1] > 0 then
    data.direction = 1
  elseif vel[1] < 0 then
    data.direction = -1
  end
  
  --Determine speed by casting onto rail
  local grad = railGradient(rail)
  --data.speed=math.abs(vel[1])
  if grad ==0 then
    --Special case: falling onto horizontal surface
    --data.speed=math.abs(vel[1])
  else
    --Taking into account vspeed * gradient of platform
    --[[
    local ir2 = 1.0/math.sqrt(2)
    data.speed= ir2 * (math.abs(vel[1]) + vel[2] * grad) 
    if data.speed < 0 then
      data.speed = -data.speed
      data.direction = -data.direction
    elseif data.speed < 0.001 then
      data.direction = 0
    end
    --]]
  end
  
  if data.direction == 0 then
    --data.deltaspeed = tech.parameter("minSpeed") - data.speed
    data.direction = tech.direction()
  end
  
end

--Called per step to update state when on the rail
function railupdate(args)
  local minspeed = tech.parameter("minSpeed")
  local maxspeed = tech.parameter("maxSpeed")
  local hookOffset = tech.parameter("hookOffset")
  local testOffset = tech.parameter("railtestStartOffset")
  local hookX = { tech.position()[1] + hookOffset[1], tech.position()[2] + hookOffset[2]}
  local testStartX = { hookX[1] + testOffset[1], hookX[2] + testOffset[2] }
  local gravity = tech.parameter("gravity")
  
  --Determine platform information
  local rail = railTest(testStartX)
  if rail == nil then
    --Rail blocked/not in range
    leaveRail()
    return
  else
    --Determine gradient of rail
    local grad = railGradient(rail)
    --Apply gravity
    --data.speed = data.speed - gravity * args.dt * grad
    data.deltaspeed = data.deltaspeed - (gravity * args.dt * grad * data.direction)
    --Clamp speed
    --[[
    if data.speed + data.deltaspeed < minspeed then
      data.deltaspeed = minspeed - data.speed
    elseif data.speed + data.deltaspeed > maxspeed then
      data.deltaspeed = maxspeed - data.speed
    end
    --]]
    
    --Set velocity of player based on rail, snap player to rail
    local vel = tech.velocity()
    local xVel = 0
    if grad == 0 then
      xVel = vel[1] + data.deltaspeed
      tech.setXVelocity(xVel)
      tech.setYVelocity(0)
    else
      --world.logInfo("Gradient %s: %s, %s", grad, (vel[1] + data.deltaspeed) * data.direction / math.sqrt(2), (vel[1] + data.deltaspeed) * grad / math.sqrt(2))
      xVel = vel[1] + (data.deltaspeed / math.sqrt(2))
      tech.setXVelocity(xVel)
      tech.setYVelocity(vel[1] + (data.deltaspeed * grad / math.sqrt(2)))
    end
    data.direction = xVel > 0 and 1 or -1
    --Snap to rail based on difference between coords with rail
    local dx = tech.position()[1] - rail.Position[1]
    local ypos = rail.Position[2]-hookOffset[2]
    if data.direction < 0 then
      ypos = ypos - (1-dx)*grad*data.direction
    else
      ypos = ypos + dx*grad*data.direction
    end
    tech.setPosition({tech.position()[1],ypos})  
    data.deltaspeed = 0
    --data.speed = math.abs(tech.measuredVelocity()[1])
  end
end

--Called per step to update state when off the rail but tech is active
function offrailupdate(args)
  local hookOffset = tech.parameter("hookOffset")
  local testOffset = tech.parameter("railtestStartOffset")
  local hookX = { tech.position()[1] + hookOffset[1], tech.position()[2] + hookOffset[2]}
  local testStartX = { hookX[1] + testOffset[1], hookX[2] + testOffset[2] }
  
  --Can join to platform?
  local rail = railTest(testStartX)
  if rail == nil or data.leaveTimer > 0 then
    --No.
    data.leaveTimer = data.leaveTimer - args.dt
  else
    --Yes.
    data.leaveTimer = 0
    joinRail(rail)
  end
end

--Determine gradient of rail w.r.t direction
function railGradient(rail)
  local prv = rail.Neighbours[1]
  local nxt = rail.Neighbours[2]
  local gradient = 0
  local reverse = false
  if data.direction < 0 then
    prv = rail.Neighbours[2]
    nxt = rail.Neighbours[1]
    reverse = true
  end
  if nxt==nil then
    --No next rail, only care about previous rail.
    if prv == nil then
      gradient = 0
    else
      gradient = -prv[2]
    end
  else
    if prv==nil then
      gradient=nxt[2] --No previous rail
    elseif nxt[2]==0 and prv[2]==0 then
      gradient=0  --straight line
    elseif nxt[2]==1 and prv[2]~=1 then
      gradient=1  --Uphill
    elseif nxt[2]==-1 and prv[2]~=-1 then
      gradient=-1 --Downhill
    else
      gradient=nxt[2] --Disjoint line?
    end
  end
  return gradient
end

--Returns rail above given position. Nil if rail blocked or not found.
--TODO: May fail in liquid - look at returning all collision blocks and stepping thru.
function railTest(position)
  local testLength = tech.parameter("railtestLength")
  local lineStart = position
  local lineEnd = {position[1], position[2] + testLength}
  
  if world.lineCollision(lineStart,lineEnd,false) then
    local blocksX = world.collisionBlocksAlongLine(lineStart, lineEnd, false, 1)
    local blockType = world.material(blocksX[1],"foreground")
    --If block type is valid
    if blockIsRail(blockType) then
      local ln = getNeighbourHelper(blocksX[1], -1)
      local rn = getNeighbourHelper(blocksX[1], 1)
      return { Position=blocksX[1], Type=blockType, Neighbours={ln,rn} } 
    else
      return nil
    end 
  end
  
  return nil
end

--Returns true if the block is a rail
function blockIsRail(blockType)
  local validSurfaces = tech.parameter("railSurfaces")
  
  if blockType ~= nil then
    for _, value in pairs(validSurfaces) do
      if value == blockType then
        return true
      end
    end
  end
  return false
end

--Returns the neighbours of a rail
function getNeighbourHelper(position, xOffset)
  local bot = world.material({position[1] + xOffset, position[2] - 1},"foreground")
  local mid = world.material({position[1] + xOffset, position[2]},"foreground")
  local top = world.material({position[1] + xOffset, position[2] + 1},"foreground")

  if blockIsRail(bot) then
    return {xOffset,-1}
  elseif blockIsRail(mid) then
    return {xOffset,0}
  elseif blockIsRail(top) then
    return {xOffset,1}
  end
  return nil
end
