local cqueues = require "cqueues"
local socket = require "cqueues.socket"

local FCGI = require "cqueues-fastcgi.constants"
local protocol = require "cqueues-fastcgi.protocol" 

local controller = cqueues.new()

local server = socket.listen {
	path = "fastcgi.socket",
	--host = "localhost", port = 4125,
	unlink = true
}

controller:wrap(function()
	
	while true do
		local connection = server:accept()
		connection:setmode("bn", "bn")
		
		controller:wrap(function()
			while true do
				local requestID, type, content = protocol.readPacket(connection)
				if requestID == nil then
					return
				end
				
				print(type, requestID, #content)
			
				if type == FCGI.BEGIN_REQUEST then
					local role, keepalive = protocol.parseBeginRequest(content)
					print(role, keepalive)
				end
				
				if type == FCGI.STDIN and #content == 0 then
					protocol.writePacket(connection, requestID, FCGI.STDOUT, "Status: 200 OK\r\n\r\n...")
					protocol.writePacket(connection, requestID, FCGI.STDOUT, "")
					--protocol.writePacket(connection, requestID, FCGI.STDERR, "Error, is a test")
					protocol.writePacket(connection, requestID, FCGI.STDERR, "")
					protocol.endRequest(connection, requestID, 200)
					connection:shutdown("w")
				end
			end
		end)

	end
end)

assert(controller:loop())
