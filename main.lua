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

function parseExpression(e)
    local s, f = pcall(loadstring, "return " .. e)
    if s and f then
        setfenv(f, math)
        local _s, v = pcall(f)
        if _s then
            return v
        end
    end
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

-- callbacks

function love.load(args)
    require "mesh"

    _MOBILE = love.system.getOS() == "Android" or love.system.getOS() == "iOS"

    axisColors = {
        x = {1, 0, 0},
        y = {0, 1, 0},
        z = {0, 0, 1}
    }

    size = vec3(1, 1, 1)
    mesh = blockMesh(size)

    plane = {
        vec3(-1/2, -1/2, -1/2),
        vec3( 1/2, -1/2,  1/2),
        vec3( 1/2,  1/2, -1/2)
    }
    planeColors = {
        {0, 1, 1},
        {1, 0, 1},
        {1, 1, 0}
    }

    function recalculateCut()
        planePoint = plane[1]
        planeNormal = (plane[1] - plane[2]):cross(plane[1] - plane[3])
        cut = meshCut(mesh, planePoint, planeNormal)
    end
    recalculateCut()

    sqit = require "sqit"
    sqitutils = require "sqitutils"
    style = require "style"

    scene = sqit.new{}

    margin = 10
    mobileTopMargin = 60

    shapeUI = sqit.new{
        fields = {},
        z = 0,
        w = 100, h = 100,
        cornerRadius = 5,
        resize = function(self, w, h)
            if _MOBILE then
                self.x = margin
                self.y = mobileTopMargin
            else
                self.x = margin
                self.y = h - self.h - margin
            end
            for i, f in ipairs(self.fields) do f.x = self.x + self.w/2 end
            sqitutils.stretchOut(self.fields, "y", self.y, self.y + self.h, true)
        end,
        draw = function(self)
            love.graphics.setColor(style.textbox.color.default)
            love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, self.cornerRadius)
            love.graphics.setColor(style.textbox.outline.color.default)
            love.graphics.setLineWidth(style.textbox.outline.width)
            love.graphics.rectangle("line", self.x, self.y, self.w, self.h, self.cornerRadius)
        end
    }
    for j, d in ipairs{"x", "y", "z"} do
        local f = sqitutils.newInlineTextbox{
            style = style.textbox,
            scene = scene,
            z = 1,
            w = 80,
            text = tostring(size[d]),
            alttext = d:upper(),
            textcolor = axisColors[d],
            action = function(self)
                local v = parseExpression(self.text)
                if type(v) == "number" then
                    size[d] = v
                    mesh = blockMesh(size)
                    recalculateCut()
                else
                    self.text = tostring(size[d])
                end
            end
        }
        table.insert(shapeUI.fields, f)
        scene.add(f)
    end
    scene.add(shapeUI)

    planeUI = sqit.new{
        rows = {},
        z = 0,
        w = 300, h = 100,
        cornerRadius = 5,
        resize = function(self, w, h)
            if _MOBILE then
                self.x = margin
                self.y = mobileTopMargin + shapeUI.h + margin
            else
                self.x = w - self.w - margin
                self.y = h - self.h - margin
            end
            sqitutils.stretchOut(self.rows, "y", self.y, self.y + self.h, true)
        end,
        draw = function(self)
            love.graphics.setColor(style.textbox.color.default)
            love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, self.cornerRadius)
            love.graphics.setColor(style.textbox.outline.color.default)
            love.graphics.setLineWidth(style.textbox.outline.width)
            love.graphics.rectangle("line", self.x, self.y, self.w, self.h, self.cornerRadius)
        end
    }
    for i = 1, 3 do
        local e = sqit.new{
            fields = {},
            w = planeUI.w, h = 25,
            resize = function(self, w, h)
                for i, f in ipairs(self.fields) do f.y = self.y end
                sqitutils.stretchOut(self.fields, "x", planeUI.x, planeUI.x + planeUI.w, true)
                self.x = planeUI.x
            end,
            draw = function(self)
                local r, g, b = unpack(planeColors[i])
                love.graphics.setColor(r, g, b, 0.5)
                love.graphics.rectangle("fill", self.x, self.y - self.h/2, self.w, self.h, planeUI.cornerRadius)
            end
        }
        table.insert(planeUI.rows, e)
        planeUI.add(e)
        for j, d in ipairs{"x", "y", "z"} do
            local f = sqitutils.newInlineTextbox{
                style = style.textbox,
                scene = scene,
                z = 1,
                w = 80,
                text = tostring(plane[i][d]),
                alttext = d:upper(),
                textcolor = axisColors[d],
                action = function(self)
                    local v = parseExpression(self.text)
                    if type(v) == "number" then
                        plane[i][d] = v
                        recalculateCut()
                    else
                        self.text = tostring(plane[i][d])
                    end
                end
            }
            table.insert(e.fields, f)
            scene.add(f)
        end
    end
    scene.add(planeUI)

    scene.add({
        z = -1,
        sensitivity = 0.01,
        rotation = vec3.zero(),
        zoom = 0,
        zoomSpeed = 0.05,
        screenSize = vec2(0, 0),
        check = function(self, x, y) return true end,
        pressed = function(self, x, y)
            scene.activate(self)
        end,
        moved = function(self, x, y, dx, dy)
            self.rotation = self.rotation + vec3(dy * self.sensitivity, -dx * self.sensitivity, 0)
            self.rotation.x = math.max(-math.pi/2, math.min(math.pi/2, self.rotation.x))
        end,
        scrolled = function(self, t)
            self.zoom = self.zoom + t * self.zoomSpeed
        end,
        resize = function(self, w, h)
            self.screenSize = vec2(w, h)
        end,
        draw = function(self)
            local maxSize = math.max(size:unpack())
            if _MOBILE then
                love.graphics.translate(self.screenSize.x/2, self.screenSize.y/2 + (mobileTopMargin + margin + shapeUI.h + planeUI.h)/2)
            else
                love.graphics.translate((self.screenSize/2):unpack())
            end
            local scale = math.min(self.screenSize:unpack())/2 / maxSize * math.exp(self.zoom)
            love.graphics.scale(scale)
            love.graphics.setLineWidth(1 / scale)
            local q = quat.fromEuler(self.rotation)

            local meshData = getMeshData(mesh, vec3.zero(), self.rotation)
            local cutData = getCutData(cut, meshData)

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
            love.graphics.setColor(1, 0, 0)
            for i, point in ipairs(cutData.points) do
                if not cutData.pointsVisible[i] then
                    love.graphics.circle("line", point.x, point.y, 5 / scale)
                end
            end
            love.graphics.setColor(1, 0.5, 0)
            for i, edge in ipairs(cut.edges) do
                if not cutData.edgesVisible[i] then
                    local a, b = cutData.points[edge[1]], cutData.points[edge[2]]
                    dashedLine(a.x, a.y, b.x, b.y, 10 / scale)
                end
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
            love.graphics.setColor(1, 0, 0)
            for i, point in ipairs(cutData.points) do
                if cutData.pointsVisible[i] then
                    love.graphics.circle("fill", point.x, point.y, 5 / scale)
                end
            end
            love.graphics.setColor(1, 0.5, 0)
            for i, edge in ipairs(cut.edges) do
                if cutData.edgesVisible[i] then
                    local a, b = cutData.points[edge[1]], cutData.points[edge[2]]
                    love.graphics.line(a.x, a.y, b.x, b.y)
                end
            end

            -- draw plane reference points
            for i, p in ipairs(plane) do
                p = q:rotate(p)
                love.graphics.setColor(planeColors[i])
                love.graphics.circle("fill", p.x, p.y, 5 / scale)
            end

            -- draw the coordinate system
            local s = 0.25 * maxSize
            local x, y, z = q:rotate(vec3.right() * s), q:rotate(vec3.down() * s), q:rotate(vec3.forward() * s)
            love.graphics.setColor(axisColors.x)
            love.graphics.line(0, 0, x.x, x.y)
            love.graphics.setColor(axisColors.y)
            love.graphics.line(0, 0, y.x, y.y)
            love.graphics.setColor(axisColors.z)
            love.graphics.line(0, 0, z.x, z.y)
        end
    }, "viewport")

    scene.registerCallbacks()
    scene.resize(love.graphics.getDimensions())
end