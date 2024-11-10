mathplus = require "mathplus"
vec2 = mathplus.vec2
vec3 = mathplus.vec3
quat = mathplus.quat

-- math

function transformPoint(point, translate, rotate, scale)
    return quat.fromEuler(rotate):rotate(point * scale) + translate
end

function projectOnPlane(point, origin, normal)
    return point - (point - origin):project(normal)
end

function raycastCube(origin, direction, cubeCenter, cubeSize)
    local halfSize = cubeSize/2
    local minBound, maxBound = cubeCenter - vec3.new(halfSize, halfSize, halfSize), cubeCenter + vec3.new(halfSize, halfSize, halfSize)
    local tMin, tMax = -math.huge, math.huge
    local function slab(originCoord, dirCoord, minBoundCoord, maxBoundCoord)
        if dirCoord ~= 0 then
            local t1 = (minBoundCoord - originCoord) / dirCoord
            local t2 = (maxBoundCoord - originCoord) / dirCoord
            if t1 > t2 then t1, t2 = t2, t1 end
            tMin = math.max(tMin, t1)
            tMax = math.min(tMax, t2)
        elseif originCoord < minBoundCoord or originCoord > maxBoundCoord then
            return false
        end
        return true
    end
    if  slab(origin.x, direction.x, minBound.x, maxBound.x) and
        slab(origin.y, direction.y, minBound.y, maxBound.y) and
        slab(origin.z, direction.z, minBound.z, maxBound.z)
    then
        if tMin >= 0 then
            --if tMin <= 1 then
                return origin + direction * tMin
            --end
        elseif tMax >= 0 then
            --if tMax <= 1 then
                return origin + direction * tMax
            --end
        end
    end
end

-- graphics

function dashedLine(x1, y1, x2, y2, dashLength)
    local lineLength = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    local dashes = math.floor(lineLength / dashLength)
    local dx = (x2 - x1) / dashes
    local dy = (y2 - y1) / dashes
    for i = 0, dashes - 1, 2 do
        local startX = x1 + i * dx
        local startY = y1 + i * dy
        local endX = x1 + (i + 1) * dx
        local endY = y1 + (i + 1) * dy
        love.graphics.line(startX, startY, endX, endY)
    end
end

function cubeMeshData(position, size, rotation)
    local halfSize = size/2
    local rot = (vec3.is(rotation) and quat.fromEuler(rotation)) or (quat.is(rotation) and rotation) or quat.identity()
    local forward = vec3(0, 0, 1)

    local vertices = {
        vec3(-halfSize, -halfSize, -halfSize), -- UBL
        vec3( halfSize, -halfSize, -halfSize), -- UBR
        vec3( halfSize, -halfSize,  halfSize), -- UFR
        vec3(-halfSize, -halfSize,  halfSize), -- UFL
        vec3(-halfSize,  halfSize, -halfSize), -- DBL
        vec3( halfSize,  halfSize, -halfSize), -- DBR
        vec3( halfSize,  halfSize,  halfSize), -- DFR
        vec3(-halfSize,  halfSize,  halfSize)  -- DFL
    }

    local edges = {
        {1, 2}, -- UB
        {2, 3}, -- UR
        {3, 4}, -- UF
        {4, 1}, -- UL
        {5, 6}, -- DB
        {6, 7}, -- DR
        {7, 8}, -- DF
        {8, 5}, -- DL
        {1, 5}, -- BL
        {2, 6}, -- BR
        {3, 7}, -- FR
        {4, 8}  -- FL
    }

    local faces = {
        {1, 2, 3, 4}, -- U
        {8, 7, 6, 5}, -- D
        {2, 1, 6, 5}, -- B
        {4, 3, 7, 8}, -- F
        {1, 4, 8, 5}, -- L
        {3, 2, 6, 7}  -- R
    }

    local vertexInFace = {
        {1, 3, 5}, -- UBL
        {1, 3, 6}, -- UBR
        {1, 4, 6}, -- UFL
        {1, 4, 5}, -- UFR
        {2, 3, 5}, -- DBL
        {2, 3, 6}, -- DBR
        {2, 4, 6}, -- DFL
        {2, 4, 5}  -- DFR
    }

    local normals = {
        vec3( 0, -1,  0), -- U
        vec3( 0,  1,  0), -- D
        vec3( 0,  0, -1), -- F
        vec3( 0,  0,  1), -- B
        vec3(-1,  0,  0), -- L
        vec3( 1,  0,  0)  -- R
    }

    for i, vertex in ipairs(vertices) do
        vertices[i] = rot:rotate(vertex) + position
    end

    for i, normal in ipairs(normals) do
        normals[i] = rot:rotate(normal)
    end
    
    local facesVisible = {}
    for i, normal in ipairs(normals) do
        facesVisible[i] = forward:dot(normal) <= 0
    end

    local verticesVisible = {}
    for i, faces in ipairs(vertexInFace) do
        verticesVisible[i] = false
        for j, face in ipairs(faces) do
            if facesVisible[face] then
                verticesVisible[i] = true
            end
        end
    end

    local edgesVisible = {}
    for i, edge in ipairs(edges) do
        edgesVisible[i] = verticesVisible[edge[1]] and verticesVisible[edge[2]]
    end

    return {
        vertices = vertices,
        edges = edges,
        faces = faces,
        normals = normals,
        verticesVisible = verticesVisible,
        edgesVisible = edgesVisible,
        facesVisible = facesVisible
    }
