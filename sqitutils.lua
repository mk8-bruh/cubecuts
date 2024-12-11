local utf8 = require("utf8")

local emptyf = function(...) return ... end

local inlineScrollSpeed = 10
local inlineScrollThreshold = 3

local textButton = {
    check = function(t, x, y)
        return math.abs(x - t.x) <= t.w/2 and math.abs(y - t.y) <= t.h/2
    end,
    draw = function(t)
        love.graphics.setColor((t.scene.isPressed(t) and t.style.color.pressed) or (t.scene.isHovered(t) and t.style.color.hovered) or (t.scene.isActive(t) and t.style.color.active) or t.style.color.default)
        love.graphics.rectangle("fill", t.x - t.w/2, t.y - t.h/2, t.w, t.h, t.style.shape.cornerRadius)
        love.graphics.setColor((t.scene.isPressed(t) and t.style.outline.color.pressed) or (t.scene.isHovered(t) and t.style.outline.color.hovered) or (t.scene.isActive(t) and t.style.outline.color.active) or t.style.outline.color.default)
        love.graphics.setLineWidth(t.style.outline.width)
        love.graphics.rectangle("line", t.x - t.w/2, t.y - t.h/2, t.w, t.h, t.style.shape.cornerRadius)
        love.graphics.setColor((t.scene.isPressed(t) and t.style.text.color.pressed) or (t.scene.isHovered(t) and t.style.text.color.hovered) or (t.scene.isActive(t) and t.style.text.color.active) or t.style.text.color.default)
        love.graphics.setFont(t.style.text.font)
        love.graphics.print(t.text, t.x - t.style.text.font:getWidth(t.text)/2, t.y - t.style.text.font:getHeight()/2)
    end,
    released = function(t)
        t:action()
    end,
    keypressed = function(t, k)
        if k == "return" or k == "space" then
            t:action()
        elseif k == "up" then
            if t.previous then t.scene.activate(t.previous) end
        elseif k == "down" then
            if t.next then t.scene.activate(t.next) end
        end
    end
}
local textButtonMt = {
    __index = function(t, k)
        if k == "text" then return ""
        elseif k == "w" then return t.style.text.font:getWidth(t.text) + 2*t.style.shape.padding.x
        elseif k == "h" then return t.style.text.font:getHeight() + t.style.shape.padding.y * 2
        elseif k == "action" then return emptyf
        else return textButton[k] end
    end
}

