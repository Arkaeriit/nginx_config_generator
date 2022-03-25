#!/usr/bin/env lua

------------------------------ Making server block. ----------------------------

-- Put the desired content in a basic http block. The last argument is unused
-- and is only there so that the prototype is the same as `https_frame`.
local function http_frame(server_name, content, _)
    local ret = "server {\n"
    ret =  ret.."    listen 80;\n"
    ret =  ret.."    server_name "..server_name..";\n"
    ret =  ret.."    \n"
    ret =  ret..content.."\n"
    ret =  ret .."}\n"
    return ret
end

-- Put the desired content in a https block.
local function https_frame(server_name, content, key_path)
    local ret = "server {\n"
    ret =  ret.."    listen 443 ssl;\n"
    ret =  ret.."    server_name "..server_name..";\n"
    ret =  ret.."    ssl_certificate     "..key_path.."/"..server_name.."/fullchain.pem;\n"
    ret =  ret.."    ssl_certificate_key "..key_path.."/"..server_name.."/privkey.pem;\n"
    ret =  ret.."    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;\n"
    ret =  ret.."    ssl_ciphers         HIGH:!aNULL:!MD5;\n"
    ret =  ret.."    \n"
    ret =  ret..content.."\n"
    ret =  ret .."}\n"
    return ret
end

-- Generate the main content for a nginx web server.
local function server_content(files_path)
    local ret = "    index index.html;\n"
    ret =  ret.."    root "..files_path..";\n"
    ret =  ret.."    location / {\n"
    ret =  ret.."        try_files $uri $uri/ =404;\n"
    ret =  ret.."    }\n"
    return ret
end

-- Generate the main content for a nginx proxy.
local function proxy_content(destination)
    local ret = "    location / {\n"
    ret =  ret.."        proxy_pass "..destination..";\n"
    ret =  ret.."    }\n"
    return ret
end

-- Generate a complete server block. `is_http` and `is_proxy` are booleans used
-- to tell what kind of block to create. `target` is either the path to the web
-- pages or the URL of the proxy's target.
function make_block(is_https, is_proxy, server_name, key_path, target)
    local frame_func = http_frame
    if is_https then
        frame_func = https_frame
    end
    local content_func = server_content
    if is_proxy then
        content_func = proxy_content
    end
    return frame_func(
        server_name,
        content_func(target),
        key_path)
end

----------------------------------- Error codes --------------------------------

ERR_OK                = 0
ERR_MISSING_CONFIG    = 1
ERR_MISSING_FIELD     = 2
ERR_INVALID_FIELD     = 3
ERR_INVALID_ARGUMENTS = 4

------------------- Generating output from input configuration -----------------

-- Generates a full URL for the host at the desired domain name.
local function gen_servername(host, domain_name)
    if host == "@" or host == "" then
        return domain_name
    else
        return host.."."..domain_name
    end
end

-- Reads the configuration file given as argument and return the generated
-- nginx configuration and an error code.
function gen_output(config_file)
    dofile(config_file)
    -- Error checking
    if type(domain_name) ~= "string" then
        io.stderr:write("Error, the domain name has not be specified as a string.")
        return "", ERR_MISSING_CONFIG
    end
    if type(key_path) ~= "string" then
        io.stderr:write("Error, the keys path has not be specified as a string.")
        return "", ERR_MISSING_CONFIG
    end
    if type(hosts) ~= "table" then
        io.stderr:write("Error, the host list has not be specified as a table.")
        return "", ERR_MISSING_CONFIG
    end
    -- Main processing
    ret = ""
    for k,v in pairs(hosts) do
        local server_name = gen_servername(k, domain_name)
        -- Error checking
        if type(v.http) ~= "string" or type(v.https) ~= "string" or type(v.target) ~= "string"then
        io.stderr:write("Error, fields `http`, `https`, and `target` should be specified for the host '", k,"'.\n")
        return "", ERR_MISSING_FIELD
        end
        -- HTTP
        if v.http == "no" then
            --
        elseif v.http == "server" then
            ret = ret..make_block(false, false, server_name, key_path, v.target).."\n"
        elseif v.http == "proxy" then
            ret = ret..make_block(false, true, server_name, key_path, v.target).."\n"
        else
            io.stderr:write('Error, the value of the `http` field for the host "', k, '" should be "no", "server", or "proxy".\n')
            return "", ERR_INVALID_FIELD
        end
        -- HTTPS
        local target = v.target
        if v.target_https then
            target = v.target_https
        end
        if v.https == "no" then
            --
        elseif v.https == "server" then
            ret = ret..make_block(true, false, server_name, key_path, target).."\n"
        elseif v.https == "proxy" then
            ret = ret..make_block(true, true, server_name, key_path, target).."\n"
        elseif v.https == "auto" then
            ret = ret..make_block(true, true, server_name, key_path, "http://"..server_name).."\n"
        else
            io.stderr:write('Error, the value of the `https` field for the host "', k, '" should be "no", "auto", "server", or "proxy".\n')
            return "", ERR_INVALID_FIELD
        end
    end
    return ret, ERR_OK

end

-------------------------------------- Main ------------------------------------

function main()
    if #arg ~= 1 then
        io.stderr:write("Error invalid arguments.\n", "Do nginx_config_generator.lua --help for more info.\n")
        return ERR_INVALID_ARGUMENTS
    end
    if arg[1] == "help" or arg[1] == "--help" or arg[1] == "-h" then
        help()
        return ERR_OK
    else
        str, rc = gen_output(arg[1])
        print(str)
        return rc
    end
end

function help()
    print("TODO")
end
    
os.exit(main())

