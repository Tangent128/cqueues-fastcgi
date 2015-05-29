local cqueues = require "cqueues"
local socket = require "cqueues.socket"

local FCGI = require "cqueues-fastcgi.constants"
local responder = require "cqueues-fastcgi.responder"

local controller = cqueues.new()

local server = socket.listen {
	path = "fastcgi.socket",
	--host = "localhost", port = 4125,
	unlink = true
}

local clients = 0

controller:wrap(function()
	
	while true do
		local connection = server:accept()
		
		controller:wrap(function()
			local request = responder.new(connection)
			
			request:pcall(function()
				request:init()
				request:header("Status", 200)
				request:write "PARAMS:\n"
				for k, v in pairs(request.params) do
					request:write(("%s = %s\n"):format(k, v))
				end
			end)

			request:close()
			
		end)

	end
end)

assert(controller:loop())
