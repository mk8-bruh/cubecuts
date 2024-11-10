--[[
SQIT - Super Quick Interface Toolkit

small and simplistic UI library by mk8

usage:
    importing:
        sqit = require "sqit"
    creating a UI instance:
        ui = sqit()
        or
        ui = sqit.new()
    adding/removing elements:
        ui.add(elem, [name]) - optionally assigns a name by which the element can be retrieved from the instance (if there was previously an element registered under the same name, it will be overwritten!), can be used to assign name to an already added element
        ui.remove(elem) - remove an element either by its object or by its name
        (chaining: ui.add(e1).add(e2).remove(e3) etc.)
    element properties:
        x, y, w, h: the position and size of the bounding box of the element
        z: sorting order priority
    element callbacks:
        e:check(x, y) - checking function for custom element shapes, should return true if the point x, y is inside of the element's hitbox, false otherwise
        e:pressed(x, y) - called when the element's press is initiated (if this function returns false, the press will be cancelled and passed to the next z layer)
        e:moved(x, y, dx, dy) - called when the element's press moves (if this function returns a boolean value, as long as it is true the element will remain pressed even if the press exits the bounding area)
        e:released(x, y) - called when the element's press is released
        e:cancelled() - called when the element's press is cancelled (not released properly)
        e:scrolled(t) - called when the mousewheel is moved over the element
        e:activated() - called when the element is activated
        e:deactivated() - called when the element is deactivated or a new element is activated
        e:hovered() - called when the cursor enters this element's bounding box (if this function returns false, the hover will be cancelled and passed to the next z layer)
        e:unhovered() - called when the cursor exits this element's bounding box
        e:enabled() - called right after this object (or the entire instance) is enabled
        e:disabled() - called right before this object (or the entire instance) is disabled
        LÖVE callbacks:
            resize, update, draw,
            keypressed, keyreleased, textinput,
            filedropped, directorydropped,
            joystickadded, joystickremoved,
            joystickaxis, joystickhat, joystickpressed, joystickreleased,
            gamepadaxis, gamepadpressed, gamepadreleased
            (all callbacks are passed with the element as self)
    instance callbacks (to be called from within the respective LÖVE callbacks):
        resize, update, draw, quit,
        pressed, moved, released,
        mousepressed, mousemoved, mousereleased, wheelmoved,
        touchpressed, touchmoved, touchreleased,
        keypressed, keyreleased, textinput,
        filedropped, directorydropped,
        joystickadded, joystickremoved,
        joystickaxis, joystickhat, joystickpressed, joystickreleased,
        gamepadaxis, gamepadpressed, gamepadreleased
        (all element callbacks are instance callbacks)
        (all input callbacks return true if the instance responded to the input, which can be used for blocking the inputs)
    instance methods (all elements can be specified by their object or by their registered name):
        ui.registerCallbacks() - automatically register all instance callbacks
        ui.contains(...) - check whether the instance contains the element(s)
        ui.hasNamed(n) - check if the insance has an element registered under this name
        ui.getNamed(n) - retrieve the element registered under this name
        ui.activate(e) - activate an element within the instance
        ui.deactivate(e) - deactivate an element (or the currently active element)
        ui.isActive(e) - check whether an element is active
        ui.getActive() - get the currently active element
        ui.isPressed(e) - check whether an element is currently pressed
        ui.getPress(e) - get the element's press identificator
        ui.getPressID(e) - if the element is pressed with a touch, retrieve the touch's ID
        ui.getPressButton(e) - if the element is pressed with the mouse, retrieve the mouse button
        ui.getPressPosition(e) - get the position of the element's press
        ui.cancelPress(e) - cancel the element's press (without properly releasing it)
        ui.transferPress(e1, e2) - cancel both elements' current presses, then press the second element with the first element's press
        ui.getHovered() - get the currently hovered element
        ui.isHovered(e) - check whether the element is currently hovered
        ui.refreshHover() - recalculates mouse hover (called automatically in ui.update, if not using this callback it should be called when a hoverable element's z value is changed, as this library can't automatically detect that)
        ui.setEnabled(v) - changes the enabled state of the instance (when disabled, the element or instance won't register any callbacks apart from resize)
        ui.setEnabled(e, v) - changes the enabled state of an element
        ui.isEnabled() - retrieves the enabled state of the instance
        ui.isEnabled(e) - retrieves the enabled state of an element
        ui.getElements(r) - get a list of all the elements in the instance, sorted from front to back (decreasing z values, r reverses the sorting order)
    (note: instance functions can also be called with semicolon)
    instance properties:
        ui.callbacks - a table containing all the instance's extra callbacks (the extra callbacks are called right before the elements' respective callbacks, they can be set by overriding the fields in the instance table itself or in this table)
--]]

