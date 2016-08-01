
local json_api = require "cqueues-fastcgi.json-api"
local router = require "cqueues-fastcgi.router"

assert(json_api.simpleLoop({
	path = "fastcgi.socket",
	unlink = true
}, function(request, input)
    return router.dispatch(request, input, {
        ["/echo"] = function(request, input)
            return {
                CGI = request.params;
                CONTENT = input;
            }
        end,
        ["/add/(%d+)/(%d+)"] = function(request, input, left, right)
            return {
                sum = left + right
            }
        end
    }) or {
        status = 404
    }
end))
