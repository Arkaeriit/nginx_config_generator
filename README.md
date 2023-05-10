# Nginx Config Generator

A tool to generate Nginx config file from a compact Lua table.

## Usage

```
./nginx_config_generator.lua <config.lua>
```

## Lua config file

### Top level configuration

The Lua config have to specify 4 variables:

* `domain_name`: Your domain name such as `"example.xyz"`
* `key_path`: The path to your SSL keys such as `"/etc/letsencrypt/live/"` if you are using certbot.
* `hosts`: A table whose keys are the host names and whose values are a table with the host's configuration.
* `extra`: An optional string that will be added as-is on the output file.

### Host configuration

The configuration for each host is a table, this table must have the fields `http`, `https`, and `target`.

The field `http` can have the following value:

* `"no"`: In that case, the server does not serves HTTP on this host.
* `"server"`: The host will act as a web server. The path to the files to serve are in the `target` field.
* `"proxy"`: The host will act as a proxy. The target URL must be in the `target` field.
* `"redirection"`: The host will redirect to the URL in the `target` field.

The field `https` can have the same values or the `"auto"` value which make so that the HTTPS host acts as a proxy for the HTTP host.

By default, the HTTP and HTTPS hosts will have the same targets. But you can specify a different target for the HTTPS host in the field `target_https`.

### Example

The file `example_config.lua` in this repository is an example of what can be done with this tool.

