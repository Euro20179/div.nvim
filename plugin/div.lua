local divwFormatting = "auto"

vim.api.nvim_create_user_command("Divfw", function(data)
    divwFormatting = data.args
end, {
    nargs = 1,
    bar = true,
    range = true,
    complete = function()
        return { 'auto', 'box', 'tb', 'line' }
    end
})

local function centerPad(text, size)
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

local function falsey(val)
    if val == 0 or val == "" or val == nil then
        return true
    end
    return false
end

local function getScreenWidth()
    local width = vim.b.mmfml_textwidth
    if falsey(width) then
        width = vim.bo.textwidth
    end
    if falsey(width) then
        width = 80
    end
    return width
end

local function boxify(args)
    if args.range ~= 2 then
        vim.notify("A visual range must be selected", vim.log.levels.ERROR)
        return
    end

    local sl = vim.fn.line("'<") - 1
    local sc = vim.fn.col("'<") - 1
    local el = vim.fn.line("'>") - 1
    local ec = vim.fn.col("'>")

    local text = vim.api.nvim_buf_get_text(0, sl, sc, el, ec, {})

    local strip = false

    local height = #text - 2
    local lineCount = #text
    local width = vim.fn.strwidth(text[1])
    for _, line in ipairs(text) do
        if vim.fn.strwidth(line) > width then
            width = vim.fn.strwidth(line)
        end
    end

    local tl = "┌"
    local tr = "┐"
    local br = "┘"
    local bl = "└"
    local h = "─"
    local v = "│"

    local fargs = args.fargs

    if fargs[1] == "b" then
        tl = "┏"
        tr = "┓"
        bl = "┗"
        br = "┛"
        h = "━"
        v = "┃"
    elseif fargs[1] == "d" then
        tr = "╗"
        tl = "╔"
        br = "╝"
        bl = "╚"
        h = "═"
        v = "║"
    end

    for _, kwarg in pairs(fargs) do
        if vim.startswith(kwarg, "h=") then
            h = string.sub(kwarg, 3)
        elseif vim.startswith(kwarg, "v=") then
            v = string.sub(kwarg, 3)
        elseif vim.startswith(kwarg, "tl=") then
            v = string.sub(kwarg, 4)
        elseif vim.startswith(kwarg, "tr=") then
            v = string.sub(kwarg, 4)
        elseif vim.startswith(kwarg, "br=") then
            v = string.sub(kwarg, 4)
        elseif vim.startswith(kwarg, "bl=") then
            v = string.sub(kwarg, 4)
        elseif vim.startswith(kwarg, "width=") then
            local amount = string.sub(kwarg, 7)

            if string.sub(amount, 1, 1) == "+" then
                width = width + (tonumber(string.sub(amount, 2))) * 2
                vim.print(width)
            else
                local n = tonumber(amount)
                if n and n > width then
                    width = math.floor(n)
                end
            end
        elseif vim.startswith(kwarg, "height=") then
            local amount = string.sub(kwarg, 7)

            if string.sub(amount, 1, 1) == "+" then
                height = height + (tonumber(string.sub(amount, 2))) * 2
            else
                local n = tonumber(amount)
                if n and n > height then
                    height = math.floor(n)
                end
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
        local line = v .. centerPad(' ', width) .. v
        newText[#newText + 1] = line
    end
    -- }}}

    -- middle text {{{
    for _, line in ipairs(text) do
        line = v .. centerPad(line, width) .. v
        newText[#newText + 1] = line
    end
    -- }}}

    -- bottom padding {{{
    for _ = 0, (height - lineCount) / 2 do
        local line = v .. centerPad(' ', width) .. v
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

    vim.api.nvim_buf_set_text(0, sl, sc, el, ec - 1, newText)
end

vim.api.nvim_create_user_command("Boxify", boxify, { range = true, nargs = "?" })

---@param data vim.api.keyset.create_user_command.command_args
local function getStartEndLines(data)
    local line = vim.fn.line(".")
    local endLine = vim.fn.line(".")
    if data.line1 > 0 then
        line = data.line1
    end
    if data.line2 > 0 then
        endLine = data.line2
    end

    if line > endLine then
        local temp = endLine
        endLine    = line
        line       = temp
    end


    return line, endLine
end

vim.api.nvim_create_user_command("Divline", function(cmdData)
    local endCol = getScreenWidth()

    local width = endCol
    if #cmdData.fargs == 2 then
        width = tonumber(cmdData.fargs[2]) or width
    end

    local line, endLine = getStartEndLines(cmdData)

    local lineText = vim.fn.getline(line)
    if not cmdData.bang and lineText ~= "" then
        vim.notify(string.format("line %d is not empty, use ! to replace", line))
        return
    end

    local char = "-"
    if #cmdData.fargs > 0 then
        char = cmdData.fargs[1]
    end

    width = width / vim.fn.strwidth(char)

    for i = line, endLine do
        vim.fn.setline(i, string.rep(char, width))
    end
end, { addr = "lines", bang = true, nargs = "*" })

local function divword(cmdData)
    local endCol = getScreenWidth()

    local width = endCol
    if #cmdData.fargs > 2 then
        width = tonumber(cmdData.fargs[3]) or endCol
    end

    local startLine, endLine = getStartEndLines(cmdData)

    local lineText = vim.fn.trim(vim.fn.getline(startLine))
    if not cmdData.bang and lineText ~= "" then
        vim.notify(string.format("line %d is not empty, use ! to replace", startLine))
        return
    end

    if #cmdData.fargs > 1 then
        lineText = cmdData.fargs[2]
    end

    local char = "-"
    if #cmdData.fargs > 0 then
        char = cmdData.fargs[1]
    end

    local charWidth = vim.fn.strwidth(char)

    local remainingLen = width - vim.fn.strwidth(lineText)

    local left = math.floor(remainingLen / 2)
    local right = remainingLen - left

    local finalText = string.format(
        "%s%s%s",
        string.rep(char, left),
        lineText,
        string.rep(char, right)
    )

    local emptyLine = string.format(
        "%s%s%s",
        char,
        string.rep(' ', width - charWidth * 2),
        char
    )

    -- one line
    if divwFormatting == "line" or endLine - startLine == 0 then
        for i = startLine, endLine do
            vim.fn.setline(i, finalText)
        end
        -- odd lines
    elseif divwFormatting == "box" or (endLine - startLine + 1) % 2 == 1 and (endLine - startLine) > 0 then
        local middle = math.floor((endLine + startLine) / 2)

        finalText = string.format(
            "%s%s%s%s%s",
            char,
            string.rep(' ', left - 1),
            lineText,
            string.rep(' ', right - 1),
            char
        )

        vim.fn.setline(startLine, string.rep(char, width))
        for i = startLine + 1, middle do
            vim.fn.setline(i, emptyLine)
        end

        vim.fn.setline(middle, finalText)

        for i = middle + 1, endLine - 1 do
            vim.fn.setline(i, emptyLine)
        end

        vim.fn.setline(endLine, string.rep(char, width))
        -- even lines
    elseif divwFormatting == "tb" or (endLine - startLine + 1) % 2 == 0 then
        vim.fn.setline(startLine, finalText)
        for i = startLine + 1, endLine - 1 do
            vim.fn.setline(i, emptyLine)
        end
        vim.fn.setline(endLine, finalText)
    end
end

vim.api.nvim_create_user_command("Divword", divword, { addr = 'lines', bang = true, nargs = "*" })

vim.api.nvim_create_user_command("Divbox", function(cmdData)
    vim.cmd[[
        exec "norm V:Boxify\<CR>"
        norm k
        .,+2cen
        norm j
        Divw! ─
        norm 0f│r┤f│r├
    ]]
end, {})
