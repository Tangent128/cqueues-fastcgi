
local responder = require "cqueues-fastcgi.responder"
local cjson = require "cjson"

assert(responder.simpleLoop({
	path = "fastcgi.socket",
	unlink = true
}, function(request)
	local body = request:slurp()
	local input = cjson.decode(body)
	
	request:header("Status", 200)
	request:write("CONTENT:\n")
	--request:write(body)
	for k, v in pairs(input) do
		request:write(("%s = %s\n"):format(k, v))
	end
end, function(request, code, message)
	request:header("Status", tostring(code).." "..message)
	request:header("Content-Type", "application/json")
	request:header("Encoding", "UTF-8")
	request:write(cjson.encode {
		status = code,
		message = message
	})
end))
