--- Original: Divvy's Simulation for Balatro - Engine.lua
--
-- The heart of this library: it replicates the game's score evaluation.

if not FN.SIM.run then
   -- Returns the simulated results, or nil if the simulation failed for whatever reason.
   -- An error in here can never reach (and crash) the game, and never leaves game state modified.
   function FN.SIM.run()
      local ok, results = FN.safe_call("simulation", FN.SIM.run_unprotected)
      if ok and results then return results end

      if FN.SIM.orig.is_saved then
         FN.safe_call("simulation state restore", FN.SIM.manage_state, "RESTORE")
      end
      return nil
   end

   function FN.SIM.run_unprotected()
      local null_ret = {score = {min=0, exact=0, max=0}, dollars = {min=0, exact=0, max=0}}
      if #G.hand.highlighted < 1 then return null_ret end

      FN.SIM.init()

      FN.SIM.manage_state("SAVE")
      FN.SIM.update_state_variables()

      if FN.SIM.is_hook_active() then
         -- The Hook discards random held cards before scoring, so every possible discard is simulated:
         FN.SIM.simulate_hook()
      elseif not FN.SIM.simulate_blind_debuffs() then
         FN.SIM.simulate_hand()
      else -- Only Matador at this point:
         FN.SIM.simulate_all_jokers(G.jokers, {debuffed_hand = true})
      end

      FN.SIM.manage_state("RESTORE")

      return FN.SIM.get_results()
   end

   -- Mirrors the scoring branch of G.FUNCS.evaluate_play(..)
   function FN.SIM.simulate_hand()
      FN.SIM.simulate_joker_before_effects()
      FN.SIM.add_base_chips_and_mult()
      FN.SIM.simulate_blind_effects()
      FN.SIM.simulate_scoring_cards()
      FN.SIM.simulate_held_cards()
      FN.SIM.simulate_joker_global_effects()
      FN.SIM.simulate_consumable_effects()
      FN.SIM.simulate_deck_effects()
   end

   function FN.SIM.reset_running()
      FN.SIM.running = {
         min   = {chips = 0, mult = 0, dollars = 0},
         exact = {chips = 0, mult = 0, dollars = 0},
         max   = {chips = 0, mult = 0, dollars = 0},
         reps = 0
      }
   end

   function FN.SIM.init()
      -- Reset:
      FN.SIM.reset_running()
      FN.SIM.misc.blind_triggered = false

      -- Fetch metadata about simulated play:
      local hand_name, _, poker_hands, scoring_hand, _ = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
      FN.SIM.env.scoring_name = hand_name
      FN.SIM.env.poker_hands = poker_hands

      -- Identify played cards and extract necessary data:
      FN.SIM.env.played_cards = {}
      FN.SIM.env.scoring_cards = {}
      local is_splash_joker = next(find_joker("Splash"))
      table.sort(G.hand.highlighted, function(a, b) return a.T.x < b.T.x end) -- Sorts by positional x-value to mirror card order!
      for _, card in ipairs(G.hand.highlighted) do
         local is_scoring = false
         for _, scoring_card in ipairs(scoring_hand) do
         -- Either card is scoring because it's part of the scoring hand,
         -- or there is Splash joker, or it's a Stone Card:
            if card.sort_id == scoring_card.sort_id
               or is_splash_joker
               or card.ability.effect == "Stone Card"
            then
               is_scoring = true
               break
            end
         end

         local card_data = FN.SIM.get_card_data(card)
         table.insert(FN.SIM.env.played_cards, card_data)
         if is_scoring then table.insert(FN.SIM.env.scoring_cards, card_data) end
      end

      -- Identify held cards and extract necessary data:
      FN.SIM.env.held_cards = {}
      for _, card in ipairs(G.hand.cards) do
         -- Highlighted cards are simulated as played cards:
         if not card.highlighted then
            local card_data = FN.SIM.get_card_data(card)
            table.insert(FN.SIM.env.held_cards, card_data)
         end
      end

      -- Extract necessary joker data:
      FN.SIM.env.jokers = {}
      for _, joker in ipairs(G.jokers.cards) do
         local joker_data = {
            -- P_CENTER keys for jokers have the form j_NAME, get rid of j_
            id = joker.config.center.key:sub(3, #joker.config.center.key),
            ability = copy_table(joker.ability),
            edition = copy_table(joker.edition),
            rarity = joker.config.center.rarity,
            debuff = joker.debuff
         }
         table.insert(FN.SIM.env.jokers, joker_data)
      end

      -- Extract necessary consumable data:
      FN.SIM.env.consumables = {}
      for _, consumable in ipairs(G.consumeables.cards) do
         local consumable_data = {
            -- P_CENTER keys have the form x_NAME, get rid of x_
            id = consumable.config.center.key:sub(3, #consumable.config.center.key),
            ability = copy_table(consumable.ability)
         }
         table.insert(FN.SIM.env.consumables, consumable_data)
      end

      -- Set extensible context template:
      FN.SIM.get_context = function(cardarea, args)
         local context = {
            cardarea = cardarea,
            full_hand = FN.SIM.env.played_cards,
            scoring_name = hand_name,
            scoring_hand = FN.SIM.env.scoring_cards,
            poker_hands = poker_hands
         }

         for k, v in pairs(args) do
            context[k] = v
         end

         return context
      end
   end

   function FN.SIM.get_card_data(card_obj)
      return {
         rank = card_obj.base.id,
         suit = card_obj.base.suit,
         base_chips = card_obj.base.nominal,
         ability = copy_table(card_obj.ability),
         edition = copy_table(card_obj.edition),
         seal = card_obj.seal,
         debuff = card_obj.debuff,
         lucky_trigger = {}
      }
   end

   function FN.SIM.get_results()
      local FNSR = FN.SIM.running

      local min_score   = math.floor(FNSR.min.chips   * FNSR.min.mult)
      local exact_score = math.floor(FNSR.exact.chips * FNSR.exact.mult)
      local max_score   = math.floor(FNSR.max.chips   * FNSR.max.mult)

      return {
         score   = {min = min_score,        exact = exact_score,        max = max_score},
         dollars = {min = FNSR.min.dollars, exact = FNSR.exact.dollars, max = FNSR.max.dollars}
      }
   end

   --
   -- GAME STATE MANAGEMENT:
   --

   function FN.SIM.manage_state(save_or_restore)
      local FNSO = FN.SIM.orig

      if save_or_restore == "SAVE" then
         FNSO.random_data = copy_table(G.GAME.pseudorandom)
         FNSO.hand_data = copy_table(G.GAME.hands)
         FNSO.blind_triggered = G.GAME.blind.triggered
         FNSO.is_saved = true
         return
      end

      if save_or_restore == "RESTORE" then
         FNSO.is_saved = false
         G.GAME.pseudorandom = FNSO.random_data
         G.GAME.hands = FNSO.hand_data
         G.GAME.blind.triggered = FNSO.blind_triggered
         return
      end
   end

   function FN.SIM.update_state_variables()
      -- Increment poker hand played this run/round:
      local hand_info = G.GAME.hands[FN.SIM.env.scoring_name]
      hand_info.played = hand_info.played + 1
      hand_info.played_this_round = hand_info.played_this_round + 1
   end

   --
   -- MACRO LEVEL:
   --

   function FN.SIM.simulate_scoring_cards()
      for _, scoring_card in ipairs(FN.SIM.env.scoring_cards) do
         -- As in evaluate_play(..), a debuffed scoring card counts as the blind being triggered (Matador):
         if scoring_card.debuff then FN.SIM.misc.blind_triggered = true end
         FN.SIM.simulate_card_in_context(scoring_card, G.play)
      end
   end

   function FN.SIM.simulate_held_cards()
      for _, held_card in ipairs(FN.SIM.env.held_cards) do
         FN.SIM.simulate_card_in_context(held_card, G.hand)
      end
   end

   function FN.SIM.simulate_joker_global_effects()
      for _, joker in ipairs(FN.SIM.env.jokers) do
         if joker.edition then -- Foil and Holo:
            if joker.edition.chips then FN.SIM.add_chips(joker.edition.chips) end
            if joker.edition.mult  then FN.SIM.add_mult(joker.edition.mult) end
         end

         FN.SIM.simulate_joker(joker, FN.SIM.get_context(G.jokers, {global = true}))

         -- Joker-on-joker effects (eg. Blueprint):
         FN.SIM.simulate_all_jokers(G.jokers, {other_joker = joker})

         if joker.edition then -- Poly:
            if joker.edition.x_mult then FN.SIM.x_mult(joker.edition.x_mult) end
         end
      end
   end

   function FN.SIM.simulate_consumable_effects()
      for _, consumable in ipairs(FN.SIM.env.consumables) do
         if consumable.ability.set == "Planet" and not consumable.debuff then
            if G.GAME.used_vouchers.v_observatory and consumable.ability.consumeable.hand_type == FN.SIM.env.scoring_name then
               FN.SIM.x_mult(G.P_CENTERS.v_observatory.config.extra)
            end
         end
      end
   end

   function FN.SIM.add_base_chips_and_mult()
      local played_hand_data = G.GAME.hands[FN.SIM.env.scoring_name]
      FN.SIM.add_chips(played_hand_data.chips)
      FN.SIM.add_mult(played_hand_data.mult)
   end

   function FN.SIM.simulate_joker_before_effects()
      for _, joker in ipairs(FN.SIM.env.jokers) do
         FN.SIM.simulate_joker(joker, FN.SIM.get_context(G.jokers, {before = true}))
      end
   end

   function FN.SIM.simulate_blind_effects()
      if G.GAME.blind.disabled then return end

      if G.GAME.blind.name == "The Flint" then
         FN.SIM.misc.blind_triggered = true -- See Blind:modify_hand(..); relevant for Matador
         local function flint(data)
            local half_chips = math.floor(data.chips/2 + 0.5)
            local half_mult = math.floor(data.mult/2 + 0.5)
            data.chips = mod_chips(math.max(half_chips, 0))
            data.mult  = mod_mult(math.max(half_mult, 1))
         end

         flint(FN.SIM.running.min)
         flint(FN.SIM.running.exact)
         flint(FN.SIM.running.max)
      else
         -- Other blinds do not impact scoring; refer to Blind:modify_hand(..)
      end
   end

   function FN.SIM.simulate_deck_effects()
      if G.GAME.selected_back.name == 'Plasma Deck' then
         local function plasma(data)
            local sum = data.chips + data.mult
            local half_sum = math.floor(sum/2)
            data.chips = mod_chips(half_sum)
            data.mult = mod_mult(half_sum)
         end

         plasma(FN.SIM.running.min)
         plasma(FN.SIM.running.exact)
         plasma(FN.SIM.running.max)
      else
         -- Other decks do not impact scoring; refer to Back:trigger_effect(..)
      end
   end

   function FN.SIM.simulate_blind_debuffs()
      -- NOTE: `FN.SIM.misc.blind_triggered` mirrors `G.GAME.blind.triggered`, which decides whether
      --       Matador pays out. It is tracked separately so the real blind is never modified.
      FN.SIM.misc.blind_triggered = false

      local blind_obj = G.GAME.blind
      if blind_obj.disabled then return false end

      -- The following are part of Blind:press_play()
      -- NOTE: The Hook is handled separately, see FN.SIM.simulate_hook()
      -- NOTE: press_play() marks the blind as triggered, but Blind:debuff_hand(..) always resets
      --       that flag before jokers are evaluated, so Matador does NOT pay out for these.

      if blind_obj.name == "The Tooth" then
         FN.SIM.add_dollars((-1) * #FN.SIM.env.played_cards)
      end

      -- The following are part of Blind:debuff_hand(..)

      if blind_obj.name == "The Arm" then
         local played_hand_name = FN.SIM.env.scoring_name
         if G.GAME.hands[played_hand_name].level > 1 then
            FN.SIM.misc.blind_triggered = true
            -- NOTE: Important to save/restore G.GAME.hands here
            -- NOTE: Implementation mirrors level_up_hand(..)
            local played_hand_data = G.GAME.hands[played_hand_name]
            played_hand_data.level = math.max(1, played_hand_data.level - 1)
            played_hand_data.mult  = math.max(1, played_hand_data.s_mult  + (played_hand_data.level-1) * played_hand_data.l_mult)
            played_hand_data.chips = math.max(0, played_hand_data.s_chips + (played_hand_data.level-1) * played_hand_data.l_chips)
         end
         return false -- IMPORTANT: Avoid duplicate effects from Blind:debuff_hand() below
      end

      if blind_obj.name == "The Ox" then
         if FN.SIM.env.scoring_name == G.GAME.current_round.most_played_poker_hand then
            FN.SIM.misc.blind_triggered = true
            -- Money is set to exactly $0 (which is a gain when in debt):
            FN.SIM.add_dollars(-G.GAME.dollars)
         end
         return false -- IMPORTANT: Avoid duplicate effects from Blind:debuff_hand() below
      end

      -- Blind:debuff_hand(..) sets the blind's triggered flag as a side effect, even when only checking.
      -- NOTE: The real flag is put back by FN.SIM.manage_state("RESTORE")
      local is_debuffed = blind_obj:debuff_hand(G.hand.highlighted, FN.SIM.env.poker_hands, FN.SIM.env.scoring_name, true)
      FN.SIM.misc.blind_triggered = (blind_obj.triggered and true) or false

      return is_debuffed
   end

   --
   -- THE HOOK:
   --

   function FN.SIM.is_hook_active()
      return G.GAME.blind.name == "The Hook" and not G.GAME.blind.disabled
   end

   -- The Hook discards 2 random held cards (or as many as are held) after the hand is played but
   -- before it is scored; see Blind:press_play(). Which cards get discarded cannot be known, so
   -- every possible discard is simulated and the overall minimum and maximum are reported.
   function FN.SIM.simulate_hook()
      local snapshot = FN.SIM.snapshot_env()
      local num_held = #snapshot.held_cards
      local num_discards = math.min(2, num_held)

      local combinations = {}
      if num_discards == 0 then
         table.insert(combinations, {})
      elseif num_discards == 1 then
         table.insert(combinations, {1})
      else
         for a = 1, num_held - 1 do
            for b = a + 1, num_held do
               table.insert(combinations, {a, b})
            end
         end
      end

      local min_score, max_score = math.huge, -math.huge
      local min_dollars, max_dollars = math.huge, -math.huge

      for _, discard_idxs in ipairs(combinations) do
         -- Jokers and cards get modified while simulating, so start every discard from a clean slate:
         FN.SIM.restore_env(snapshot)
         FN.SIM.reset_running()

         -- Blind:press_play() marks The Hook as triggered, but Blind:debuff_hand(..) resets that flag
         -- before any joker is evaluated, so Matador does NOT pay out because of The Hook itself:
         FN.SIM.misc.blind_triggered = false

         -- Split held cards into discarded and kept cards, both in hand order:
         local is_discarded = {}
         for _, idx in ipairs(discard_idxs) do is_discarded[idx] = true end
         local kept_cards, discarded_cards = {}, {}
         for i, card in ipairs(FN.SIM.env.held_cards) do
            table.insert(is_discarded[i] and discarded_cards or kept_cards, card)
         end
         FN.SIM.env.held_cards = kept_cards

         -- Joker effects on discard (eg. Mail-In Rebate); see G.FUNCS.discard_cards_from_highlighted(..)
         for _, card in ipairs(discarded_cards) do
            FN.SIM.simulate_all_jokers(G.hand, {discard = true, other_card = card, full_hand = discarded_cards})
         end

         FN.SIM.simulate_hand()

         local res = FN.SIM.get_results()
         min_score = math.min(min_score, res.score.min)
         max_score = math.max(max_score, res.score.max)
         min_dollars = math.min(min_dollars, res.dollars.min)
         max_dollars = math.max(max_dollars, res.dollars.max)
      end

      -- Overwrite final min/max range based on all possible discards:
      -- NOTE: FN.SIM.running.exact is left as the last simulated discard; an exact result cannot be known here
      FN.SIM.running.min = {chips = min_score, mult = 1, dollars = min_dollars}
      FN.SIM.running.max = {chips = max_score, mult = 1, dollars = max_dollars}
   end

   function FN.SIM.snapshot_env()
      local env = FN.SIM.env

      -- Scoring cards are the same objects as (some of) the played cards; remember which ones:
      local scoring_idxs = {}
      for _, scoring_card in ipairs(env.scoring_cards) do
         for i, played_card in ipairs(env.played_cards) do
            if played_card == scoring_card then
               table.insert(scoring_idxs, i)
               break
            end
         end
      end

      return {
         jokers = copy_table(env.jokers),
         played_cards = copy_table(env.played_cards),
         held_cards = copy_table(env.held_cards),
         scoring_idxs = scoring_idxs
      }
   end

   function FN.SIM.restore_env(snapshot)
      local env = FN.SIM.env
      env.jokers = copy_table(snapshot.jokers)
      env.played_cards = copy_table(snapshot.played_cards)
      env.held_cards = copy_table(snapshot.held_cards)
      env.scoring_cards = {}
      for _, idx in ipairs(snapshot.scoring_idxs) do
         table.insert(env.scoring_cards, env.played_cards[idx])
      end
   end

   --
   -- MICRO LEVEL (CARDS):
   --

   function FN.SIM.simulate_card_in_context(card, cardarea)
      -- Reset and collect repetitions:
      FN.SIM.running.reps = 1
      if card.seal == "Red" then FN.SIM.add_reps(1) end
      FN.SIM.simulate_all_jokers(cardarea, {other_card = card, repetition = true})

      -- Apply effects:
      for _ = 1, FN.SIM.running.reps do
         FN.SIM.simulate_card(card, FN.SIM.get_context(cardarea, {}))
         FN.SIM.simulate_all_jokers(cardarea, {other_card = card, individual = true})
      end
   end

   function FN.SIM.simulate_card(card_data, context)
      -- Do nothing if debuffed:
      if card_data.debuff then return end

      if context.cardarea == G.play then
         -- Chips:
         if card_data.ability.effect == "Stone Card" then
            FN.SIM.add_chips(card_data.ability.bonus + (card_data.ability.perma_bonus or 0))
         else
            FN.SIM.add_chips(card_data.base_chips + card_data.ability.bonus + (card_data.ability.perma_bonus or 0))
         end

         -- Mult:
         if card_data.ability.effect == "Lucky Card" then
            local exact_mult, min_mult, max_mult = FN.SIM.get_probabilistic_extremes(pseudorandom("nope"), 5, card_data.ability.mult, 0)
            FN.SIM.add_mult(exact_mult, min_mult, max_mult)
            -- Careful not to overwrite `card_data.lucky_trigger` outright:
            if exact_mult > 0 then card_data.lucky_trigger.exact = true end
            if min_mult > 0 then card_data.lucky_trigger.min = true end
            if max_mult > 0 then card_data.lucky_trigger.max = true end
         else
            FN.SIM.add_mult(card_data.ability.mult)
         end

         -- XMult:
         if card_data.ability.x_mult > 1 then
            FN.SIM.x_mult(card_data.ability.x_mult)
         end

         -- Dollars:
         if card_data.seal == "Gold" then
            FN.SIM.add_dollars(3)
         end
         if card_data.ability.p_dollars > 0 then
            if card_data.ability.effect == "Lucky Card" then
               local exact_dollars, min_dollars, max_dollars = FN.SIM.get_probabilistic_extremes(pseudorandom("notthistime"), 15, card_data.ability.p_dollars, 0)
               FN.SIM.add_dollars(exact_dollars, min_dollars, max_dollars)
               -- Careful not to overwrite `card_data.lucky_trigger` outright:
               if exact_dollars > 0 then card_data.lucky_trigger.exact = true end
               if min_dollars > 0 then card_data.lucky_trigger.min = true end
               if max_dollars > 0 then card_data.lucky_trigger.max = true end
            else
               FN.SIM.add_dollars(card_data.ability.p_dollars)
            end
         end

      -- Edition:
         if card_data.edition then
            if card_data.edition.chips then FN.SIM.add_chips(card_data.edition.chips) end
            if card_data.edition.mult then FN.SIM.add_mult(card_data.edition.mult) end
            if card_data.edition.x_mult then FN.SIM.x_mult(card_data.edition.x_mult) end
         end

      elseif context.cardarea == G.hand then
         if card_data.ability.h_mult > 0 then
            FN.SIM.add_mult(card_data.ability.h_mult)
         end

         if card_data.ability.h_x_mult > 0 then
            FN.SIM.x_mult(card_data.ability.h_x_mult)
         end
      end
   end

   --
   -- MICRO LEVEL (JOKERS):
   --

   function FN.SIM.simulate_all_jokers(cardarea, context_args)
      for _, joker in ipairs(FN.SIM.env.jokers) do
         FN.SIM.simulate_joker(joker, FN.SIM.get_context(cardarea, context_args))
      end
   end

   function FN.SIM.simulate_joker(joker_obj, context)
      -- Do nothing if debuffed:
      if joker_obj.debuff then return end

      local joker_simulation_function = FN.SIM.JOKERS["simulate_" .. joker_obj.id]
      if joker_simulation_function then joker_simulation_function(joker_obj, context) end
   end

end
