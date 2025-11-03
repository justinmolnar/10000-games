local json = require('json')

local M = {}
M.filename = 'solitaire_state.json'
M.version = '1.0'

local function safe_write(path, contents)
    return pcall(love.filesystem.write, path, contents)
end

local function safe_read(path)
    local ok, data = pcall(love.filesystem.read, path)
    if not ok then return nil, data end
    return data, nil
end

function M.save(data)
    if type(data) ~= 'table' then return false, 'invalid data' end
    local payload = {
        version = M.version,
        timestamp = os.time(),
        data = data
    }
    local ok, json_str = pcall(json.encode, payload)
    if not ok then return false, 'encode failed' end
    local wrote, err = safe_write(M.filename, json_str)
    if not wrote then return false, err end
    return true
end

function M.load()
    local info = love.filesystem.getInfo(M.filename)
    if not info then return nil, 'no save' end
    local contents, err = safe_read(M.filename)
    if not contents then return nil, err end
    local ok, payload = pcall(json.decode, contents)
    if not ok or type(payload) ~= 'table' then
        pcall(love.filesystem.remove, M.filename)
        return nil, 'corrupt save removed'
    end
    if payload.version ~= M.version then
        -- Version mismatch: ignore old save (could migrate in future)
        return nil, 'incompatible version'
    end
    return payload.data
end

function M.clear()
    pcall(love.filesystem.remove, M.filename)
end

return M