end

-- callbacks

function love.load()
    sqit = require "sqit"

    scene = sqit.new{}

    scene.add({
        z = -1,
        sensitivity = 0.01,
        rotation = vec3(0, 0, 0),
        speed = 0.05,
        zoom = 0,
        screenSize = vec2(0, 0),
        check = function(self, x, y) return true end,
        moved = function(self, x, y, dx, dy)
            self.rotation = self.rotation + vec3(dy * self.sensitivity, -dx * self.sensitivity, 0)
            self.rotation.x = math.max(-math.pi/2, math.min(math.pi/2, self.rotation.x))
        end,
        scrolled = function(self, t)
            self.zoom = self.zoom + t * self.speed
        end,
        resize = function(self, w, h)
            self.screenSize = vec2(w, h)
        end,
        draw = function(self)
            love.graphics.translate((self.screenSize/2):unpack())
            local scale = math.min(self.screenSize:unpack())/2 * math.exp(self.zoom)
            love.graphics.scale(scale)

            -- draw the cube
            local data = cubeMeshData(vec3(0, 0, 0), 1, self.rotation)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(1 / scale)
            for i, edge in ipairs(data.edges) do
                local a, b = data.vertices[edge[1]], data.vertices[edge[2]]
                if data.edgesVisible[i] then
                    love.graphics.line(a.x, a.y, b.x, b.y)
                else
                    dashedLine(a.x, a.y, b.x, b.y, 10 / scale)
                end
            end
            love.graphics.setColor(0, 1, 0)
            for i, vertex in ipairs(data.vertices) do
                love.graphics.circle(data.verticesVisible[i] and "fill" or "line", vertex.x, vertex.y, 8 / scale)
            end

            -- draw the coordinate system
            local q = quat.fromEuler(self.rotation)
            local s = 0.25
            local x, y, z = q:rotate(vec3(s, 0, 0)), q:rotate(vec3(0, s, 0)), q:rotate(vec3(0, 0, s))
            love.graphics.setColor(1, 0, 0)
            love.graphics.line(0, 0, x.x, x.y)
            love.graphics.setColor(0, 1, 0)
            love.graphics.line(0, 0, y.x, y.y)
            love.graphics.setColor(0, 0, 1)
            love.graphics.line(0, 0, z.x, z.y)
        end
    }, "viewport")

    scene.registerCallbacks()
    scene.resize(love.graphics.getDimensions())
end