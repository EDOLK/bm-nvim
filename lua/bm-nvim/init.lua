local M = {}

local bmdir = vim.env.HOME .. "\\.config\\nvim\\.bookmarks\\"

local dir = ""

local dirName = ""

---@class bookmark
---@field path string
---@field row number
---@field col number
---@field global boolean
---@field name string

---@type bookmark[]
local bookmark_cache = {}

---@type table<bookmark,integer>
local virt_text_marks = {}

local ns_id = nil

---@param info bookmark
local function appendCache(info)
    bookmark_cache[#bookmark_cache+1] = info;
end

local function split(inputstr, sep)
    sep = sep or "%s"
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

---@param path string
---@return integer|nil
local function getBufId(path)
    local bufIds = vim.api.nvim_list_bufs()
    for _, bufId in ipairs(bufIds) do
        if path == vim.api.nvim_buf_get_name(bufId) then
            return bufId
        end
    end
    return nil
end

---@param bufId integer
---@return string
local function getPath(bufId)
    return vim.api.nvim_buf_get_name(bufId)
end

---@param str string
---@return bookmark
local function convertToBookmark(str)
    local strs = split(str, ",")
    return {
        path = strs[1],
        row = tonumber(strs[2]),
        col = tonumber(strs[3]),
        global = (strs[4] == tostring(1)),
        name = strs[5],
    }
end

---@param bkm bookmark
---@return string
local function convertToString(bkm)
    local global = "0"
    if bkm.global then
        global = "1"
    end
    return bkm.path .. "," .. tostring(bkm.row) .. "," .. tostring(bkm.col) .. "," .. global .. "," .. bkm.name
end

---@param file file*
---@param info bookmark[]
local function write(file, info)
    for _, value in ipairs(info) do
        file:write(convertToString(value), "\n")
    end
    file:flush()
    file:close()
end

---@param dr string
---@param info bookmark[]?
local function writeIntoFile(dr, info)
    if io.open(dr,"r") ~= nil then
        local file = io.open(dr, "w")
        if file ~= nil and info ~= nil then
            write(file,info)
        end
    elseif info ~= nil and #info ~= 0 then
        local file = io.open(dr, "w")
        if file ~= nil then
            write(file,info)
        end
    end
end

local function readIntoCache(dr)
    bookmark_cache = {}
    local file = io.open(dr, "r")
    if file ~= nil then
        while true do
            local line = file:read()
            if line == nil then break end
            appendCache(convertToBookmark(line))
        end
    end
end

---@param bookmark bookmark
local function renderBookmark(bookmark)
    ---@type vim.api.keyset.set_extmark
    local opts = {
        virt_text = {{bookmark.name, "IncSearch"}},
        virt_text_pos = 'eol',

    }
    if ns_id ~= nil then
        if virt_text_marks[bookmark] == nil then
            local bufId = getBufId(bookmark.path)
            if bufId ~= nil then
                virt_text_marks[bookmark] = vim.api.nvim_buf_set_extmark(bufId, ns_id, bookmark.row-1, bookmark.col, opts)
            end
        end
    end
end

---@param bookmark bookmark
local function deRenderBookmark(bookmark)
    local virtMark = virt_text_marks[bookmark]
    if ns_id ~= nil and virtMark ~= nil then
        local bufId = getBufId(bookmark.path)
        if bufId ~= nil then
            vim.api.nvim_buf_del_extmark(bufId,ns_id,virtMark)
        end
    end
    virt_text_marks[bookmark] = nil
end

local function renderBookmarksForBuffer(bufId)
    for _, value in ipairs(bookmark_cache) do
        local foundBufId = getBufId(value.path)
        if foundBufId == bufId then
            renderBookmark(value)
        end
    end
end

local function deRenderBookmarksForBuffer(bufId)
    for _, value in ipairs(bookmark_cache) do
        local foundBufId = getBufId(value.path)
        if foundBufId == bufId then
            deRenderBookmark(value)
        end
    end
end

local function setupAutocmds()
    local group = vim.api.nvim_create_augroup("bm",{clear = false})
    vim.api.nvim_create_autocmd("SessionLoadPost", {
        pattern = {"*"},
        callback = function (args)
            dir = vim.v.this_session
            dirName = vim.fn.fnamemodify(dir, ":t:r")
            readIntoCache(bmdir .. dirName)
            ns_id = vim.api.nvim_create_namespace("")
            renderBookmarksForBuffer(args.buf)
        end,
        group = group,
    })
    vim.api.nvim_create_autocmd({"SessionWritePost","VimLeavePre"}, {
        pattern = {"*"},
        callback = function ()
            writeIntoFile(bmdir .. dirName, bookmark_cache)
        end,
        group = group,
    })
    vim.api.nvim_create_autocmd({"BufWinEnter"}, {
        pattern = {"*"},
        callback = function (args)
            renderBookmarksForBuffer(args.buf)
        end,
        group = group,
    })
    vim.api.nvim_create_autocmd({"BufWinLeave"}, {
        pattern = {"*"},
        callback = function (args)
            deRenderBookmarksForBuffer(args.buf)
        end,
        group = group,
    })
end

function M.setup(args)
    if args.enabled then
        bmdir = args.bookmark_directory or bmdir
        setupAutocmds()
    end
end

function M.localBookmark()
    local pos = vim.api.nvim_win_get_cursor(0)

    vim.ui.input({prompt = "Bookmark"}, function (input)
        if input ~= nil then
            ---@type bookmark
            local new_bookmark = {
                path = getPath(vim.api.nvim_get_current_buf()),
                row = pos[1],
                col = pos[2],
                global = false,
                name = input
            }
            appendCache(new_bookmark)
            renderBookmark(new_bookmark)
            vim.notify("Bookmark " .. new_bookmark.name .. " created.", vim.log.levels.INFO)
        end
    end)
end

function M.globalBookmark()
    local pos = vim.api.nvim_win_get_cursor(0)

    vim.ui.input({prompt = "Bookmark"}, function (input)
        if input ~= nil then
            ---@type bookmark
            local new_bookmark = {
                path = getPath(vim.api.nvim_get_current_buf()),
                row = pos[1],
                col = pos[2],
                global = true,
                name = input
            }
            appendCache(new_bookmark)
            renderBookmark(new_bookmark)
            vim.notify("Bookmark " .. new_bookmark.name .. " created.", vim.log.levels.INFO)
        end
    end)
end

function M.deleteBookmark()
    local pos = vim.api.nvim_win_get_cursor(0)
    for i = #bookmark_cache, 1, -1 do
        local bookmark = bookmark_cache[i]
        local bufId = getBufId(bookmark.path)
        if bookmark.row == pos[1] and bufId == vim.api.nvim_get_current_buf() then
            deRenderBookmark(bookmark)
            table.remove(bookmark_cache,i)
            vim.notify("Bookmark " .. bookmark.name .. " removed.", vim.log.levels.INFO)
        end
    end
end

function M.selectLocalBookmarks()
    local localBookmarks = {}
    local bufId = vim.api.nvim_get_current_buf()
    for _, value in ipairs(bookmark_cache) do
        local bId = getBufId(value.path)
        if bId == bufId then
            localBookmarks[#localBookmarks+1] = value
        end
    end
    if #localBookmarks ~= 0 then
        vim.ui.select(localBookmarks,{
            prompt = "local bookmarks",
            format_item = function (bm)
                return bm.name
            end
        }, function (bm)
            if bm == nil then
                return
            end
            vim.api.nvim_win_set_cursor(0,{bm.row,bm.col})
        end)
        return
    end
    vim.notify("No local bookmarks found", vim.log.levels.ERROR)
end

function M.selectGlobalBookmarks()
    ---@type bookmark[]
    local globalBookmarks = {}
    for _, value in ipairs(bookmark_cache) do
        if value.global == true then
            globalBookmarks[#globalBookmarks+1] = value
        end
    end
    if #globalBookmarks ~= 0 then
        vim.ui.select(globalBookmarks,{
            prompt = "global bookmarks",
            ---@param bm bookmark
            format_item = function (bm)
                return bm.name
            end
            ---@param bm bookmark
        }, function (bm)
            if bm == nil then
                return
            end
            local bufId = getBufId(bm.path)
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == bufId then
                    vim.api.nvim_set_current_win(win)
                    vim.api.nvim_win_set_cursor(win,{bm.row,bm.col})
                    return
                end
            end
            if bufId ~= nil and vim.api.nvim_buf_is_loaded(bufId) then
                vim.api.nvim_set_current_buf(bufId)
                vim.api.nvim_win_set_cursor(0,{bm.row,bm.col})
                return
            end
            if io.open(bm.path,"r") ~= nil then
                vim.cmd('e ' .. bm.path)
                vim.api.nvim_win_set_cursor(0,{bm.row,bm.col})
            end
            vim.notify("File not found", vim.log.levels.ERROR)
        end)
        return
    end
    vim.notify("No global bookmarks found", vim.log.levels.ERROR)
end

function M.selectBookmarks()
    local bookmarks = {}
    for _, value in ipairs(bookmark_cache) do
        if getBufId(value.path) == vim.api.nvim_get_current_buf() or value.global then
            bookmarks[#bookmarks+1] = value
        end
    end
    if #bookmarks ~= 0 then
        vim.ui.select(bookmarks,{
            prompt = "bookmarks",
            format_item = function (bm)
                return bm.name
            end
        }, function (bm)
            if bm == nil then
                return
            end
            local bufId = getBufId(bm.path)
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == bufId then
                    vim.api.nvim_set_current_win(win)
                    vim.api.nvim_win_set_cursor(win,{bm.row,bm.col})
                    return
                end
            end
            if bufId ~= nil and vim.api.nvim_buf_is_loaded(bufId) then
                vim.api.nvim_set_current_buf(bufId)
                vim.api.nvim_win_set_cursor(0,{bm.row,bm.col})
                return
            end
            if io.open(bm.path,"r") ~= nil then
                vim.cmd('e ' .. bm.path)
                vim.api.nvim_win_set_cursor(0,{bm.row,bm.col})
            end
            vim.notify("File not found", vim.log.levels.ERROR)
        end)
        return
    end
    vim.notify("No bookmarks found", vim.log.levels.ERROR)
end

---@return bookmark[]
function M.getBookmarks()
    return bookmark_cache
end

return M
