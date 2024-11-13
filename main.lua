mathplus = require "mathplus"
vec2 = mathplus.vec2
vec3 = mathplus.vec3
quat = mathplus.quat

function math.sign(x)
    if type(x) == "number" then
        return (x < 0 and -1) or (x > 0 and 1) or 0
    end
end

function table.shallowcopy(t)
    local r = {}
    for k, v in pairs(t) do
        r[k] = v
    end
    if type(getmetatable(t)) == "table" then
        setmetatable(r, getmetatable(t))
    end
    return r
end

-- math

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

--
-- CUBE MESH MAPPING
--
-- order of vertices:
-- 1: UBL
-- 2: UBR
-- 3: UFR
-- 4: UFL
-- 5: DBL
-- 6: DBR
-- 7: DFR
-- 8: DFL
--
-- order of edges:
--  1: UB
--  2: UR
--  3: UF
--  4: UL
--  5: DB
--  6: DR
--  7: DF
--  8: DL
--  9: BL
-- 10: BR
-- 11: FR
-- 12: FL
--
-- order of faces:
-- 1: U
-- 2: D
-- 3: B
-- 4: F
-- 5: L
-- 6: R
--

local blockMeshMap = {
    edges = {
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 1},
        {5, 6},
        {6, 7},
        {7, 8},
        {8, 5},
        {1, 5},
        {2, 6},
        {3, 7},
        {4, 8}
    },
    faces = {
        {1, 2, 3, 4},
        {8, 7, 6, 5},
        {2, 1, 6, 5},
        {4, 3, 7, 8},
        {1, 4, 8, 5},
        {3, 2, 6, 7}
    },
    edgesWithVertex = {
        {1, 4,  9},
        {1, 2, 10},
        {3, 4, 11},
        {3, 2, 12},
        {5, 8,  9},
        {5, 6, 10},
        {7, 8, 11},
        {7, 6, 12}
    },
    facesWithVertex = {
        {1, 3, 5},
        {1, 3, 6},
        {1, 4, 6},
        {1, 4, 5},
        {2, 3, 5},
        {2, 3, 6},
        {2, 4, 6},
        {2, 4, 5}
    },
    facesWithEdge = {
        {1, 3},
        {1, 6},
        {1, 4},
        {1, 5},
        {2, 3},
        {2, 6},
        {2, 4},
        {2, 5},
        {3, 5},
        {3, 6},
        {4, 6},
        {4, 5}
    },
    edgesInFace = {
        {1, 2,  3,  4},
        {5, 6,  7,  8},
        {1, 5,  9, 10},
        {3, 7, 11, 12},
        {4, 8,  9, 12},
        {2, 6, 10, 11}
    }
}

function blockMesh(size)
    if type(size) == "number" then size = vec3(size, size, size) end
    size = vec3.is(size) and size or vec3(1, 1, 1)
    local halfSize = size/2

    local vertices = {
        vec3(-halfSize.x, -halfSize.y, -halfSize.z), -- UBL
        vec3( halfSize.x, -halfSize.y, -halfSize.z), -- UBR
        vec3( halfSize.x, -halfSize.y,  halfSize.z), -- UFR
        vec3(-halfSize.x, -halfSize.y,  halfSize.z), -- UFL
        vec3(-halfSize.x,  halfSize.y, -halfSize.z), -- DBL
        vec3( halfSize.x,  halfSize.y, -halfSize.z), -- DBR
        vec3( halfSize.x,  halfSize.y,  halfSize.z), -- DFR
        vec3(-halfSize.x,  halfSize.y,  halfSize.z)  -- DFL
    }

    local normals = {
        vec3( 0, -1,  0), -- U
        vec3( 0,  1,  0), -- D
        vec3( 0,  0, -1), -- F
        vec3( 0,  0,  1), -- B
        vec3(-1,  0,  0), -- L
        vec3( 1,  0,  0)  -- R
    }

    return setmetatable({
        vertices = vertices,
        normals = normals
    }, {__index = blockMeshMap})
end

