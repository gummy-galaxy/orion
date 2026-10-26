local net = require("@lute/net/server")

local LOOPBACK_NAMES = table.freeze({ "localhost", "127.0.0.1", "[::1]" })

local function isTrustedAddress(address: string, hostname: string, ports: { number }): boolean
	local name, port = address:lower():match("^(.+):(%d+)$")
	if not name or not table.find(ports, tonumber(port) :: number) then
		return false
	end

	return name == hostname:lower() or table.find(LOOPBACK_NAMES, name) ~= nil
end

-- Whether a request comes from the app rather than another site. Its `Host`
-- must name this server's address or a loopback name on one of `ports`, which
-- closes DNS rebinding. Browsers send `Origin` on every cross-site request,
-- including the `text/plain` POSTs and WebSocket upgrades that skip CORS, so
-- one that is present must name the same. Requests without one come from local
-- tools such as curl.
local function isTrustedRequest(request: net.ReceivedRequest, hostname: string, ports: { number }): boolean
	local host = request.headers.host
	if not host or not isTrustedAddress(host, hostname, ports) then
		return false
	end

	local origin = request.headers.origin
	if origin == nil then
		return true
	end

	local address = origin:lower():match("^http://([^/]+)$")

	return address ~= nil and isTrustedAddress(address, hostname, ports)
end

return isTrustedRequest