_NAME = "SQIT"
_VERSION = "1.0"

local function emptyf() return end
local function clamp(x, a, b) a, b = math.min(a, b), math.max(a, b) return math.max(a, math.min(b, x)) end
local function inrect(x, y, l, t, w, h) return x == clamp(x, l, l + w) and y == clamp(y, t, t + h) end
local function hasbbox(e) if type(e) ~= "table" then return false end for _,k in ipairs{"x","y","w","h"} do if type(e[k]) ~= "number" then return false end end return true end
local function check(e, x, y) return (type(e.check) == "function" and e:check(x, y)) or (hasbbox(e) and inrect(x, y, e.x, e.y, e.w, e.h)) end

local function zsorted(elem, rev)
    local r = {}
    for e in pairs(elem) do
        local z = e.z or 0
        local s = false
        for i,o in ipairs(r) do
            local oz = o.z or 0
            if (rev and z < oz) or (not rev and z > oz) then
                table.insert(r, i, e)
                s = true
                break
            end
        end
        if not s then table.insert(r, e) end
    end
    return r
end

local callbackNames, activeCallbackNames, blockingCallbackNames = {
    "resize", "update", "draw", "quit",

    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",
    "activated", "deactivated", "enabled", "disabled",

    "mousepressed", "mousemoved", "mousereleased", "wheelmoved",
    "touchpressed", "touchmoved", "touchreleased",
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}, {
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved", "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}, {
    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",
    "activated", "deactivated", "enabled", "disabled",

    "mousepressed", "mousemoved", "mousereleased", "wheelmoved",
    "touchpressed", "touchmoved", "touchreleased",
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved", "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

local lib = {}

function lib.new(o)
    local elem = {}
    local named = {}
    local ui = {}
    local presses = {}
    local hovered = nil
    local active = nil
    local enabled = true
    local callbacks = {}
    
    for _,n in ipairs(callbackNames) do
       callbacks[n] = emptyf
    end

    function ui.contains(...)
        local v = true
        for i, e in ipairs{...} do
            v = v and (elem[e] ~= nil)
        end
        return v
    end

    function ui.add(e, n)
        if type(e) == "table" then
            elem[e] = true
            if type(n) == "string" then
                named[n] = e
            end
        end
    end

    function ui.remove(e)
        if ui.contains(e) then
            elem[e] = nil
        elseif ui.hasNamed(e) then
            elem[named[e]] = nil
            named[e] = nil
        end
    end

    function ui.hasNamed(n)
        return named[n] ~= nil
    end

    function ui.getNamed(n)
        return named[n]
    end

    local function convertNames(...)
        local t = {}
        for i, e in ipairs{...} do
            t[i] = ui.getNamed(e) or e
        end
        return unpack(t)
    end

    function ui.activate(e)
        e = convertNames(e)
        ui.deactivate()
        if ui.contains(e) and ui.isEnabled(e) then
            active = e
            if type(e.activated) == "function" then
                e:activated()
            end
        end
    end

    function ui.deactivate(e)
        e = convertNames(e)
        if active and active == (e or active) then
            if type(active.deactivated) == "function" then
                active:deactivated()
            end
            active = nil
        end
    end

    function ui.getActive()
        return active
    end

    function ui.isActive(e)
        e = convertNames(e)
        return active == e
    end

    function ui.isPressed(e)
        e = convertNames(e)
        return presses[e] and true or false
    end

    function ui.getPress(e)
        e = convertNames(e)
        return presses[e]
    end

    function ui.getPressID(e)
        e = convertNames(e)
        return type(presses[e]) == "userdata" and presses[e]
    end

    function ui.getPressButton(e)
        e = convertNames(e)
        return type(presses[e]) == "number" and presses[e]
    end

    function ui.getPressPosition(e)
        e = convertNames(e)
        local id = presses[e]
        if type(id) == "number" then
            return love.mouse.getPosition()
        elseif type(id) == "userdata" then
            return love.touch.getPosition(id)
        end
    end

    function ui.cancelPress(e)
        e = convertNames(e)
        if presses[e] then
            presses[e] = nil
            if type(e.cancelled) == "function" then
                e:cancelled()
            end
        end
    end

    function ui.transferPress(e1, e2)
        e1, e2 = convertNames(e1, e2)
        if ui.contains(e1, e2) then
            local p = presses[e1]
            if p then
                ui.cancelPress(e1)
                ui.cancelPress(e2)
                presses[e2] = p
                if type(e2.pressed) == "function" then
                    if e2:pressed(x, y) ~= false then
                        return true
                    else
                        presses[e2] = nil
                    end
                elseif type(e2.pressed) ~= "bool" or e2.pressed then
                    return true
                end
            end
            return false
        end
    end

    function ui.getHovered()
        return hovered
    end

    function ui.isHovered(e)
        e = convertNames(e)
        return hovered == e
    end

    function ui.pressed(k, x, y)
        for _,v in ipairs(zsorted(elem)) do if elem[v] then
            if check(v, x, y) then
                presses[v] = k
                if type(v.pressed) == "function" then
                    local r = v:pressed(x, y)
                    if r ~= false then
                        return true
                    else
                        presses[v] = nil
                    end
                elseif type(v.pressed) ~= "bool" or v.pressed then
                    return true
                end
            end
        end end
        return false
    end

    function ui.moved(k, x, y, dx, dy)
        for v in pairs(elem) do if elem[v] then
            if presses[v] == k then
                if type(v.moved) == "function" then
                    local r = v:moved(x, y, dx, dy)
                    if type(r) == "boolean" then
                        if not r then
                            ui.cancelPress(v)
                        end
                    elseif not check(v, x, y) then
                        ui.cancelPress(v)
                    end
                elseif not check(v, x, y) then
                    ui.cancelPress(v)
                end
            end
        end end
    end

    function ui.released(k, x, y)
        local r = false
        for v in pairs(elem) do if elem[v] then
            if presses[v] == k then
                if type(v.released) == "function" then
                    v:released(x, y)
                end
                presses[v] = nil
                r = true
            end
        end end     
        return r
    end

    function ui.refreshHover()
        local prev = hovered
        hovered = nil
        local x, y = love.mouse.getPosition()
        for _,v in ipairs(zsorted(elem)) do if elem[v] then
            if check(v, x, y) then
                hovered = v
                if v ~= prev then
                    if type(v.hovered) == "function" then
                        if v:hovered() ~= false then
                            break
                        else
                            hovered = nil
                        end
                    elseif v.hovered == false then
                        hovered = nil
                    else
                        break
                    end
                else break end
            end
        end end
        if prev and prev ~= hovered then
            if type(prev.unhovered) == "function" then
               prev:unhovered()
           end 
        end
    end

    function ui.mousepressed(x, y, b, t)
        if not t and b then
            return ui.pressed(b, x, y)
        end
    end        

    function ui.mousemoved(x, y, dx, dy)
        for v,k in pairs(presses) do
            if type(k) == "number" then
                ui.moved(k, x, y, dx, dy)
            end
        end
    end

    function ui.mousereleased(x, y, b, t)
        if not t and b then
            return ui.released(b, x, y)
        end
    end

    function ui.touchpressed(id, x, y)
        return ui.pressed(id, x, y)
    end

    function ui.touchmoved(id, x, y, dx, dy)
        ui.moved(id, x, y, dx, dy)
    end

    function ui.touchreleased(id, x, y)
        return ui.released(id, x, y)
    end

    function ui.wheelmoved(x, y)
        if hovered and type(hovered.scrolled) == "function" then
            hovered:scrolled(y)
            return true
        end
        return false
    end

    function ui.resize(w, h)
        for v in pairs(elem) do
            if type(v.resize) == "function" then
                v:resize(w, h)
            end
        end
    end

    function ui.update(dt)
        ui.refreshHover()
        for _,v in ipairs(zsorted(elem)) do if elem[v] then
            if type(v.update) == "function" then
                v:update(dt)
            end
        end end
    end

    function ui.draw()
        for _,v in ipairs(zsorted(elem, true)) do if elem[v] then
            if type(v.draw) == "function" then
                love.graphics.push("all")
                v:draw()
                love.graphics.pop()
            end
        end end
    end

    for _,f in ipairs(activeCallbackNames) do
        ui[f] = function(...)
            if active and type(active[f]) == "function" then
                active[f](active, ...)
                return true
            end
        end
    end

    function ui.registerCallbacks()
        local _update = love.update or emptyf
        love.update = function(...)
            ui.update(...)
            _update(...)
        end
        local _draw = love.draw or emptyf
        love.draw = function(...)
            _draw(...)
            ui.draw(...)
        end
        local _resize = love.resize or emptyf
        love.resize = function(...)
            ui.resize(...)
            _resize(...)
        end
        local _quit = love.quit or emptyf
        love.quit = function(...)
            ui.quit(...)
            return _quit(...)
        end
        for _,f in ipairs(blockingCallbackNames) do
            local _f = love[f] or emptyf
            love[f] = function(...)
                if ui[f](...) then return end
                _f(...)
            end
        end
    end

    function ui.setEnabled(e, v)
        e = convertNames(e)
        if ui.contains(e) then
            elem[e] = v and true or false
            if not enabled then
                if type(e.disabled) == "function" then
                    e:disabled()
                end
                ui.cancelPress(e)
            else
                if type(e.enabled) == "function" then
                    e:enabled()
                end
            end
        elseif type(e) == "boolean" then
            enabled = e and true or false
            if not enabled then
                for v in pairs(elem) do
                    if type(v.disabled) == "function" then
                        v:disabled()
                    end
                    ui.cancelPress(v)
                end
            else
                for v in pairs(elem) do
                    if type(v.enabled) == "function" then
                        v:enabled()
                    end
                end
            end
        end
    end

    function ui.isEnabled(e)
        e = convertNames(e)
        if ui.contains(e) then
            return elem[e]
        elseif e == nil then
            return enabled and true or false
        end
    end

    function ui.getElements(r)
        return zsorted(elem, r)
    end

    local t = {}

    for i, n in ipairs(callbackNames) do
        local f = ui[n] or emptyf
        ui[n] = function(...)
            if enabled or n == "resize" then
                local args = {...}
                while args[1] == t do table.remove(args, 1) end
                if n == "draw" then love.graphics.push("all") end
                local r = callbacks[n](t, unpack(args))
                if r ~= false then r = r or f(unpack(args)) end
                if n == "draw" then love.graphics.pop() end
                return r
            end
        end
    end

    for _, k in ipairs{"add", "remove"} do
        local f = ui[k]
        ui[k] = function(...)
            f(...)
            return t
        end
    end

    ui.callbacks = setmetatable({}, {
        __index = function(t, k)
            return callbacks[k] ~= emptyf and callbacks[k] or nil
        end,
        __newindex = function(t, k, v)
            if callbacks[k] and type(v) == "function" then
                callbacks[k] = v
            elseif callbacks[k] and v == nil then
                callbacks[k] = emptyf
            end
        end,
        __metatable = {}
    })

    setmetatable(t, {
        __index = function(t, k)
            return ui[k] or named[k]
        end,
        __newindex = function(t, k, v)
            if callbacks[k] and type(v) == "function" then
                callbacks[k] = v
            elseif callbacks[k] and v == nil then
                callbacks[k] = emptyf
            elseif not ui[k] then
                rawset(t, k, v)
            end
        end,
        __metatable = {},
        __tostring = function(t) return ("[%s instance]"):format(_NAME) end
    })

    if type(o) == "table" then
        for k, v in pairs(o) do
            t[k] = v
        end
    end

    return t
end

return setmetatable({}, {
    __index = lib,
    __newindex = function() end,
    __call = lib.new,
    __metatable = {},
    __tostring = function() return ("[%s v%s]"):format(_NAME, _VERSION) end
})
