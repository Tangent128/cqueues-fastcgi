
local json_api = require "cqueues-fastcgi.json-api"

-- convenience wrapper for a JSON API; 
assert(json_api.simpleLoop({
	path = "fastcgi.socket",
	unlink = true
}, function(request, input)
	return {
        CGI = request.params;
        CONTENT = input;
    }
end, function(request, code, message)
	request:header("Status", tostring(code).." "..message)
	request:header("Content-Type", "application/json")
	request:header("Encoding", "UTF-8")
	request:write(cjson.encode {
		status = code,
		message = message
	})
end))
