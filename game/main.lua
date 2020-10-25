function love.load()

  floorImage = love.graphics.newImage( "floor.png" )
  pathTile = love.graphics.newImage( "pathtile.png" )

end

pfWidth = 1536
pfHeight = 1080

scWidth = 1920
scHeight = 1080

sqSize = 256

appState = "ready"

function love.draw()
	if appState == "play" then
		drawPlay()
  elseif appState == "ready" then
    drawReady()
	end
end

function love.update(dt)
  if appState == "play" then
    updatePlay(dt)
  elseif appState == "ready" then
    updateReady()
  end
end

--
-- Ready mode
--

readyState =
{
  wasDown = false,
}

function drawReady()
  drawPlay()
end

function updateReady()
  if love.keyboard.isDown("space") then
    readyState.wasDown = true
  else
    if readyState.wasDown then
      readyState.wasDown = false
      initPlay()
      appState = "play"
    end
  end
end


--
-- Play mode
--

playState =
{
  scrollPos = 0,
  floorPos = 0,
  scrollSpeed = 32,
  sqCol = { { 0, 0.25, 0 }, { 0, 0, 0.25 } },
  wallWidth = 32,
  wallTypes = 2,
  walls = {},
  wallCol = { { 0.75, 0, 0 }, {0.15,0.65,0.8}, {0.5,0.5,0.5}, {0,0.65,0.65}, {0.65,0,0.65} },
  playerCol = { 1.0, 0.7, 0.2 },
  walkerCol = { 0.9, 0.1, 0.9 },
  gemCol = { 1.0, 1.0, 0.1 },
  levelLength = 1024,
  levelWidth = 16, -- default only
  pp = { x=0, y=0, dx=0, dy=0, sx=0.1, sy=0.1, l=1, mode="y" },
  ladder = { x=0, y=0, tx=0, ty=0, dx=0, dy=0, sx=0.0, sy=0.0, ready=false },
  ladderCol = { { 0.25, 0.25, 0.5 }, { 0.5,0.5,1 } },
  walkers = {},
  walkerDir= { {dx=1,dy=0}, {dx=0,dy=1}, {dx=-1,dy=0}, {dx=0,dy=-1} },
  gems = {},
}

function levelToScreen( lx, ly )
  local sx = (lx-1)*playState.wallWidth
  local sy = (pfHeight-((ly-1)*playState.wallWidth))+playState.scrollPos
  return sx, sy
end

function orderedRect( x1, y1, x2, y2 )
  local minx = math.min(x1,x2)
  local miny = math.min(y1,y2)
  local maxx = math.max(x1,x2)
  local maxy = math.max(y1,y2)
  return minx, miny, maxx, maxy
end


