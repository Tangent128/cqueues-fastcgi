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
			clients = clients + 1
			local request = responder.new(connection)
			
			request:init()
			request:header("Status", 200)
			cqueues.sleep(5)
			request:write(("%i clients connected"):format(clients))
			request:close()
			clients = clients - 1
		end)

	end
end)

assert(controller:loop())
