function init(args)
  self.dead = false

  -- Data doesn't attack people
  entity.setDamageOnTouch(false)
  entity.setAggressive(false)
  
  self.regionToApply = {0,0,0,0}
  self.forceToApply = {0,0}
end

function main()
  entity.setForceRegion(self.regionToApply, self.forceToApply)
  --world.logInfo("Monster %s applied force %s to region %s", entity.id(), self.forceToApply, self.regionToApply)
end

function setForceToApply(region, force)
  self.regionToApply = region
  self.forceToApply = force
end

function isForceMonster()
  return true
end

function damage(args)
  -- huehuehue i cant die
end

function kill()
  -- nvm i can die D:
  self.dead = true
end

function shouldDie()
  return self.dead
end