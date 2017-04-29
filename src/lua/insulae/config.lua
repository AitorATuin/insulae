------------
-- insulae.config
-- insulae config module
-- module: insulae.config
-- author: AitorATuin
-- license: GPL3

local Config = {
  VERSION  = 0.1,
  AUTHOR   = 'AitorATuin'

  packages = {
    lua = {
      default = '51',
      ['51'] = {
        version = '5.1.5',
        url     = 'https://www.lua.org/ftp/lua-5.3.4.tar.gz',
        sha256  = '2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333'
      }
      ['52']    = {
        version = '5.2.4',
        url     = 'https://www.lua.org/ftp/lua-5.2.4.tar.gz'
        sha256  = 'b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b'
      }
       ['53']   = {
        version = '5.3.4',
        url     = 'https://www.lua.org/ftp/lua-5.3.4.tar.gz',
        sha256  = 'f681aa518233bc407e23acf0f5887c884f17436f000d453b2491a9f11a52400c'
      }
    },
    luarocks = {
      version = '2.4.2',
      url = 'https://luarocks.github.io/luarocks/releases/luarocks-2.4.2.tar.gz',
      sha256 = '0e1ec34583e1b265e0fbafb64c8bd348705ad403fe85967fd05d3a659f74d2e5'
    }
  }
}

function Config.default_lua_version()
  return Config.packages.lua[Config.packages.lua.default]
end

function Config.get_lua_version(version)
  return Config.packages.lua[version]
end

function Config.default_luarocks_version()
  return Config.packages.luarocks
end

return Config