local inlineTextbox = {
    check = function(t, x, y)
        return math.abs(x - t.x) <= t.w/2 and math.abs(y - t.y) <= t.h/2
    end,
    update = function(t, dt)
        local txt = (t.scene.isActive(t) or utf8.len(t.text) > 0) and t.encrypt(t.text) or t.alttext
        t.cursorBlink = (t.cursorBlink + 2*t.style.cursor.blinkSpeed * dt) % 2
        t.scroll = math.min(math.max(t.scroll, t.w - 2*t.style.shape.padding.x - (t.style.text.font:getWidth(txt) + math.ceil(t.style.cursor.width/2))), 0)
    end,
    draw = function(t)
        love.graphics.setColor((t.scene.isActive(t) and t.style.color.active) or (t.scene.isHovered(t) and t.style.color.hovered) or t.style.color.default)
        love.graphics.rectangle("fill", t.x - t.w/2, t.y - t.h/2, t.w, t.h, t.style.shape.cornerRadius)
        love.graphics.setColor((t.scene.isActive(t) and t.style.outline.color.active) or (t.scene.isHovered(t) and t.style.outline.color.hovered) or t.style.outline.color.default)
        love.graphics.setLineWidth(t.style.outline.width)
        love.graphics.rectangle("line", t.x - t.w/2, t.y - t.h/2, t.w, t.h, t.style.shape.cornerRadius)
        love.graphics.stencil(function()
            love.graphics.setColorMask(false, false, false, false)
            love.graphics.rectangle("fill", t.x - t.w/2 + t.style.shape.padding.x, t.y - t.h/2 + t.style.shape.padding.y, t.w - 2*t.style.shape.padding.x, t.h - 2*t.style.shape.padding.y)
            love.graphics.setColorMask()
        end, "replace", 1, false)
        love.graphics.setStencilTest("equal", 1)
        if t.scene.isActive(t) or utf8.len(t.text) > 0 then
            local txt = t.encrypt(t.text)
            love.graphics.setColor(t.textcolor or (t.scene.isActive(t) and t.style.text.color.active) or (t.scene.isHovered(t) and t.style.text.color.hovered) or t.style.text.color.default)
            love.graphics.setFont(t.style.text.font)
            love.graphics.print(txt, t.x - t.w/2 + t.style.shape.padding.x + t.scroll, t.y - t.style.text.font:getHeight()/2)
            love.graphics.setStencilTest()
            if t.scene.isActive(t) and math.floor(t.cursorBlink) == 0 then
                local cx = t.x - t.w/2 + t.style.shape.padding.x + t.scroll + t.style.text.font:getWidth(txt:sub(0, utf8.offset(txt, t.cursor + 1) - 1)) + math.ceil(t.style.cursor.width/2)
                love.graphics.setColor(t.style.cursor.color)
                love.graphics.setLineWidth(t.style.cursor.width)
                love.graphics.line(cx, t.y - t.style.text.font:getHeight()/2, cx, t.y + t.style.text.font:getHeight()/2)
            end
        else
            love.graphics.setColor(t.style.alttext.color)
            love.graphics.setFont(t.style.alttext.font)
            love.graphics.print(t.alttext, t.x - t.w/2 + t.style.shape.padding.x + t.scroll, t.y - t.style.alttext.font:getHeight()/2)
        end
    end,
    pressed = function(t, x, y)
        t._press = x
    end,
    moved = function(t, x, y, dx, dy)
        t.scroll = t.scroll + dx
    end,
    released = function(t, x, y)
        if t._press and math.abs(t._press - x) <= inlineScrollThreshold then
            if t.scene.getPressButton(t) == 1 then
                t.scene.activate(t)
                local txt = t.encrypt(t.text)
                local p, d = 0, math.abs(t.x - t.w/2 + t.style.shape.padding.x + t.scroll - x)
                for i = 1, utf8.len(txt) do
                    local o = utf8.offset(txt, i + 1)
                    if math.abs(t.x - t.w/2 + t.style.shape.padding.x + t.scroll + t.style.text.font:getWidth(txt:sub(0, o - 1)) - x) < d then
                        p, d = i, math.abs(t.x - t.w/2 + t.style.shape.padding.x + t.scroll + t.style.text.font:getWidth(txt:sub(0, o - 1)) - x)
                    end
                end
                t.cursor = p
            end
        end
    end,
    activated = function(t)
        love.keyboard.setKeyRepeat(true)
        error(love.system.getOS())
        if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
            love.keyboard.setTextInput(true, self.x - self.w/2, self.y - self.h/2, self.w, self.h)
        end
        t.cursorBlink = 0
    end,
    deactivated = function(t)
        love.keyboard.setKeyRepeat(false)
        if love.system.getOS() == "Android" or love.system.getOS() == "iOS" then
            love.keyboard.setTextInput(false)
        end
    end,
    hovered = function(t)
        love.mouse.setCursor(love.mouse.getSystemCursor("ibeam"))
    end,
    unhovered = function(t)
        love.mouse.setCursor()
    end,
    textinput = function(t, txt)
        t.scroll = t.scroll - t.style.text.font:getWidth(txt)
        t.text = t.text:sub(1, utf8.offset(t.text, t.cursor + 1) - 1) .. txt .. t.text:sub(utf8.offset(t.text, t.cursor + 1), -1)
        t.cursor = t.cursor + utf8.len(txt)
    end,
    keypressed = function(t, k)
        if k == "backspace" then
            if t.cursor > 0 then
                t.scroll = t.scroll + t.style.text.font:getWidth(t.text:sub(utf8.offset(t.text, t.cursor + 1) - 1, utf8.offset(t.text, t.cursor + 1) - 1))
                t.text = t.text:sub(1, utf8.offset(t.text, t.cursor) - 1) .. t.text:sub(utf8.offset(t.text, t.cursor + 1), -1)
                t.cursor = t.cursor - 1
            end
        elseif love.keyboard.isDown("lctrl", "rctrl") and k == "v" then
            t:textinput(love.system.getClipboardText() or "")
        elseif k == "left" then
            if t.cursor > 0 then
                t.scroll = t.scroll + t.style.text.font:getWidth(t.text:sub(utf8.offset(t.text, t.cursor + 1) - 1, utf8.offset(t.text, t.cursor + 1) - 1))
                t.cursor = t.cursor - 1
            end
        elseif k == "right" then
            if t.cursor < utf8.len(t.text) then
                t.scroll = t.scroll - t.style.text.font:getWidth(t.text:sub(utf8.offset(t.text, t.cursor + 2) - 1, utf8.offset(t.text, t.cursor + 2) - 1))
                t.cursor = t.cursor + 1
            end
        elseif k == "up" then
            if t.previous then t.scene.activate(t.previous) end
        elseif k == "down" then
            if t.next then t.scene.activate(t.next) end
        elseif k == "return" then
            t:action()
            if t.next then t.scene.activate(t.next) end
        end
    end,
    scrolled = function(t, x)
        t.scroll = t.scroll + x * t.scrollSpeed
    end
}
local inlineTextboxMt = {
    __index = function(t, k)
        if k == "text" then return ""
        elseif k == "alttext" then return ""
        elseif k == "cursor" then return #t.text
        elseif k == "cursorBlink" then return 0
        elseif k == "scroll" then return t.w - 2*t.style.shape.padding.x - (t.style.text.font:getWidth(t.encrypt(t.text)) + math.ceil(t.style.cursor.width/2))
        elseif k == "scrollSpeed" then return inlineScrollSpeed
        elseif k == "w" then return t.style.text.font:getWidth(t.text) + 2*t.style.shape.padding.x
        elseif k == "h" then return t.style.text.font:getHeight() + t.style.shape.padding.y * 2
        elseif k == "encrypt" then return emptyf
        elseif k == "action" then return emptyf
        else return inlineTextbox[k] end
    end
}