function drawPlay()

	-- Split screen
	love.graphics.setColor( 0, 0, 0 )
	love.graphics.rectangle( "fill", pfWidth, 0, scWidth-pfWidth, scHeight )

	-- Floor
  --local scrollMod = playState.floorPos % (sqSize*2)
  --love.graphics.setScissor( 0, 0, pfWidth, pfHeight )
  --for sy = -((sqSize*2)-scrollMod), pfHeight, sqSize*2 do
  --  for sx = 0, pfWidth, sqSize*2 do
  --    love.graphics.setColor( playState.sqCol[1] )
  --    love.graphics.rectangle( "fill", sx, sy, sqSize, sqSize )
  --    love.graphics.rectangle( "fill", sx+sqSize, sy+sqSize, sqSize, sqSize )
  --    love.graphics.setColor( playState.sqCol[2] )
  --    love.graphics.rectangle( "fill", sx+sqSize, sy, sqSize, sqSize )
  --    love.graphics.rectangle( "fill", sx, sy+sqSize, sqSize, sqSize )
  --  end
  --end
  local scrollMod = playState.floorPos % sqSize
  love.graphics.setScissor( 0, 0, pfWidth, pfHeight )
  love.graphics.setColor( 1,1,1 )
  for sy = -(sqSize-scrollMod), pfHeight, sqSize do
    for sx = 0, pfWidth, sqSize do
      love.graphics.draw( floorImage, sx, sy ) 
    end
  end

  -- Walls
  for t = 1, playState.wallTypes+1 do
    if t ~= playState.pp.l then
      local et = t
      if t == playState.wallTypes+1 then et = playState.pp.l end
      if playState.walls[et] then
        love.graphics.setColor( playState.wallCol[et] )
        for y=1, playState.levelLength do
          for x=1, playState.levelWidth do
            if playState.walls[y][x][et] then
              local sx, sy = levelToScreen( x, y )
              love.graphics.draw( pathTile, sx, sy )
              --love.graphics.rectangle( "fill", sx, sy, playState.wallWidth, playState.wallWidth )
            end
          end
        end
      end
      -- Walkers get drawn just above their layers.
      for k,walker in pairs( playState.walkers ) do
        if walker.alive and walker.l==et then
          love.graphics.setColor( playState.walkerCol )
          local sx, sy = levelToScreen( walker.x, walker.y )
          sx = sx + (walker.dx*playState.wallWidth) + (playState.wallWidth/4)
          sy = sy - (walker.dy*playState.wallWidth) + (playState.wallWidth/4)
          love.graphics.rectangle( "fill", sx, sy, playState.wallWidth/2, playState.wallWidth/2 )
        end
      end
      -- Gems also get drawn just above their layers.
      for k,gem in pairs( playState.gems ) do
        if gem.alive and gem.l==et then
          love.graphics.setColor( playState.gemCol )
          local sx, sy = levelToScreen( gem.x, gem.y )
          local ww = playState.wallWidth/2
          sx = sx
          sy = sy
          love.graphics.polygon( "fill", sx+ww, sy, sx+ww+ww, sy+ww, sx+ww, sy+ww+ww, sx, sy+ww )
        end
      end
    end
  end

  -- Ladder
  if playState.ladder.x ~= 0 then
    if playState.ladder.ready then
      love.graphics.setColor( playState.ladderCol[2] )
    else
      love.graphics.setColor( playState.ladderCol[1] )
    end
    local sx, sy = levelToScreen( playState.ladder.x, playState.ladder.y )
    local tx, ty = levelToScreen( playState.ladder.tx, playState.ladder.ty )
    local x1, y1, x2, y2 = orderedRect(sx,sy,tx,ty)
    love.graphics.rectangle("line",x1,y1,(x2+playState.wallWidth)-x1,(y2+playState.wallWidth)-y1)
    local ux, uy = levelToScreen( playState.ladder.x+playState.ladder.dx, playState.ladder.y+playState.ladder.dy )
    local x1, y1, x2, y2 = orderedRect(sx,sy,ux,uy)
    love.graphics.rectangle("fill",x1,y1,(x2+playState.wallWidth)-x1,(y2+playState.wallWidth)-y1)
  end


  -- Player
  love.graphics.setColor( playState.playerCol )
  local sx, sy = levelToScreen( playState.pp.x, playState.pp.y )
  love.graphics.rectangle( "line", sx, sy, playState.wallWidth, playState.wallWidth )
  sx = sx + (playState.pp.dx*playState.wallWidth) + (playState.wallWidth/4)
  sy = sy - (playState.pp.dy*playState.wallWidth) + (playState.wallWidth/4)
  love.graphics.rectangle( "fill", sx, sy, playState.wallWidth/2, playState.wallWidth/2 )

  love.graphics.setScissor()

  -- Debug
  love.graphics.setColor( 1, 1, 1 )
  love.graphics.print( "x:"..tostring(playState.pp.x).." / "..tostring(playState.pp.dx), pfWidth+32, pfHeight-32 )
  love.graphics.print( "y:"..tostring(playState.pp.y).." / "..tostring(playState.pp.dy), pfWidth+32, pfHeight-48 )

end

function onLadder( x, y )
  if playState.ladder.ready then
    local x1,y1,x2,y2 = orderedRect(playState.ladder.x,playState.ladder.y,playState.ladder.tx,playState.ladder.ty)
    if x>=x1 and x<=x2 and y>=y1 and y<=y2 then
       return true
    end
  end
  return false
end

function canEnter( x, dx, y, dy, l )
  if dx < 0 then 
    while dx < 0 do x=x-1 dx=dx+1 end
  else
    while dx > 0 do x=x+1 dx=dx-1 end
  end
  if dy < 0 then
    while dy < 0 do y=y-1 dy=dy+1 end
  else
    while dy > 0 do y=y+1 dy=dy-1 end
  end
  if x < 1 or x > playState.levelWidth or y < 1 or y > playState.levelLength then
    return false
  end
  if playState.walls[y][x][l] then
    return true
  end
  return onLadder( x, y )
end

