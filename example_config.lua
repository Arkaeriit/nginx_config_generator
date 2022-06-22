domain_name = "example.xyz"
key_path = "/etc/letsencrypt/live/"

hosts = {
        www = { -- configuration for a webserver at the URL www.example.xyz
                http = "server",
                https = "server",
                target = "/srv",
        },
        google = { -- google.example.xyz proxies to google.com
                http = "proxy",
                https = "proxy",
                target = "https://google.com",
        },
        [""] = { -- example.xyz proxies to www.example.xyz. Use [""] to indicate that we use the raw domain name as the URL
                http = "proxy",
                https = "proxy",
                target = "www.example.xyz",
        },
        website = { -- A single host can have different targets for http and https
                http = "proxy",
                https = "server",
                target = "https://other_website.xyz",
                target_https = "/srv/website",
        },
        blog = {
                http = "server",
                https = "auto", -- The `auto` directive will make the https://blog.example.xyz a proxy to http://blog.example.xyz
                target = "/srv/blog",
        },
        cooking = {
                http = "no", -- The `no` directive will make cooking.example.xyz only accessible with HTTPS and not HTTP
                https = "server",
                target = "/srv/cooking",
        },
        safesite = {
                http = "redirection",
                https = "server",
                target = "https://$host$request_uri", -- The http request will be redirected to https
                target_https = "/srv/safesite",
        },
}

