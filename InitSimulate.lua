--- Original: Divvy's Simulation for Balatro - Init.lua
--
-- Global values that must be present for the rest of this mod to work.

if not FN then FN = {} end

-- SAFETY NET: this mod must never be able to crash the game.
-- Runs `func(...)` and returns `true, result`. If `func` throws an error, that error is caught and
-- written to the log (every distinct error only once), and `false` is returned instead.
FN.logged_errors = {count = 0}
function FN.safe_call(label, func, ...)
   local ok, result = pcall(func, ...)
   if ok then return true, result end

   local message = "[FantomsPreview] Error in " .. tostring(label) .. ": " .. tostring(result)
   if not FN.logged_errors[message] and FN.logged_errors.count < 25 then
      FN.logged_errors[message] = true
      FN.logged_errors.count = FN.logged_errors.count + 1
      pcall(print, message)
   end
   return false
end

FN.SIM = {
   JOKERS = {},
   
   running = {
      --- Table to store workings (ie. running totals):
      min   = {chips = 0, mult = 0, dollars = 0},
      exact = {chips = 0, mult = 0, dollars = 0},
      max   = {chips = 0, mult = 0, dollars = 0},
      reps = 0,
   },

   env = {
      --- Table to store data about the simulated play:
      jokers = {},        -- Derived from G.jokers.cards
      played_cards = {},  -- Derived from G.hand.highlighted
      scoring_cards = {}, -- Derived according to evaluate_play()
      held_cards = {},    -- Derived from G.hand minus G.hand.highlighted
      consumables = {},   -- Derived from G.consumeables.cards
      scoring_name = ""   -- Derived according to evaluate_play()
   },

   orig = {
      --- Table to store game data that gets modified during simulation:
      random_data = {}, -- G.GAME.pseudorandom
      hand_data = {},   -- G.GAME.hands
      blind_triggered = nil, -- G.GAME.blind.triggered
      is_saved = false  -- Whether the above currently hold a saved state that was not restored yet
   },

   misc = {
      --- Table to store ancillary status variables:
      next_stone_id = -1,
      blind_triggered = false -- Mirrors G.GAME.blind.triggered during simulation (for Matador)
   }
}
