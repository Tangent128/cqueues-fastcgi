
local cqueues = require "cqueues"
local cqueuesSocket = require "cqueues.socket"

local FCGI = require "cqueues-fastcgi.constants"
local protocol = require "cqueues-fastcgi.protocol"

local responder = {}
local responder_funcs = {}
local responder_mt = {
	__index = responder_funcs
}

-- convenience handler for managing the FastCGI Responder protocol
-- on an accepted socket; limited to one request per socket 
function responder.new(socket)
	socket:setmode("bn", "bn")

	return setmetatable({
		socket = socket,
		requestID = 0,
		params = {},
		headersDone = false
	}, responder_mt)
end

local function handleManagementRecord(socket, type, content)
	protocol.unknownRecord(socket, type)
end

function responder_funcs:readPacket()
	local requestID, type, content = protocol.readPacket(self.socket)
	if requestID == nil then -- EOF
		return nil, nil
	end
	if requestID == 0 then -- management record, handle internally
		handleManagementRecord(self.socket, type, content)
		return self:readPacket()
	end
	if self.requestID == 0 then -- first record of request
		self.requestID = requestID
	end
	if requestID ~= self.requestID then -- reject extra request
		protocol.endRequest(connection, requestID, 0, FCGI.CANT_MPX_CONN)
		return self:readPacket()
	end
	
	return type, content
end

function responder_funcs:init()
	local type, content = self:readPacket()
	assert(type == FCGI.BEGIN_REQUEST, "Request opened with non-BEGIN packet")
	local role = protocol.parseBeginRequest(content)
	assert(role == FCGI.RESPONDER, "Request wants non-responder role")
	
	-- read params string
	local chunks = {}
	for type, chunk in self.readPacket, self do
		if chunk == "" then
			break
		end
		assert(type == FCGI.PARAMS, "Unknown packet when expecting PARAMS")
		chunks[#chunks + 1] = chunk
	end
	
	local paramData = table.concat(chunks)
	self.params = protocol.parseNameValuePairs(paramData)
end

function responder_funcs:read()
	local type, content = self:readPacket()
	
	if type == nil or content == "" then
		return nil
	end
	
	assert(type == FCGI.STDIN, "Unknown packet when expecting STDIN")
	
	return content
end

function responder_funcs:slurp()
	local chunks = {}
	for chunk in self.read, self do
		chunks[#chunks + 1] = chunk
	end
	return table.concat(chunks)
end

function responder_funcs:header(name, value)
	--TODO: escape header values
	local header = ("%s: %s\r\n"):format(name, tostring(value))
	protocol.writePacket(self.socket, self.requestID, FCGI.STDOUT, header)
end

function responder_funcs:write(content)
	if not self.headersDone then
		protocol.writePacket(self.socket, self.requestID, FCGI.STDOUT, "\r\n")
		self.headersDone = true
	end
	if content ~= "" then
		protocol.writePacket(self.socket, self.requestID, FCGI.STDOUT, content)
	end
end

function responder_funcs:log(content)
	if content ~= "" then
		protocol.writePacket(self.socket, self.requestID, FCGI.STDERR, content)
	end
end

function responder_funcs:close()
	protocol.writePacket(self.socket, self.requestID, FCGI.STDOUT, "")
	protocol.writePacket(self.socket, self.requestID, FCGI.STDERR, "")
	protocol.endRequest(self.socket, self.requestID)
	self.socket:shutdown("w")
end

-- runs func in protected mode, sending any error message as STDERR
-- does not end the request even on error
function responder_funcs:pcall(func, ...)
	local ok, err = pcall(func, ...)
	if not ok then
		self:log(tostring(err))
	end
end

-- default "error page" handler for the simpleLoop;
-- called by simpleLoop if a request errors before
-- sending a response
local function errorPage(request, code, message)
	request:header("Status", tostring(code).." "..message)
	request:header("Content-Type", "text/plain")
	request:header("Encoding", "UTF-8")
	request:write(message)
end

-- a default main loop that implements a typical application
-- structure for FastCGI responders
function responder.simpleLoop(socketOpts, func, errorHandler)
	local controller = cqueues.new()
	local server = cqueuesSocket.listen(socketOpts)
	
	controller:wrap(function()
		while true do
			local client = server:accept()
			
			controller:wrap(function()
				local request = responder.new(client)
				
				request:pcall(function()
					request:init()
					func(request)
				end)
				
				if not request.headersDone then
					(errorHandler or errorPage)(request, 500, "Script Error")
				end
				
				request:close()
			end)
		end
	end)
	
	return controller:loop()
end

return responder
