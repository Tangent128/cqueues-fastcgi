
local responder = require "cqueues-fastcgi.responder"
local cjson = require "cjson"

local json_api = {}

-- a default main loop that implements a FastCGI responder
-- for a JSON API, automatically decodes & encodes input & output
function json_api.simpleLoop(socketOpts, appFunc)
    return responder.simpleLoop(socketOpts,
    function(request)
        local body = request:slurp()
        local input = cjson.decode(body)
        
        local output = appFunc(request, input)
        
        if not output.status then
            output.status = 200
        end
        request:header("Status", output.status)
        request:header("Content-Type", "application/json")
        request:write(cjson.encode(output))
    end, function(request, code, message)
        request:header("Status", tostring(code).." "..message)
        request:header("Content-Type", "application/json")
        request:header("Encoding", "UTF-8")
        request:write(cjson.encode {
            status = code,
            message = message
        })
    end)
end

return json_api