function polyMesh(vertices, faces, normals, flipNormals)
    vertices = type(vertices) == "table" and vertices or {}
    faces = type(faces) == "table" and faces or {}
    normals = type(normals) == "table" and normals or {}
    local nv, nf = 0, 0
    while vec3.is(vertices[nv + 1]) do nv = nv + 1 end
    while type(faces[nf + 1]) == "table" do
        for i = 1, 3 do
            if not vertices[faces[nf + 1][i]] then
                break
            end
        end
        nf = nf + 1
    end
    local _v, _f, _n = vertices, faces, normals
    vertices, faces, normals = {}, {}, {}
    for i = 1, nv do vertices[i] = _v[i] end
    for i = 1, nf do
        faces[i] = _f[i]
        normals[i] = vec3.is(_n[i]) and _n[i] or (flipNormals and -1 or 1) * (faces[i][1] - faces[i][2]):cross(faces[i][1] - faces[i][3]).norm
    end
    local edgeLookup, edges, edgesWithVertex, facesWithVertex, facesWithEdge, edgesInFace = {}, {}, {}, {}, {}, {}
    for i = 1, nv do edgesWithVertex[i], facesWithVertex[i] = {}, {} end
    for i, face in ipairs(faces) do
        edgesInFace[i] = {}
        for j = 1, #face - 1 do
            if not edgeLookup[face[j]][face[j + 1]] then
                table.insert(edges, {face[j], face[j + 1]})
                edgeLookup[face[j]] = edgeLookup[face[j]] or {}
                edgeLookup[face[j]][face[j + 1]] = #edges
                table.insert(edgesWithVertex[j], #edges)
                edgeLookup[face[j + 1]] = edgeLookup[face[j + 1]] or {}
                edgeLookup[face[j + 1]][face[j]] = #edges
                table.insert(edgesWithVertex[j + 1], #edges)
                facesWithEdge[#edges] = {}
            end
            table.insert(facesWithVertex[face[j]], i)
            table.insert(facesWithVertex[face[j + 1]], i)
            table.insert(facesWithEdge[edgeLookup[face[j]][face[j + 1]]], i)
            table.insert(edgesInFace[i], edgeLookup[face[j]][face[j + 1]])
        end
    end
    return {
        vertices = vertices,
        edges = edges,
        faces = faces,
        normals = normals,
        edgesWithVertex = edgesWithVertex,
        facesWithVertex = facesWithVertex,
        facesWithEdge = facesWithEdge,
        edgesInFace = edgesInFace
    }
end

function getMeshData(mesh, position, rotation, scale)
    if vec3.is(rotation) then rotation = quat.fromEuler(rotation) end
    position = vec3.is(position) and position or vec3.zero()
    scale = (vec3.is(scale) or type(scale) == "number") and scale or 1
    rotation = quat.is(rotation) and rotation or quat.identity()
    local forward = vec3.forward()

    local vertices = {}
    for i, vertex in ipairs(mesh.vertices) do
        vertices[i] = rotation:rotate(vertex * scale) + position
    end

    local normals = {}
    for i, normal in ipairs(mesh.normals) do
        normals[i] = rotation:rotate(normal)
    end
    
    local facesVisible = {}
    for i, normal in ipairs(normals) do
        facesVisible[i] = forward:dot(normal) <= 0
    end

    local verticesVisible = {}
    for i, faces in ipairs(mesh.facesWithVertex) do
        verticesVisible[i] = false
        for j, face in ipairs(faces) do
            if facesVisible[face] then
                verticesVisible[i] = true
            end
        end
    end

    local edgesVisible = {}
    for i, edge in ipairs(mesh.edges) do
        edgesVisible[i] = verticesVisible[edge[1]] and verticesVisible[edge[2]]
    end

    return setmetatable({
        vertices = vertices,
        normals = normals,
        verticesVisible = verticesVisible,
        edgesVisible = edgesVisible,
        facesVisible = facesVisible
    }, {__index = mesh})
end

function cubeCut(cubePosition, cubeSize, cubeRotation, planeOrigin, planeNormal)
    if planeNormal.len == 0 then return {} end
    if vec3.is(cubeRotation) then cubeRotation = quat.fromEuler(cubeRotation) end
    if not quat.is(cubeRotation) then cubeRotation = quat.identity() end
    local r, ri = cubeRotation, cubeRotation.inv
    local p, n = planeOrigin, planeNormal
    p = (p - cubePosition) / cubeSize
    p, n = ri:rotate(p), ri:rotate(n)
    local a, b, c = n:unpack()
    local d = n:dot(p)
    local points = {}
    if a ~= 0 or b ~= 0 then -- F-B: UL, UR, DR, DL => 4, 2, 8, 6
        local ulz = (d + a/2 + b/2) / c
        local urz = (d - a/2 + b/2) / c
        local drz = (d - a/2 - b/2) / c
        local dlz = (d + a/2 - b/2) / c
        if math.abs(ulz) <= 1/2 then points[4] = vec3(-1/2, -1/2, ulz) end
        if math.abs(urz) <= 1/2 then points[2] = vec3( 1/2, -1/2, urz) end
        if math.abs(drz) <= 1/2 then points[8] = vec3( 1/2,  1/2, drz) end
        if math.abs(dlz) <= 1/2 then points[6] = vec3(-1/2,  1/2, dlz) end
    else
        if p.z == -1/2 then
            return {
                vec3(-cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2, -cubeSize/2),
                vec3(-cubeSize/2,  cubeSize/2, -cubeSize/2)
            }
        elseif p.z == 1/2 then
            return {
                vec3(-cubeSize/2, -cubeSize/2,  cubeSize/2),
                vec3( cubeSize/2, -cubeSize/2,  cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2,  cubeSize/2),
                vec3(-cubeSize/2,  cubeSize/2,  cubeSize/2)
            }
        end
    end
    if a ~= 0 or c ~= 0 then -- U-D: BL, BR, FR, FL => 9, 10, 11, 12
        local bly = (d + a/2 + c/2) / b
        local bry = (d - a/2 + c/2) / b
        local fry = (d - a/2 - c/2) / b
        local fly = (d + a/2 - c/2) / b
        if math.abs(bly) <= 1/2 then points[ 9] = vec3(-1/2, bly, -1/2) end
        if math.abs(bry) <= 1/2 then points[10] = vec3( 1/2, bry, -1/2) end
        if math.abs(fry) <= 1/2 then points[11] = vec3( 1/2, fry, 1/2) end
        if math.abs(fly) <= 1/2 then points[12] = vec3(-1/2, fly, 1/2) end
    else
        if p.y == -1/2 then
            return {
                vec3(-cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2, -cubeSize/2,  cubeSize/2),
                vec3(-cubeSize/2, -cubeSize/2,  cubeSize/2)
            }
        elseif p.y == 1/2 then
            return {
                vec3(-cubeSize/2,  cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2,  cubeSize/2),
                vec3(-cubeSize/2,  cubeSize/2,  cubeSize/2)
            }
        end
    end
    if b ~= 0 or c ~= 0 then -- L-R: UB, DB, DF, UF => 1, 5, 7, 3
        local ubx = (d + b/2 + c/2) / a
        local dbx = (d - b/2 + c/2) / a
        local dfx = (d - b/2 - c/2) / a
        local ufx = (d + b/2 - c/2) / a
        if math.abs(ubx) <= 1/2 then points[1] = vec3(ubx, -1/2, -1/2) end
        if math.abs(dbx) <= 1/2 then points[5] = vec3(dbx,  1/2, -1/2) end
        if math.abs(dfx) <= 1/2 then points[7] = vec3(dfx,  1/2,  1/2) end
        if math.abs(ufx) <= 1/2 then points[3] = vec3(ufx, -1/2,  1/2) end
    else
        if p.x == -1/2 then
            return {
                vec3(-cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3(-cubeSize/2,  cubeSize/2, -cubeSize/2),
                vec3(-cubeSize/2,  cubeSize/2,  cubeSize/2),
                vec3(-cubeSize/2, -cubeSize/2,  cubeSize/2)
            }
        elseif p.x == 1/2 then
            return {
                vec3( cubeSize/2, -cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2, -cubeSize/2),
                vec3( cubeSize/2,  cubeSize/2,  cubeSize/2),
                vec3( cubeSize/2, -cubeSize/2,  cubeSize/2)
            }
        end
    end
    local vertices = {}
    for i = 1, 12 do 
        if points[i] then
            table.insert(vertices, r:rotate(points[i]) * cubeSize + cubePosition)
        end
    end
    local center = vec3.zero()
    for i, vertex in ipairs(vertices) do
        center = center + vertex
    end
    center = center / #vertices
    angles = {}
    local q = quat.between(vec3.forward(), planeNormal)
    for i, vertex in ipairs(vertices) do
        angles[vertex] = vec2.angle(vec2(q:rotate(vertex)))
    end
    table.sort(vertices, function(a, b) return angles[a] < angles[b] end)
    return vertices
end

function meshCut(mesh, planeOrigin, planeNormal)
    if planeNormal.len == 0 then return {} end
    local q = quat.between(planeNormal, vec3.forward())
    local vertices = {}
    for i, vertex in ipairs(mesh.vertices) do
        vertices[i] = q:rotate(vertex - planeOrigin)
    end
    local normals = {}
    for i, normal in ipairs(mesh.normals) do
        normals[i] = q:rotate(normal)
    end
    local intersects, intersectsByEdge = {}, {}
    for i, edge in ipairs(mesh.edges) do
        if math.sign(vertices[edge[1]].z) ~= math.sign(vertices[edge[2]].z) then

        elseif vertices[edge[1]].z == 0 and vertices[edge[2]].z == 0 then

        end
    end
end

-- callbacks

function love.load(args)
    size = tonumber(args[1] or 1)
    mesh = blockMesh(size)
    a, b, c = vec3(-size/2, -size/2, -size/2), vec3( size/2, -size/2,  size/2), vec3( size/2,  size/2, -size/2)
    if #args >= 10 then
        a = vec3(tonumber(args[2]), tonumber(args[3]), tonumber(args[ 4]))
        b = vec3(tonumber(args[5]), tonumber(args[6]), tonumber(args[ 7]))
        c = vec3(tonumber(args[8]), tonumber(args[9]), tonumber(args[10]))
    end
    planePoint = a
    planeNormal = (a - b):cross(a - c)
    cut = {
        points = {a, b, c},
        vertices = cubeCut(vec3.zero(), size, vec3.zero(), planePoint, planeNormal),
        faces = {{}, {}},
        normals = {planeNormal, -planeNormal}
    }
    for i = 1, #cut.vertices do cut.faces[1][i] = i cut.faces[2][i] = #cut.vertices - i + 1 end

    sqit = require "sqit"

    scene = sqit.new{}

    scene.add({
        z = -1,
        size = size,
        sensitivity = 0.01,
        rotation = vec3.zero(),
        screenSize = vec2(0, 0),
        check = function(self, x, y) return true end,
        moved = function(self, x, y, dx, dy)
            self.rotation = self.rotation + vec3(dy * self.sensitivity, -dx * self.sensitivity, 0)
            self.rotation.x = math.max(-math.pi/2, math.min(math.pi/2, self.rotation.x))
        end,
        resize = function(self, w, h)
            self.screenSize = vec2(w, h)
        end,
        draw = function(self)
            love.graphics.translate((self.screenSize/2):unpack())
            local scale = math.min(self.screenSize:unpack())/2 / self.size
            love.graphics.scale(scale)
            love.graphics.setLineWidth(1 / scale)
            local q = quat.fromEuler(self.rotation)

            local meshData = getMeshData(mesh, vec3.zero(), self.rotation, 1)
            local cutData = getMeshData(cut, vec3.zero(), self.rotation, 1)

            --- draw invisible parts
            love.graphics.setColor(1, 1, 1)
            for i, edge in ipairs(mesh.edges) do
                if not meshData.edgesVisible[i] then
                    local a, b = meshData.vertices[edge[1]], meshData.vertices[edge[2]]
                    dashedLine(a.x, a.y, b.x, b.y, 10 / scale)
                end
            end
            love.graphics.setColor(0, 1, 0)
            for i, vertex in ipairs(meshData.vertices) do
                if not meshData.verticesVisible[i] then
                    love.graphics.circle("line", vertex.x, vertex.y, 5 / scale)
                end
            end
            --- draw the cut
            love.graphics.setColor(1, 0, 0, 0.5)
            if #cutData.vertices >= 3 then
                love.graphics.polygon("fill", vec2.convertArray(cutData.vertices))
            end
            love.graphics.setColor(1, 0, 0)
            for i, vertex in ipairs(cutData.vertices) do
                love.graphics.circle("line", vertex.x, vertex.y, 5 / scale)
            end
            --- draw visible parts
            love.graphics.setColor(1, 1, 1)
            for i, edge in ipairs(mesh.edges) do
                if meshData.edgesVisible[i] then
                    local a, b = meshData.vertices[edge[1]], meshData.vertices[edge[2]]
                    love.graphics.line(a.x, a.y, b.x, b.y)
                end
            end
            love.graphics.setColor(0, 1, 0)
            for i, vertex in ipairs(meshData.vertices) do
                if meshData.verticesVisible[i] then
                    love.graphics.circle("fill", vertex.x, vertex.y, 5 / scale)
                end
            end

            -- draw cut reference points
            love.graphics.setColor(1, 0.5, 0)
            for i, point in ipairs(cut.points) do
                local p = q:rotate(point)
                love.graphics.circle("fill", p.x, p.y, 5 / scale)
            end

            -- draw the coordinate system
            local s = 0.25 * size
            local x, y, z = q:rotate(vec3.right() * s), q:rotate(vec3.down() * s), q:rotate(vec3.forward() * s)
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