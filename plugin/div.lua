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
    local width = vim.b.mmfml_textwidth
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
    local box = div.boxify(text, kwargs2tbl(cmdData.fargs))
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
        vim.api.nvim_buf_set_lines(0, i - 1, endLine, false, {fullLine})
    end
end, { addr = "lines", bang = true, nargs = "*" })

local function divword(cmdData)
    local char, lineText, line, endLine, width = parseDivwlData(cmdData, 1, 2)
    if width == 0 then return end

    if #cmdData.fargs > 1 then
        lineText = cmdData.fargs[2]
    end

    local text = div.divword(endLine - line + 1, lineText, {
        char = char,
        format = divwFormatting,
        width = width
    })

    vim.api.nvim_buf_set_lines(0, line - 1, endLine, false, vim.split(text, '\n'))
end

vim.api.nvim_create_user_command("Divword", divword, { addr = 'lines', bang = true, nargs = "*" })

vim.api.nvim_create_user_command("Divbox", function()
    vim.cmd [[
        Boxify
        norm j
        Divw! ─
        norm 0f│r┤f│r├
        -1,+1cen
    ]]
end, {})