function isEmpty( x, y )
  if x < 1 or x > playState.levelWidth or y < 1 or y > playState.levelLength then
    return false
  end
  local res = true
  for t = 1, playState.wallTypes do
    res = res and not playState.walls[y][x][t]
  end
  return res
end

function layerAt( x, y )
  if x>=1 and y>=1 and x<=playState.levelWidth and y<=playState.levelLength then
    for t = 1, playState.wallTypes do
      if playState.walls[y][x][t] then
        return t
      end
    end
  end
  return 0
end

function updatePlay( dt )

  -- Scroll
  playState.scrollPos = playState.scrollPos + (dt* playState.scrollSpeed)
  playState.floorPos = playState.floorPos + (dt* (playState.scrollSpeed*0.5))

  -- Movement inputs
  local oldX = playState.pp.x
  local oldY = playState.pp.y
  local oldDX = playState.pp.dx
  local oldDY = playState.pp.dy
  local wantUp = love.keyboard.isDown("up")
  local wantDown = love.keyboard.isDown("down")
  local wantLeft = love.keyboard.isDown("left")
  local wantRight = love.keyboard.isDown("right")
  local wantLadder = love.keyboard.isDown('z')

  if playState.pp.mode == "x" then
    if wantLeft then
      if canEnter( playState.pp.x, playState.pp.dx-playState.pp.sx, playState.pp.y, 0, playState.pp.l ) then
        playState.pp.dx = playState.pp.dx-playState.pp.sx
        if playState.pp.dx < -1 then
          playState.pp.x = playState.pp.x - 1
          playState.pp.dx = playState.pp.dx + 1
        end
      else
        playState.pp.dx = math.floor(playState.pp.dx)
      end
     end
    if wantRight then
      if canEnter( playState.pp.x, playState.pp.dx+playState.pp.sx, playState.pp.y, 0, playState.pp.l ) then
        playState.pp.dx = playState.pp.dx+playState.pp.sx
        if playState.pp.dx > 1 then
          playState.pp.x = playState.pp.x + 1
          playState.pp.dx = playState.pp.dx - 1
        end
      else
        playState.pp.dx = math.ceil(playState.pp.dx)
      end  
    end
    if oldX ~= playState.pp.x or (oldDX*playState.pp.dx)<0 or math.abs(playState.pp.dx)<0.01 then
      if wantUp and canEnter( playState.pp.x, 0, playState.pp.y, 1, playState.pp.l ) then
        playState.pp.dx = 0
        playState.pp.dy = playState.pp.sy
        playState.pp.mode = "y"
      elseif wantDown and canEnter( playState.pp.x, 0, playState.pp.y, -1, playState.pp.l ) then
        playState.pp.dx = 0
        playState.pp.dy = -playState.pp.sy
        playState.pp.mode = "y"
      end
    end
  else
    if wantDown then
      if canEnter( playState.pp.x, 0, playState.pp.y, playState.pp.dy-playState.pp.sy, playState.pp.l ) then
        playState.pp.dy = playState.pp.dy-playState.pp.sy
        if playState.pp.dy < -1 then
          playState.pp.y = playState.pp.y - 1
          playState.pp.dy = playState.pp.dy + 1
        end
      else
        playState.pp.dy = math.floor(playState.pp.dy)
      end
    end
    if wantUp then
      if canEnter( playState.pp.x, 0, playState.pp.y, playState.pp.dy+playState.pp.sy, playState.pp.l ) then
        playState.pp.dy = playState.pp.dy+playState.pp.sy
        if playState.pp.dy > 1 then
          playState.pp.y = playState.pp.y + 1
          playState.pp.dy = playState.pp.dy - 1
        end
      else
        playState.pp.dy = math.ceil(playState.pp.dy)
      end
    end
    if oldY ~= playState.pp.y or (oldDY*playState.pp.dy)<0 or math.abs(playState.pp.dy)<0.01 then
      if wantRight and canEnter( playState.pp.x, 1, playState.pp.y, 0, playState.pp.l ) then
        playState.pp.dy = 0
        playState.pp.dx = playState.pp.sx
        playState.pp.mode = "x"
      elseif wantLeft and canEnter( playState.pp.x, -1, playState.pp.y, 0, playState.pp.l ) then
        playState.pp.dy = 0
        playState.pp.dx = -playState.pp.sx
        playState.pp.mode = "x"
      end
    end
  end

  -- Change base positions
  if playState.pp.dx > 0.5 then playState.pp.dx=playState.pp.dx-1 playState.pp.x=playState.pp.x+1 end
  if playState.pp.dx < -0.5 then playState.pp.dx=playState.pp.dx+1 playState.pp.x=playState.pp.x-1 end
  if playState.pp.dy > 0.5 then playState.pp.dy=playState.pp.dy-1 playState.pp.y=playState.pp.y+1 end
  if playState.pp.dy < -0.5 then playState.pp.dy=playState.pp.dy+1 playState.pp.y=playState.pp.y-1 end
   
  -- Ladder place
  if wantLadder and ( wantUp or wantDown or wantLeft or wantRight ) and not onLadder(playState.pp.x,playState.pp.y) then
    playState.ladder.x = math.floor(playState.pp.x)
    playState.ladder.y = math.floor(playState.pp.y)
    playState.ladder.dx = 0
    playState.ladder.dy = 0
    local px=0
    local py=0
    if wantUp or wantDown then
      if wantUp then py=1 else py=-1 end
      playState.ladder.sx = 0;
      playState.ladder.sy = playState.pp.sy * 2.0 * py
    else
      if wantRight then px=1 else px=-1 end
      playState.ladder.sx = playState.pp.sx * 2.0 * px
      playState.ladder.sy = 0;
    end
    playState.ladder.tx = playState.ladder.x+px
    playState.ladder.ty = playState.ladder.y+py
    while isEmpty( playState.ladder.tx, playState.ladder.ty ) do
      playState.ladder.tx = playState.ladder.tx+px
      playState.ladder.ty = playState.ladder.ty+py
    end
    playState.ladder.ready = false
  end

  if playState.ladder.x ~= 0 then
    playState.ladder.dx = playState.ladder.dx+playState.ladder.sx
    playState.ladder.dy = playState.ladder.dy+playState.ladder.sy
    if ( math.abs(playState.ladder.tx-playState.ladder.x) < math.abs(playState.ladder.dx) ) or ( math.abs(playState.ladder.ty-playState.ladder.y) < math.abs(playState.ladder.dy) ) then
      playState.ladder.dx = playState.ladder.tx-playState.ladder.x
      playState.ladder.dy = playState.ladder.ty-playState.ladder.y
      if layerAt( playState.ladder.tx, playState.ladder.ty ) > 0 then
        playState.ladder.ready = true
      else
        playState.ladder.x = 0
      end
    end
  end

  -- Ladder destination
  if onLadder( playState.pp.x, playState.pp.y ) then
    local oldDist, newDist
    if playState.ladder.x ~= playState.ladder.tx then
      oldDist = math.abs(playState.ladder.x-(oldX+oldDX))
      newDist = math.abs(playState.ladder.x-(playState.pp.x+playState.pp.dx))
    else
      oldDist = math.abs(playState.ladder.y-(oldY+oldDY))
      newDist = math.abs(playState.ladder.y-(playState.pp.y+playState.pp.dy))
    end
    if oldDist > newDist then
      playState.pp.l = layerAt( playState.ladder.x, playState.ladder.y )
    elseif oldDist < newDist then
      playState.pp.l = layerAt( playState.ladder.tx, playState.ladder.ty )
    end
  end

  -- Walker movement
  for k,walker in pairs( playState.walkers ) do
    if walker.alive then
      local dir = playState.walkerDir[walker.direction]
      local sx = dir.dx/16
      local sy = dir.dy/16
      if canEnter( walker.x, walker.dx+sx, walker.y, walker.dy+sy, walker.l ) then
        walker.dx = walker.dx + sx
        walker.dy = walker.dy + sy
      else
        walker.direction = walker.direction + 1
        if walker.direction == 5 then walker.direction = 1 end
      end
      if walker.dx > 0.5 then walker.dx=walker.dx-1 walker.x=walker.x+1 end
      if walker.dx < -0.5 then walker.dx=walker.dx+1 walker.x=walker.x-1 end
      if walker.dy > 0.5 then walker.dy=walker.dy-1 walker.y=walker.y+1 end
      if walker.dy < -0.5 then walker.dy=walker.dy+1 walker.y=walker.y-1 end

      -- Collision
      if walker.x == playState.pp.x and walker.y == playState.pp.y and walker.l == playState.pp.l then
        appState = "ready"
      end
    end
  end

  -- Gem collect
  for k,gem in pairs( playState.gems ) do
    if gem.alive then
      if gem.x == playState.pp.x and gem.y == playState.pp.y and gem.l == playState.pp.l then
        gem.alive = false
      end
    end
  end

  -- Off the bottom
  local sx, sy = levelToScreen( playState.pp.x, playState.pp.y )
  if sy > pfHeight+32 then
    appState = "ready"
  end

