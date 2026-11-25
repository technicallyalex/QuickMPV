-- Runs only in the background preview decoder. The mailbox carries a sequence number and seek position.
local mp = require 'mp'
local options = {base=''}
require('mp.options').read_options(options,'quick-thumb-worker')
if options.base=='' then return end

local last = 0
mp.add_periodic_timer(.02,function()
    local file=io.open(options.base..'.request','rb')
    if not file then return end
    local request=file:read(80) or ''
    file:close()
    local sequence,seconds=request:match('^(%d+) (%d+%.%d+)\n$')
    sequence,seconds=tonumber(sequence),tonumber(seconds)
    if not sequence or not seconds or sequence<=last then return end
    last=sequence
    mp.commandv('seek',seconds,'absolute+exact')
end)
