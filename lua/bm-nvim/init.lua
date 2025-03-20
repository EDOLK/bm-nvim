local M = {}

local sqlite = require("sqlite.db")
local uri = vim.env.HOME .. "\\.db\\bm.db"

local sessionDir = ""

local bookmark_cache = {}

local function checkForDatabase()

    local file = io.open(uri,"r")

    local dbExists = file ~= nil;

    if not dbExists then
        local filenew = io.open(uri,"w")
        filenew:write("")
        filenew:flush()
        filenew:close()
    end

    local db = sqlite:open(uri)

    if not dbExists then
        db.execute("PRAGMA foreign_keys = ON;")
        db.execute("CREATE TABLE IF NOT EXISTS sessions ( sessionId INTEGER PRIMARY KEY, sessionDir TEXT);")
        db.execute("CREATE TABLE IF NOT EXISTS bookmarks ( bookmarkId INTEGER PRIMARY KEY, bufId INTEGER, row INTEGER, column INTEGER, isGlobal BOOLEAN, name TEXT, sessionId INTEGER, FOREIGN KEY(sessionId) REFERENCES sessions(sessionId));")
    end

    return db
end

local function populateBookmarkCache(dir, db)
    local bookmarks = db:eval("select bufId, row, column, isGlobal, name from sessions join bookmarks on sessions.sessionId=bookmarks.sessionId where sessionDir='" .. dir .. "'")
    if bookmarks ~= false then
        bookmark_cache = bookmarks
    end
    print(vim.inspect(bookmarks))
end

local function setupAutcmds(db)
    local group = vim.api.nvim_create_augroup('bm',{clear = true})
    vim.api.nvim_create_autocmd({"SessionLoadPost"},{
        pattern = {"*"},
        callback = function ()
            if sessionDir ~= "" then

            else
                sessionDir = vim.fn.getcwd()
                populateBookmarkCache(sessionDir, db)
            end
        end
    })
end

function M.setup(args)
    if args.enabled then
        local db = checkForDatabase()
        setupAutcmds(db);
    end
end

function M.localBookmark()
    
end

function M.sound_off()
    vim.print("I LIVE!")
end

function M.globalBookmark()
    
end


return M