end


function initPlay()
  playState.levelWidth = pfWidth/playState.wallWidth

  playState.wallTypes = 2

  local newState = {}
  for y = 1, playState.levelLength do
    newState[y] = {}
    for x = 1, playState.levelWidth do
      newState[y][x] = {}
    end
  end

  for t = 1, playState.wallTypes do
    local lastLine = 0
    local lastStart = 1
    local lastEnd = playState.levelWidth
    while lastLine <= playState.levelLength do
      local nextLine = lastLine + math.random( 5, 10 )
      local nextWidth = math.random( 10, 25 )
      local nextStart = math.random( 1, playState.levelWidth-nextWidth )
      local nextEnd = nextStart+nextWidth

      if nextEnd<lastStart  then
        nextEnd = lastStart
      end
      if nextStart>lastEnd then
        nextStart = lastEnd
      end

      if nextLine <= playState.levelLength then
        for x = nextStart, nextEnd do
          newState[nextLine][x][t] = true
        end
      end

      local yBase = math.max( lastLine, 1 )
      local yLimit = math.min( nextLine, playState.levelLength )
      local x = 0
      if nextStart >= lastStart and nextStart <= lastEnd then
        x = nextStart
      elseif lastStart >= nextStart and lastStart <= nextEnd then
        x = lastStart
      end
      if x > 0 then
        for y = yBase, yLimit do
          newState[y][x][t] = true
        end
      end
      x=0
      if nextEnd >= lastStart and nextEnd <= lastEnd then
        x = nextEnd
      elseif lastEnd >= nextStart and lastEnd <= nextEnd then
        x = lastEnd
      end
      if x > 0 then
        for y = yBase, yLimit do
         newState[y][x][t] = true
        end
      end

      lastLine = nextLine
      lastStart = nextStart
      lastEnd = nextEnd
    end
  end
  playState.walls = newState

  playState.pp.x = 1
  playState.pp.y = 20
  playState.pp.dx = 0
  playState.pp.dy = 0
  while not playState.walls[playState.pp.y][playState.pp.x][1] do
    playState.pp.x = playState.pp.x+1
  end

  -- Place walkers
  playState.walkers = {}
  local walkerCount = 1
  local y = math.random(1,5)
  while y <= playState.levelLength do
    local walkerLevel = math.random(1,2)
    local newWalker = {}
    local optCount = 0
    for x = 1, playState.levelWidth do
      if playState.walls[y][x][walkerLevel] then
        optCount = optCount+1
      end
    end
    local tgt = math.random( 1, optCount)
    optCount = 0
    for x = 1, playState.levelWidth do
      if playState.walls[y][x][walkerLevel] then
        optCount = optCount+1
        if optCount == tgt then
          newWalker.x = x
        end
      end
    end
    newWalker.y = y
    newWalker.dx = 0
    newWalker.dy = 0
    newWalker.direction = math.random(1,4)
    newWalker.l = walkerLevel
    newWalker.alive = true
    playState.walkers[walkerCount] = newWalker
    walkerCount = walkerCount + 1
    y = y + math.random( 3, 10 )
  end

  -- Place gems
  playState.gems = {}
  local gemCount = 1
  local y = math.random(1,5)
  while y <= playState.levelLength do
    local gemLevel = math.random(1,2)
    local newGem = {}
    local optCount = 0
    for x = 1, playState.levelWidth do
      if playState.walls[y][x][gemLevel] then
        optCount = optCount+1
      end
    end
    local tgt = math.random( 1, optCount)
    optCount = 0
    for x = 1, playState.levelWidth do
      if playState.walls[y][x][gemLevel] then
        optCount = optCount+1
        if optCount == tgt then
          newGem.x = x
        end
      end
    end
    newGem.y = y
    newGem.l = gemLevel
    newGem.alive = true
    playState.gems[gemCount] = newGem
    gemCount = gemCount + 1
    y = y + math.random( 2, 6 )
  end

  playState.ladder.x = 0
  playState.ladder.ready = false

  playState.scrollPos = 0
  playState.floorPos = 0

end

