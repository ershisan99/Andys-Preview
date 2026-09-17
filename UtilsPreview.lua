--- Original: Divvy's Preview for Balatro - Utils.lua
--
-- Utilities for checking states and formatting display.

function FN.PRE.is_enough_to_win(chips)
   if G.GAME.blind and
      (G.STATE == G.STATES.SELECTING_HAND or
       G.STATE == G.STATES.DRAW_TO_HAND or
       G.STATE == G.STATES.PLAY_TAROT)
   then return (G.GAME.chips + chips >= G.GAME.blind.chips)
   else return false
   end
end

function FN.PRE.format_number(num)
   if not num or type(num) ~= 'number' then return num or '' end
   -- Start using e-notation earlier to reduce number length, if showing min and max for preview:
   if true and num >= 1e7 then
      local x = string.format("%.4g",num)
      local fac = math.floor(math.log(tonumber(x), 10))
      return string.format("%.2f",x/(10^fac))..'e'..fac
   end
   return number_format(num) -- Default Balatro function.
end

-- NOTE: Must ALWAYS return a colour. The result is handed to the game's text renderer, which
--       crashes while drawing (where no error can be caught) if it receives no colour.
function FN.PRE.get_dollar_colour(n)
   if FN.PRE.is_finite_number(n) then
      if n > 0 and G.C.MONEY then return G.C.MONEY end
      if n < 0 and G.C.RED then return G.C.RED end
   end
   return HEX("7e7667")
end

-- Whether `n` is an actual, displayable number (ie. not nil, not NaN, not infinite):
function FN.PRE.is_finite_number(n)
   return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

-- Formats a change in money, eg. "+$3", "-$12" or "$0":
function FN.PRE.format_dollars(n)
   if not FN.PRE.is_finite_number(n) then return localize('$') .. "??" end
   local sign = ""
   if n > 0 then sign = "+" elseif n < 0 then sign = "-" end
   return sign .. localize('$') .. FN.PRE.format_number(math.abs(n))
end

function FN.PRE.get_sign_str(n)
   if n >= 0 then return "+"
   else return "" -- Negative numbers already have a sign
   end
end

function FN.PRE.enabled()
   return G.SETTINGS.FN.preview_score or G.SETTINGS.FN.preview_dollars
end
