
local responder = require "cqueues-fastcgi.responder"

assert(responder.simpleLoop({
	path = "fastcgi.socket",
	unlink = true
}, function(request)
	request:header("Status", 200)
	request:write "PARAMS:\n"
	for k, v in pairs(request.params) do
		request:write(("%s = %s\n"):format(k, v))
	end
end))
