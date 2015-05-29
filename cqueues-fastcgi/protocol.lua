
local FCGI = require "cqueues-fastcgi.constants"

local protocol = {}

local HeaderPattern = "> B B I2 I2 B x"
local HeaderLength = HeaderPattern:packsize()

local BeginRequestPattern = "> I2 B xxxxx"

local ShortLengthPattern = "> B"
local LongLengthMarker = (1 << 7)
local LongLengthPattern = "> I4"

local EndRequestPattern = "> I4 B xxx"

local UnknownRecordPattern = "> B xxxxxxx"

function protocol.readPacket(socket)
	-- read/parse header
	local header = socket:read(HeaderLength)
	
	if header == nil then
		return nil, nil, nil
	end
	
	local version, type, requestID, contentLength, paddingLength = HeaderPattern:unpack(header)
	
	-- read/parse buffer
	local content = socket:read(contentLength)
	
	-- consume padding
	socket:read(paddingLength)
	
	return requestID, type, content
end

function protocol.parseBeginRequest(content)
	local role, flags = BeginRequestPattern:unpack(content)
	local keepalive = (flags & FCGI.KEEP_CONN) > 0
	return role, keepalive
end

function protocol.parseNameValuePairs(content)
	local pairs = {}
	local pairOffset = 1
	
	while pairOffset < #content do
		local nameLength, valueLengthOffset = ShortLengthPattern:unpack(content, pairOffset)
		if nameLength >= LongLengthMarker then
			nameLength, valueLengthOffset = LongLengthPattern:unpack(content, pairOffset)
		end

		local valueLength, nameOffset = ShortLengthPattern:unpack(content, valueLengthOffset)
		if valueLength >= LongLengthMarker then
			valueLength, nameOffset = LongLengthPattern:unpack(content, valueLengthOffset)
		end
		
		local valueOffset = nameOffset + nameLength
		
		local name = content:sub(nameOffset, nameOffset + nameLength - 1)
		local value = content:sub(valueOffset, valueOffset + valueLength - 1)
		
		pairs[name] = value
		
		pairOffset = valueOffset + valueLength
	end
	
	return pairs
	
end

function protocol.writePacket(socket, requestID, type, content)
	local version, contentLength, paddingLength = 1, #content, 0
	
	local header = HeaderPattern:pack(version, type, requestID, contentLength, paddingLength)
	socket:write(header)
	socket:write(content)
end

function protocol.endRequest(socket, requestID, appStatus, protocolStatus)
	local content = EndRequestPattern:pack(appStatus or 0, protocolStatus or FCGI.REQUEST_COMPLETE)
	protocol.writePacket(socket, requestID, FCGI.END_REQUEST, content)
end

function protocol.unknownRecord(socket, type)
	local content = UnknownRecordPattern:pack(type)
	protocol.writePacket(socket, 0, FCGI.UNKNOWN_TYPE, content)
end

return protocol
