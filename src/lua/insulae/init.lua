------------
-- insulae.init
-- main insulae module
-- module: insulae
-- author: AitorATuin
-- license: GPL3

local Insulae = {
  VERSION  = 0.1,
  AUTHOR   = 'AitorATuin'
  packages = {
    lua = {
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
    }
  }
}

return Insulae
