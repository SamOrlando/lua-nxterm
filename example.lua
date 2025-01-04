local nxterm = require('nxterm')

local sc = nxterm.color   -- screen colors
print( sc.red .. 'The color red ' .. sc.bg_blue .. 'now blue background' .. sc['reset bold yellow'] .. '!!!' )
print( sc'red bold ul' .. 'The color red bold and underlined' )
print( sc['green blink italic'] .. "The color green blinking and italic" )
print( sc'' .. 'Nice and boring.' )  -- empty will be reset of attributes

print( sc('r200g100b20') .. 'r200g100b20 (Truecolor)' )
print( sc('bg_r100g200b255 black') .. 'bg_r100g200b255 black (Truecolor backgrounds)' .. sc'' ) -- reset for background before return
print( sc('#BB0066') .. '#BB0066 (Truecolor)' )
print( sc('c88') .. 'c88 (palette colors)' )
print( sc('g10') .. 'g5 (palette grays)' )

local es = nxterm.escape_codes  -- escape string codes and return
print( es('This is %{red}red %{bold}bold %{ul}underlined %{reset}all in one.') )
print( es('This is %{r0g255b0}green %{bold}bold %{blink}blinking %{}all in one.') ) -- empty {}'s are resets as 0m is default
print( es('This is %{#0000BB bold blink}blue bold blinking and %{ul}underline %{}all in one.') )