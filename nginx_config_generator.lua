#!/usr/bin/env lua

documentation = [[Usage:
./nginx_config_generator.lua <config.lua>

# Lua config file

## Top level configuration

The Lua config have to specify 3 variable:

* `domain_name`: Your domain name such as `"example.xyz"`
* `key_path`: The path to your SSL keys such as `"/etc/letsencrypt/live/"` if you are using certbot.
* `hosts`: A table whose keys are the host names and whose values are a table with the host's configuration.

## Host configuration

The configuration for each host is a table, this table must have the fields `http`, `https`, and `target`.

The field `http` can have the following value:

* `"no"`: In that case, the server does not serves HTTP on this host.
* `"server"`: The host will act as a web server. The path to the files to serve are in the `target` field.
* `"proxy"`: The host will act as a proxy. The target URL must be in the `target` field.

The field `https` can have the same values or the `"auto"` value which make so that the HTTPS host acts as a proxy for the HTTP host.

By default, the HTTP and HTTPS hosts will have the same targets. But you can specify a different target for the HTTPS host in the field `target_https`.
]]

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
    ret =  ret.."        proxy_set_header Host $host;\n"
    ret =  ret.."        proxy_set_header X-Real-IP $remote_addr;\n"
    ret =  ret.."        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n"
    ret =  ret.."        proxy_set_header X-Forwarded-Proto $scheme;\n"
    ret =  ret.."        add_header Front-End-Https on;\n"
    ret =  ret.."        proxy_headers_hash_max_size 512;\n"
    ret =  ret.."        proxy_headers_hash_bucket_size 64;\n"
    ret =  ret.."        client_max_body_size 1G;\n"
    ret =  ret.."        proxy_buffering off;\n"
    ret =  ret.."        proxy_redirect off;\n"
    ret =  ret.."        proxy_max_temp_file_size 0;\n"
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
    if host == "" then
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
    print(documentation)
end
    
os.exit(main())

