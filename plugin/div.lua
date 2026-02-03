local div = require "div"

local divwFormatting = "auto"

---@param kwargs string[]
local function kwargs2tbl(kwargs)
    local tbl = {}
    for _, kwarg in ipairs(kwargs) do
        if not kwarg:match("=") then
            goto continue
        end

        local eq = kwarg:find("=")
        local key = kwarg:sub(1, eq - 1)
        local value = kwarg:sub(eq + 1)

        tbl[key] = value

        ::continue::
    end
    return tbl
end

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

local function falsey(val)
    if val == 0 or val == "" or val == nil then
        return true
    end
    return false
end

local function getScreenWidth()
    local width = vim.b.div_textwidth or vim.b.mmfml_textwidth
    if falsey(width) then
        width = vim.bo.textwidth
    end
    if falsey(width) then
        width = 80
    end
    return width
end

vim.api.nvim_create_user_command("Boxify", function(cmdData)
    local text = vim.api.nvim_buf_get_lines(0, cmdData.line1 - 1, cmdData.line2, false)
    local style = "auto"
    if cmdData.fargs[1] and not cmdData.fargs[1]:match("=") then
        style = cmdData.fargs[1]
        cmdData.fargs = vim.fn.slice(cmdData.fargs, 1)
    end
    local tbl = kwargs2tbl(cmdData.fargs)
    tbl["style"] = style
    local box = div.boxify(text, tbl)
    vim.api.nvim_buf_set_lines(0, cmdData.line1 - 1, cmdData.line2, false, box)
end, { range = true, nargs = "*" })

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

---@return string, string, integer, integer, integer
local function parseDivwlData(cmdData, charPos, widthPos)
    local endCol = getScreenWidth()

    local width = endCol
    if #cmdData.fargs == 2 then
        width = tonumber(cmdData.fargs[widthPos]) or width
    end

    local line, endLine = getStartEndLines(cmdData)

    local lineText = vim.fn.getline(line)
    if not cmdData.bang and lineText ~= "" then
        vim.notify(string.format("line %d is not empty, use ! to replace", line))
        return "", "", 0, 0, 0
    end

    local char = "-"
    if #cmdData.fargs > 0 then
        char = cmdData.fargs[charPos]
    end

    return char, lineText, line, endLine, width
end

vim.api.nvim_create_user_command("Divline", function(cmdData)
    local char, lineText, line, endLine, width = parseDivwlData(cmdData, 1, 2)
    if width == 0 then return end

    width = width / vim.fn.strwidth(char)

    local fullLine = char:rep(width)
    for i = line, endLine do
        vim.api.nvim_buf_set_lines(0, i - 1, endLine, false, { fullLine })
    end
end, { addr = "lines", bang = true, nargs = "*" })

local function divword(cmdData)
    local char, lineText, line, endLine, width = parseDivwlData(cmdData, 1, 2)
    if width == 0 then return end

    if #cmdData.fargs > 1 and cmdData.fargs[2] ~= "." then
        lineText = cmdData.fargs[2]
    end

    local formatting = divwFormatting

    if #cmdData.fargs > 2 then
        local kwargs = kwargs2tbl(vim.fn.slice(cmdData.fargs, 2))
        if kwargs["width"] ~= nil then
            width = tonumber(kwargs["width"]) or width
        elseif kwargs["s"] ~= nil then
            formatting = kwargs["s"]
        end
    end

    local text = div.divword(endLine - line + 1, lineText, {
        char = char,
        format = formatting,
        width = width
    })

    vim.api.nvim_buf_set_lines(0, line - 1, endLine, false, vim.split(text, '\n'))
end

vim.api.nvim_create_user_command("Divword", divword, { addr = 'lines', bang = true, nargs = "*" })

vim.api.nvim_create_user_command("Divbox", function()
    vim.cmd [[
        Boxify
        +1Divw! ─
        "this moves the cursor
        +1norm 0f│r┤f│r├
        -1,+1cen
    ]]
end, {})

vim.api.nvim_create_user_command("Toc", function(cmdData)
    local lines = vim.api.nvim_buf_get_lines(0, cmdData.line1 - 1, cmdData.line2, false)

    local kwargs = kwargs2tbl(cmdData.fargs)

    local dotP = getScreenWidth() / 2
    if kwargs.dotp ~= nil then
        dotP = tonumber(kwargs.dotp) or dotP
    end

    local text = div.tableofconents(lines, {
        dotPadding = dotP,
        descAlign = kwargs.dalign or "left"
    })

    vim.api.nvim_buf_set_lines(0, cmdData.line1 - 1, cmdData.line2, false, text)
end, { range = true, nargs = "*" })

vim.api.nvim_create_user_command("Table", function(cmdData)
    local colDelimiter = cmdData.fargs[1]

    local start = cmdData.line1
    local end_ = cmdData.line2

    if cmdData.range < 1 then
        while start > 1 and vim.fn.getline(start - 1):match(colDelimiter) ~= nil do
            start = start - 1
        end

        local buflinecnt = vim.api.nvim_buf_line_count(0)

        while end_ < buflinecnt and vim.fn.getline(end_ + 1):match(colDelimiter) ~= nil do
            end_ = end_ + 1
        end
    end

    local text = table.concat(vim.api.nvim_buf_get_lines(0, start - 1, end_, false), "\n")

    local textLines = div.table(text, colDelimiter)

    vim.api.nvim_buf_set_lines(0, start - 1, end_, false, textLines)
end, { range = true, nargs = 1 })
