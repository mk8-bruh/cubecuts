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
        normals[i] = vec3.is(_n[i]) and _n[i] or (flipNormals and -1 or 1) * (vertices[faces[i][1]] - vertices[faces[i][2]]):cross(vertices[faces[i][1]] - vertices[faces[i][3]]).norm
    end
    local edgeLookup, edges, edgesWithVertex, facesWithVertex, facesWithEdge, edgesInFace = {}, {}, {}, {}, {}, {}
    for i = 1, nv do edgeLookup[i], edgesWithVertex[i], facesWithVertex[i] = {}, {}, {} end
    for i, face in ipairs(faces) do
        edgesInFace[i] = {}
        for j = 1, #face do
            local a, b = j, (j % #face) + 1
            if not edgeLookup[face[a]][face[b]] then
                table.insert(edges, {face[a], face[b]})
                edgeLookup[face[a]][face[b]] = #edges
                edgeLookup[face[b]][face[a]] = #edges
                table.insert(edgesWithVertex[face[a]], #edges)
                table.insert(edgesWithVertex[face[b]], #edges)
                facesWithEdge[#edges] = {}
            end
            table.insert(facesWithVertex[face[a]], i)
            table.insert(facesWithVertex[face[b]], i)
            table.insert(facesWithEdge[edgeLookup[face[a]][face[b]]], i)
            table.insert(edgesInFace[i], edgeLookup[face[a]][face[b]])
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

function spireMesh(tip, baseY, ...)
    local points = {...}
    local n = #points
    if n == 0 then return end
    local angles = {}
    for i, p in ipairs(points) do
        p.y = baseY
        angles[p] = vec2.angle(vec2(p.x, p.z))
    end
    table.sort(points, function(a, b) return angles[a] < angles[b] end)
    table.insert(points, tip)
    local faces, base = {}, {}
    for i = 1, n do
        table.insert(faces, {i, (i % n) + 1, n + 1})
        table.insert(base, 1, i)
    end
    table.insert(faces, base)
    return polyMesh(points, faces)
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
        position = position,
        rotation = rotation,
        scale = scale,
        vertices = vertices,
        normals = normals,
        verticesVisible = verticesVisible,
        edgesVisible = edgesVisible,
        facesVisible = facesVisible
    }, {__index = mesh})
end

function meshCut(mesh, planeOrigin, planeNormal)
    if planeNormal.len == 0 then return {} end
    local q = quat.between(planeNormal, vec3.forward())
    local qi = q.inv
    local vertices = {}
    for i, vertex in ipairs(mesh.vertices) do
        vertices[i] = q:rotate(vertex - planeOrigin)
    end
    local points, edges = {}, {}
    local pointsByEdge, pointInFaces, edgeByFace, faceByEdge = {}, {}, {}, {}
    for i, edge in ipairs(mesh.edges) do
        pointsByEdge[i] = {}
        if math.sign(vertices[edge[1]].z) ~= math.sign(vertices[edge[2]].z) then
            local point = -vertices[edge[1]].z / (vertices[edge[2]].z - vertices[edge[1]].z) * (vertices[edge[2]] - vertices[edge[1]]) + vertices[edge[1]]
            table.insert(points, qi:rotate(point) + planeOrigin)
            pointsByEdge[i] = {#points}
            pointInFaces[#points] = table.shallowcopy(mesh.facesWithEdge[i])
        elseif math.sign(vertices[edge[1]].z) == 0 then
            table.insert(points, qi:rotate(vertices[edge[1]]) + planeOrigin)
            table.insert(points, qi:rotate(vertices[edge[2]]) + planeOrigin)
            pointsByEdge[i] = {#points - 1, #points}
            pointInFaces[#points - 1], pointInFaces[#points] = table.shallowcopy(mesh.facesWithVertex[edge[1]]), table.shallowcopy(mesh.facesWithVertex[edge[2]])
            table.insert(edges, {#points - 1, #points})
        end
    end
    for i, faceEdges in ipairs(mesh.edgesInFace) do
        for j = 1, #faceEdges do
            for k = j + 1, #faceEdges do
                local a, b = faceEdges[j], faceEdges[k]
                if #pointsByEdge[a] == 1 and #pointsByEdge[b] == 1 then
                    table.insert(edges, {pointsByEdge[a][1], pointsByEdge[b][1]})
                    edgeByFace[i] = #edges
                    faceByEdge[#edges] = i
                end
            end
            if edgeByFace[i] then break end
        end
    end
    return {
        mesh = mesh,
        points = points,
        edges = edges,
        pointByEdge = pointByEdge,
        pointInFaces = pointInFaces,
        edgeByFace = edgeByFace,
        faceByEdge = faceByEdge
    }
end

function getCutData(cut, data)
    local points = {}
    local pointsVisible, edgesVisible = {}, {}
    for i, point in ipairs(cut.points) do
        points[i] = data.rotation:rotate(point * data.scale) + data.position
        pointsVisible[i] = false
        for j, face in ipairs(cut.pointInFaces[i]) do
            if data.facesVisible[face] then
                pointsVisible[i] = true
            end
        end
    end
    for i, edge in ipairs(cut.edges) do
        edgesVisible[i] = data.facesVisible[cut.faceByEdge[i]]
    end

    return setmetatable({
        data = data,
        points = points,
        pointsVisible = pointsVisible,
        edgesVisible = edgesVisible
    }, {__index = cut})
end