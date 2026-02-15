local COLOR = {
    headingH1 = "ffedd39a",
    headingH2 = "ffe6d0a2",
    headingH3 = "ffd8d8b0",
    inlineCode = "ff8ebfe9",
    tableHeader = "ffe0d8c4",
    tableValue = "ff9bb6cf",
    codeLabel = "ffb6c6d8",
    codeBlock = "ff9bb6cf",
}

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local content = assert(file:read("*a"))
    file:close()
    return content
end

local function writeFile(path, content)
    local file = assert(io.open(path, "wb"))
    assert(file:write(content))
    file:close()
end

local function trim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function splitLines(text)
    local lines = {}
    text = text .. "\n"
    for line in string.gmatch(text, "(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function formatInlineCode(text)
    return (string.gsub(text, "`([^`]+)`", "|c" .. COLOR.inlineCode .. "%1|r"))
end

local function formatHeading(line)
    local h1 = string.match(line, "^#%s+(.+)$")
    if h1 then
        return "|c" .. COLOR.headingH1 .. formatInlineCode(h1) .. "|r"
    end

    local h2 = string.match(line, "^##%s+(.+)$")
    if h2 then
        return "|c" .. COLOR.headingH2 .. formatInlineCode(h2) .. "|r"
    end

    local h3 = string.match(line, "^###%s+(.+)$")
    if h3 then
        return "|c" .. COLOR.headingH3 .. formatInlineCode(h3) .. "|r"
    end

    return nil
end

local function parseMarkdownTableRow(line)
    local row = {}
    local body = string.gsub(line, "^|", "")
    body = string.gsub(body, "|$", "")
    local start = 1
    while true do
        local separator = string.find(body, "|", start, true)
        if not separator then
            table.insert(row, trim(string.sub(body, start)))
            break
        end
        table.insert(row, trim(string.sub(body, start, separator - 1)))
        start = separator + 1
    end
    return row
end

local function isTableSeparatorLine(line)
    local trimmed = trim(line)
    if string.sub(trimmed, 1, 1) ~= "|" then
        return false
    end
    local cells = parseMarkdownTableRow(trimmed)
    if #cells < 2 then
        return false
    end
    for _, cell in ipairs(cells) do
        if not string.match(cell, "^:?-+:?$") then
            return false
        end
    end
    return true
end

local function formatMarkdownTable(lines, startIndex)
    local headerLine = lines[startIndex]
    local separatorLine = lines[startIndex + 1]
    if not headerLine or not separatorLine then
        return nil, startIndex
    end
    if string.sub(trim(headerLine), 1, 1) ~= "|" then
        return nil, startIndex
    end
    if not isTableSeparatorLine(separatorLine) then
        return nil, startIndex
    end

    local headers = parseMarkdownTableRow(headerLine)
    local out = {}
    if #headers == 2 then
        table.insert(out, "|c" .. COLOR.tableHeader .. formatInlineCode(headers[1]) .. " / " .. formatInlineCode(headers[2]) .. "|r")
    else
        table.insert(out, "|c" .. COLOR.tableHeader .. formatInlineCode(table.concat(headers, " | ")) .. "|r")
    end

    local index = startIndex + 2
    while lines[index] and string.sub(trim(lines[index]), 1, 1) == "|" do
        local row = parseMarkdownTableRow(lines[index])
        if #headers == 2 and #row >= 2 then
            table.insert(out, "• " .. formatInlineCode(row[1]) .. ": |c" .. COLOR.tableValue .. formatInlineCode(row[2]) .. "|r")
        else
            table.insert(out, "• " .. formatInlineCode(table.concat(row, " | ")))
        end
        index = index + 1
    end

    table.insert(out, "")
    return out, index - 1
end

local function formatMarkdownToWowText(text)
    local lines = splitLines(text)
    local out = {}
    local inCodeBlock = false
    local index = 1

    while index <= #lines do
        local line = lines[index]
        local trimmed = trim(line)

        if string.match(trimmed, "^```") then
            inCodeBlock = not inCodeBlock
            if inCodeBlock then
                table.insert(out, "|c" .. COLOR.codeLabel .. "Code|r")
            else
                table.insert(out, "")
            end
            index = index + 1
        else
            local tableLines, nextIndex = formatMarkdownTable(lines, index)
            if tableLines then
                for _, tableLine in ipairs(tableLines) do
                    table.insert(out, tableLine)
                end
                index = nextIndex + 1
            elseif inCodeBlock then
                table.insert(out, "|c" .. COLOR.codeBlock .. line .. "|r")
                index = index + 1
            else
                if string.sub(trimmed, 1, 1) == "|" then
                    if not isTableSeparatorLine(trimmed) then
                        local row = parseMarkdownTableRow(trimmed)
                        if #row == 2 then
                            table.insert(out, "• " .. formatInlineCode(row[1]) .. ": |c" .. COLOR.tableValue .. formatInlineCode(row[2]) .. "|r")
                        else
                            table.insert(out, "• " .. formatInlineCode(table.concat(row, " | ")))
                        end
                    end
                    index = index + 1
                else
                    local heading = formatHeading(line)
                    if heading then
                        table.insert(out, heading)
                    else
                        local bulletText = string.match(line, "^%s*%-%s+(.+)$")
                        if bulletText then
                            table.insert(out, "• " .. formatInlineCode(bulletText))
                        else
                            table.insert(out, formatInlineCode(line))
                        end
                    end
                    index = index + 1
                end
            end
        end
    end

    return table.concat(out, "\n")
end

local function chooseLongBracketLevel(text)
    local level = 0
    while true do
        local equals = string.rep("=", level)
        local closeToken = "]" .. equals .. "]"
        if not string.find(text, closeToken, 1, true) then
            return level
        end
        level = level + 1
    end
end

local function buildOutput(text)
    local level = chooseLongBracketLevel(text)
    local equals = string.rep("=", level)
    local openToken = "[" .. equals .. "["
    local closeToken = "]" .. equals .. "]"

    return table.concat({
        "local addonName, AddonNS = ...",
        "AddonNS.QueryHelpDocs = AddonNS.QueryHelpDocs or {}",
        "AddonNS.QueryHelpDocs.text = " .. openToken,
        text,
        closeToken,
        "",
    }, "\n")
end

local inputPath = "QUERY_ATTRIBUTES.md"
local outputPath = "generated/queryHelpDocs.lua"

local markdownText = readFile(inputPath)
markdownText = string.gsub(markdownText, "\r\n", "\n")
local formattedText = formatMarkdownToWowText(markdownText)

local output = buildOutput(formattedText)
writeFile(outputPath, output)

print("generated " .. outputPath .. " from " .. inputPath)
