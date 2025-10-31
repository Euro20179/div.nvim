local M = {}

function M.centerPad(text, size)
    if vim.fn.strwidth(text) >= size then
        return text
    end

    local needed = size - vim.fn.strwidth(text)
    local left = vim.fn.floor(needed / 2)
    local right = vim.fn.ceil(needed / 2)

    local final = ""
    for _ = 1, left do
        final = final .. ' '
    end

    final = final .. text

    for _ = 1, right do
        final = final .. ' '
    end

    return final
end

---@class div.boxify.Kwargs
---@field tl string?
---@field tr string?
---@field br string
---@field bl string?
---@field h string?
---@field v string?
---@field style ("b" | "d")?
---@field width string?
---@field height string?

---@param text string[]
---@param kwargs div.boxify.Kwargs
function M.boxify(text, kwargs)
    local height = #text - 2
    local lineCount = #text
    local width = vim.fn.strwidth(text[1])
    for _, line in ipairs(text) do
        if vim.fn.strwidth(line) > width then
            width = vim.fn.strwidth(line)
        end
    end

    local tl = kwargs.tl or "┌"
    local tr = kwargs.tr or "┐"
    local br = kwargs.br or "┘"
    local bl = kwargs.bl or "└"
    local h = kwargs.h or "─"
    local v = kwargs.v or "│"

    if kwargs.style then
        if kwargs.style == "b" then
            tl = "┏"
            tr = "┓"
            bl = "┗"
            br = "┛"
            h = "━"
            v = "┃"
        elseif kwargs.style == 'd' then
            tr = "╗"
            tl = "╔"
            br = "╝"
            bl = "╚"
            h = "═"
            v = "║"
        end
    end

    if kwargs.width ~= nil then
        local amount = kwargs.width or width

        if string.sub(amount, 1, 1) == "+" then
            width = width + (tonumber(string.sub(amount, 2))) * 2
            vim.print(width)
        else
            local n = tonumber(amount)
            if n and n > width then
                width = math.floor(n)
            end
        end
    end

    if kwargs.height ~= nil then
        local amount = kwargs.height or height

        if string.sub(amount, 1, 1) == "+" then
            height = height + (tonumber(string.sub(amount, 2))) * 2
        else
            local n = tonumber(amount)
            if n and n > height then
                height = math.floor(n)
            end
        end
    end

    local newText = {}

    -- top line {{{
    newText[1] = tl
    for i = 1, width do
        newText[1] = newText[1] .. h
    end
    newText[1] = newText[1] .. tr
    -- }}}

    -- top padding {{{
    for _ = 0, (height - lineCount) / 2 do
        local line = v .. M.centerPad(' ', width) .. v
        newText[#newText + 1] = line
    end
    -- }}}

    -- middle text {{{
    for _, line in ipairs(text) do
        line = v .. M.centerPad(line, width) .. v
        newText[#newText + 1] = line
    end
    -- }}}

    -- bottom padding {{{
    for _ = 0, (height - lineCount) / 2 do
        local line = v .. M.centerPad(' ', width) .. v
        newText[#newText + 1] = line
    end
    -- }}}

    -- bottom line {{{
    local last = #newText + 1
    newText[last] = bl
    for i = 1, width do
        newText[last] = newText[last] .. h
    end
    newText[last] = newText[last] .. br
    -- }}}

    return newText
end

---@param text string
---@param char string
---@param width integer
---@param instructions string[]
--- instructions minilang:
--- l   = left fill, with spaces, first char is {char}
--- r   = right fill, with spaces, last char is {char}
--- t   = text
--- L   = left fill with {char}
--- R   = right fill with {char}
--- F   = fill entire line with {char}
--- ' ' = fill width of {text} with spaces
--- example instruction set:
---     { "F", "ltr", "F"}
---     =
---     -----------
---     -   text  -
---     -----------
function M.draw(text, char, width, instructions)
    local charWidth = vim.fn.strwidth(char)

    local remainingLen = width - vim.fn.strwidth(text)

    local left = math.floor(remainingLen / 2)
    local right = math.ceil(remainingLen / 2)

    local leftFill = string.rep(char, left)
    local leftPlain = char .. string.rep(' ', left - charWidth)
    local rightFill = string.rep(char, right)
    local rightPlain = string.rep(' ', right - charWidth) .. char
    local spaceFill = string.rep(' ', vim.fn.strwidth(text))
    local charFull = string.rep(char, width / charWidth)

    local final = ""
    for _, line in pairs(instructions) do
        for i = 1, #line do
            local instruction = line:sub(i, i)
            if instruction == 'l' then
                final = final .. leftPlain
            elseif instruction == 'r' then
                final = final .. rightPlain
            elseif instruction == ' ' then
                final = final .. spaceFill
            elseif instruction == 'L' then
                final = final .. leftFill
            elseif instruction == 'R' then
                final = final .. rightFill
            elseif instruction == 't' then
                final = final .. text
            elseif instruction == 'F' then
                final = final .. charFull
            end
        end
        final = final .. '\n'
    end

    return final
end

---@class div.divword.Options
---@field char string?
---@field width integer?
---@field format ("auto" | "line" | "box" | "tb")?

---@param height integer
---@param text string
---@param options div.divword.Options
function M.divword(height, text, options)
    local char = options.char or '-'
    local width = options.width or 80


    local format = options.format
    local instructions = {}
    if format == nil or format == "auto" then
        if height == 1 then
            instructions[1] = "LtR"
        elseif height % 2 == 1 then
            local middle = math.floor(height / 2)
            for i = 1, height do
                if i == middle then
                    instructions[#instructions + 1] = 'ltr'
                else
                    instructions[#instructions + 1] = 'l r'
                end
            end
        else
            instructions[1] = 'LtR'
            for i = 1, height - 1 do
                instructions[#instructions + 1] = 'l r'
            end
            instructions[#instructions + 1] = 'LtR'
        end
    end

    return M.draw(text, char, width, instructions)
end

return M
