
local router = {}
local type = type
local unpack = table.unpack

-- a utility function to match a request to an appropriate handler;
-- first match wins. Does nothing on failure, so a catchall is advised.
-- The handler function is called as (request, input, ...),
-- where ... is the matches from the URL pattern.
function router.dispatch(request, input, routes)
    local path = request.params.PATH_INFO
    for route, handler in pairs(routes) do
        if type(route) == "string" then
            route = {path = route}
        end
        local captures = {path:match(route.path)}
        if #captures > 0 then
            return handler(request, input, unpack(captures))
        end
    end
end

return router
