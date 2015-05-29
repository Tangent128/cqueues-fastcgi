
local FCGI = require "cqueues-fastcgi.constants"

local protocol = {}

protocol.HeaderPattern = "> B B I2 I2 B x"
protocol.HeaderLength = protocol.HeaderPattern:packsize()

protocol.BeginRequestPattern = "> I2 B xxxxx"

protocol.EndRequestPattern = "> I4 B xxx"

function protocol.readPacket(socket)
	-- read/parse header
	local header = socket:read(protocol.HeaderLength)
	
	if header == nil then
		return nil, nil, nil
	end
	
	local version, type, requestID, contentLength, paddingLength = protocol.HeaderPattern:unpack(header)
	
	-- read/parse buffer
	local content = socket:read(contentLength)
	
	-- consume padding
	socket:read(paddingLength)
	
	return requestID, type, content
end

function protocol.parseBeginRequest(content)
	local role, flags = protocol.BeginRequestPattern:unpack(content)
	local keepalive = (flags & FCGI.KEEP_CONN) > 0
	return role, keepalive
end

function protocol.writePacket(socket, requestID, type, content)
	local version, contentLength, paddingLength = 1, #content, 0
	
	local header = protocol.HeaderPattern:pack(version, type, requestID, contentLength, paddingLength)
	socket:write(header)
	socket:write(content)
	
	print("Sent", type, requestID, content)
end

function protocol.endRequest(socket, requestID, appStatus, protocolStatus)
	local content = protocol.EndRequestPattern:pack(appStatus, protocolStatus or FCGI.REQUEST_COMPLETE)
	protocol.writePacket(socket, requestID, FCGI.END_REQUEST, content)
end

return protocol
