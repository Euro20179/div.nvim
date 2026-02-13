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
---@field a string?
---@field style ("b" | "d" | "l")?
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

    local tl = kwargs.tl or kwargs.a or "┌"
    local tr = kwargs.tr or kwargs.a or "┐"
    local br = kwargs.br or kwargs.a or "┘"
    local bl = kwargs.bl or kwargs.a or "└"
    local h = kwargs.h or kwargs.a or "─"
    local v = kwargs.v or kwargs.a or "│"

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
        elseif kwargs.style == "l" then
            tr = "┐"
            tl = "┌"
            br = "┘"
            bl = "└"
            h = "─"
            v = "│"
        end
    end

    if kwargs.width ~= nil then
        local amount = kwargs.width or width

        if string.sub(amount, 1, 1) == "+" then
            width = width + (tonumber(string.sub(amount, 2))) * 2
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


    local format = options.format or "auto"
    local instructions = {}
    if format == "auto" then
        if height == 1 then
            format = "line"
        elseif height % 2 == 1 then
            format = "box"
        else
            format = "tb"
        end
    end

    if format == "line" then
        instructions[1] = "LtR"
    elseif format == "box" then
        local middle = math.floor(height / 2)
        if height == 1 then
            instructions[1] = 'ltr'
        else
            for i = 1, height do
                if i == middle then
                    instructions[#instructions + 1] = 'ltr'
                else
                    instructions[#instructions + 1] = 'l r'
                end
            end
        end
    elseif format == "tb" then
        instructions[1] = 'LtR'
        for _ = 1, height - 1 do
            instructions[#instructions + 1] = 'l r'
        end
        instructions[#instructions + 1] = 'LtR'
    end

    return M.draw(text, char, width, instructions):sub(0, -2)
end

---@class div.tableofcontents.Options
---@field char string? the char to use as the separator
---@field dotPadding integer?
---@field descAlign ("left" | "right")?

---@param lines string[]
---@param options div.tableofcontents.Options
function M.tableofconents(lines, options)
    local tocLines = {}

    local maxLabelWidth = 0
    local maxRestWidth = 0
    for _, line in pairs(lines) do
        if vim.fn.trim(line) == "" then
            tocLines[#tocLines + 1] = ""
            goto continue
        end
        --find the first non-leading space because otherwise it will match
        --the leading space and mess up the dots
        local firstNonLeadingSpace = line:find("[^%s]%s") + 1
        local label = line:sub(0, firstNonLeadingSpace - 1)
        local rest = line:sub(firstNonLeadingSpace + 1)

        rest = rest:gsub("%.+ ", "")
        tocLines[#tocLines + 1] = { label, rest }

        local w = vim.fn.strwidth(label)
        if w > maxLabelWidth then
            maxLabelWidth = w
        end

        w = vim.fn.strwidth(rest)
        if w > maxRestWidth then
            maxRestWidth = w
        end

        ::continue::
    end

    --enough for options.dotPadding dots + 2 spaces
    local extraSpace = 2 + (options.dotPadding or 2)
    maxLabelWidth = maxLabelWidth + extraSpace

    local dalign = options.descAlign or "left"

    local final = {}
    for _, line in pairs(tocLines) do
        if line == "" then
            final[#final + 1] = ""
            goto continue
        end

        local label = line[1]
        local rest = line[2]
        local labelW = vim.fn.strwidth(label)

        if dalign ~= "left" then
            --left pad the rest so that every line is the same width
            --so that the block can be cenetered nicer
            rest = string.rep(' ', maxRestWidth - vim.fn.strwidth(rest)) .. rest
        end

        final[#final + 1] = string.format(
            "%s %s %s",
            -- -2 for spaces
            label, string.rep(".", maxLabelWidth - labelW - 2),
            rest
        )

        ::continue::
    end

    return final
end

---Aligns tabled data with a column of {column}
---Each column can have a max width of {maxwidth}
---The width of each column is determined by:
---   min(maxColumnWidth, maxWidth)
---   where maxColumnWidth is the longest line in the column
---the total width of the table may exceed 'textwidth'
---@param text string
---@param column string - the column separator
---@param maxWidth integer? - the maxwidth of any given column
function M.table(text, column, maxWidth)
    local lines = vim.split(text, "\n")

    local columns = {}

    for i, _ in ipairs(vim.split(lines[1], column)) do
        columns[i] = {}
    end

    local columnCount = #columns

    -- first, remap lines into a list of columns
    for linenr, line in ipairs(lines) do
        vim.iter(
            vim.split(line, column)
        )
            :map(vim.fn.trim)
            :enumerate()
            -- this map function creates columns
            -- and determines the amount of columns
            :map(function(i, v)
                if i > columnCount then
                    columns[i] = {}
                    for _ = 1, linenr - 1 do
                        columns[i][#columns[i] + 1] = " "
                    end
                    columnCount = i
                end
                columns[i][#columns[i] + 1] = v
            end)
            :totable()
    end

    -- next determine the longest row in each column
    local longestColumns = {}
    for i = 1, columnCount do
        local longest = 0
        for _, c in pairs(columns[i]) do
            if vim.fn.strwidth(c) > longest then
                longest = vim.fn.strwidth(c)
            end
        end
        -- +1 is padding
        longestColumns[i] = longest + 1
    end

    -- set the max width
    local tw = vim.o.textwidth
    if tw == 0 then
        tw = 80
    end
    local maxColumnWidth = (maxWidth or math.floor(tw / #columns))

    -- if a column is entirely `-`, `=` or `─` then the user probably wants
    -- that column to be that wide, no exceptions
    for i = 1, columnCount do
        for j = 1, #columns[i] do
            if columns[i][j]:match("^[-=─]+$") then
                local w = vim.fn.strwidth(columns[i][j])
                if w > maxColumnWidth then
                    maxColumnWidth = w
                end
            end
        end
    end


    local out = {}
    local newCols = {}

    local extraLines = 0

    for linenr = 1, #lines do
        for colNr, c in pairs(columns) do
            local columnLen = math.min(longestColumns[colNr], maxColumnWidth)
            local colText = c[linenr]

            local col = newCols[colNr]

            if col == nil then
                col = {}
                newCols[colNr] = col
            end

            -- if the column is currently too wide, text wrap it
            -- nextLines will contain, well... the next lines
            local nextLines = {}
            while vim.fn.strwidth(colText) > columnLen do
                nextLines[#nextLines + 1] = colText:sub(string.len(colText) - columnLen + 1)
                colText = colText:sub(1, vim.fn.strwidth(colText) - columnLen)
            end

            -- the while loop creates it backwards
            nextLines = vim.iter(nextLines):rev():totable()

            col[linenr + extraLines] = colText

            if #nextLines > 0 then
                for i = 1, #nextLines do
                    col[linenr + extraLines + i] = nextLines[i]
                end
                extraLines = extraLines + #nextLines
            end
        end
    end

    for linenr = 1, #lines + extraLines do
        local line = ""

        -- format each column in linenr
        for colnr, col in ipairs(newCols) do
            local columnLen = math.min(longestColumns[colnr], maxColumnWidth)

            line = line .. string.format("%-" .. tostring(columnLen) .. "s", col[linenr] or " ") .. column .. ' '
        end

        line = line:gsub("%s+$", "")

        while vim.endswith(line, column) do
            line = line:sub(0, vim.fn.strwidth(line) - vim.fn.strwidth(column)):gsub("%s+$", "")
        end

        if not line:match(column) then
            -- we can use longestColumns[1] as the longest column because if
            -- column is not in line, then that means there is only 1 column in
            -- the line (the first column)
            line = string.format("%-" .. tostring(math.min(longestColumns[1], maxColumnWidth)) .. "s", line) .. column

            for i = 2, columnCount - 1 do
                line = line .. string.format("%-" .. tostring(math.min(longestColumns[i], maxColumnWidth) + 1) .. "s", ' ') .. column
            end
        end

        out[#out + 1] = line
    end

    return out
end

return M
