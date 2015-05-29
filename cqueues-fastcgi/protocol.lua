
local protocol = {}

protocol.HeaderPattern = "> B B I2 I2 B x"
protocol.HeaderLength = protocol.HeaderPattern:packsize()

function protocol.readPacket(socket)
	-- read/parse header
	local header = socket:read(protocol.HeaderLength)
	local version, type, requestID, contentLength, paddingLength = protocol.HeaderPattern:unpack(header)
	print(version, type, requestID)
	
	-- read/parse buffer
	local buffer = socket:read(contentLength)
	print(buffer)
	
	-- consume padding
	socket:read(paddingLength)
	
end

return protocol