return {
    newTextButton = function(t)
        return setmetatable(t, textButtonMt)
    end,
    newInlineTextbox = function(t)
        return setmetatable(t, inlineTextboxMt)
    end,
    spaceOut = function(elems, direction, space, pivot, mode, spaceAround)
        space = space or 0
        pivot = pivot or 0
        mode = mode or "center"
        local pk, sk
        if direction == "x" then
            pk, sk = "x", "w"
        elseif direction == "y" then
            pk, sk = "y", "h"
        else return end
        local sum = space * (spaceAround and #elems + 1 or #elems - 1)
        for i, e in ipairs(elems) do
            sum = sum + e[sk]
        end
        local piv = pivot
        if mode == "start" then
            piv = piv
        elseif mode == "center" then
            piv = piv - sum/2
        elseif mode == "end" then
            piv = piv - sum
        else return end
        piv = spaceAround and piv + space or piv
        for i, e in ipairs(elems) do
            e[pk] = piv + e[sk]/2
            piv = piv + e[sk] + space
        end
    end,
    stretchOut = function(elems, direction, from, to, spaceAround)
        if not to then from, to = 0, from end
        local pk, sk
        if direction == "x" then
            pk, sk = "x", "w"
        elseif direction == "y" then
            pk, sk = "y", "h"
        else return end
        local sum = 0
        for i, e in ipairs(elems) do
            sum = sum + e[sk]
        end
        local space = (to - from - sum) / (spaceAround and #elems + 1 or #elems - 1)
        local piv = spaceAround and from + space or from
        for i, e in ipairs(elems) do
            e[pk] = piv + e[sk]/2
            piv = piv + e[sk] + space
        end
    end
}