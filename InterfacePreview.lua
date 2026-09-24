--- Original: Divvy's Preview for Balatro - Interface.lua
--
-- The user interface components that display simulation results.

-- Append node for preview text to the HUD:
local orig_hud = create_UIBox_HUD
function create_UIBox_HUD()
   local contents = orig_hud()
   -- If anything goes wrong, the game simply gets its regular HUD without the preview:
   FN.safe_call("HUD setup", FN.PRE.add_preview_to_hud, contents)
   return contents
end

function FN.PRE.add_preview_to_hud(contents)
   local hand_text_area = FN.PRE.find_hand_text_area(contents)
   if not hand_text_area then return end
   local rows = hand_text_area.nodes and hand_text_area.nodes[1] and hand_text_area.nodes[1].nodes
   if type(rows) ~= "table" then return end

   -- Build everything first, so that the HUD is only touched once nothing can fail anymore:
   local preview_container = FN.PRE.get_preview_container()
   table.insert(rows, preview_container)

   -- The HUD already reaches the bottom edge of the screen, so the money row must not make it taller.
   -- Make room by trimming the (mostly empty) row that shows the name of the selected poker hand:
   if G.SETTINGS.FN.preview_dollars then
      local hand_name_row = rows[1]
      if type(hand_name_row) == "table" and type(hand_name_row.config) == "table" and type(hand_name_row.config.minh) == "number" then
         hand_name_row.config.minh = math.max(0.6, hand_name_row.config.minh - FN.PRE.dollars_row_height)
      end
   end
end

-- Keybind: press "s" to calculate the score. There is no button, to keep the HUD short.
FN.PRE.calculate_key = "s"
local orig_key_press = Controller.key_press_update
function Controller:key_press_update(key, dt)
   orig_key_press(self, key, dt)
   FN.safe_call("calculate score keybind", FN.PRE.on_key_press, self, key)
end

function FN.PRE.on_key_press(self, key)
   if key ~= FN.PRE.calculate_key then return end
   if self.locks.frame or self.text_input_hook then return end
   if G.SETTINGS.paused or G.OVERLAY_MENU then return end
   if not FN.PRE.enabled() then return end
   if not (G.STATE == G.STATES.SELECTING_HAND or
           G.STATE == G.STATES.DRAW_TO_HAND or
           G.STATE == G.STATES.PLAY_TAROT)
   then return end
   FN.PRE.start_new_coroutine()
end

function FN.PRE.get_preview_container()
   -- The money row sits under the score. Its wrapper has no padding and the money text is small,
   -- so the HUD only grows by the height of that one line of text.
   local dollars_wrap = {n=G.UIT.R, config={id = "fn_pre_dollars_wrap", align = "cm"}, nodes={}}
   if G.SETTINGS.FN.preview_dollars then table.insert(dollars_wrap.nodes, FN.PRE.get_dollars_node()) end

   return {n=G.UIT.R, config={id = "fn_preview_container", align = "cm"}, nodes={
      {n=G.UIT.C, config={align = "cm"}, nodes={
         {n=G.UIT.R, config={id = "fn_pre_score_wrap", align = "cm", padding = G.SETTINGS.FN.preview_dollars and 0.05 or 0.1}, nodes={
            FN.PRE.get_score_node()
         }},
         dollars_wrap,
      }}
   }}
end


function FN.PRE.get_score_node()
   local text_scale = nil
   if true then text_scale = 0.5
   else text_scale = 0.75 end

   return {n = G.UIT.C, config = {id = "fn_pre_score", align = "cm"}, nodes={
              {n=G.UIT.O, config={id = "fn_pre_l", func = "fn_pre_score_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.score, ref_value = "l"}}, colours = {G.C.UI.TEXT_LIGHT}, shadow = true, float = true, scale = text_scale})}},
              {n=G.UIT.O, config={id = "fn_pre_r", func = "fn_pre_score_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.score, ref_value = "r"}}, colours = {G.C.UI.TEXT_LIGHT}, shadow = true, float = true, scale = text_scale})}},
   }}
end

function FN.PRE.find_hand_text_area(node)
   if node.config and node.config.id == "hand_text_area" then
      return node
   end
   if node.nodes then
      for _, child in ipairs(node.nodes) do
         local found = FN.PRE.find_hand_text_area(child, id)
         if found then return found end
      end
   end
   return nil
end

-- Net height that the money row adds to the HUD (its text, minus padding saved around the score):
FN.PRE.dollars_row_height = 0.25

function FN.PRE.get_dollars_node()
   local text_scale = 0.4
   local colour = FN.PRE.get_dollar_colour(0)

   return {n = G.UIT.C, config = {id = "fn_pre_dollars", align = "cm"}, nodes={
              {n=G.UIT.O, config={id = "fn_pre_dollars_l", func = "fn_pre_dollars_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.dollars, ref_value = "l"}}, colours = {colour}, shadow = true, float = true, scale = text_scale})}},
              {n=G.UIT.O, config={id = "fn_pre_dollars_r", func = "fn_pre_dollars_UI_set", object = DynaText({string = {{ref_table = FN.PRE.text.dollars, ref_value = "r"}}, colours = {colour}, shadow = true, float = true, scale = text_scale})}},
   }}
end

--
-- SETTINGS:
--

function FN.get_preview_settings_page()
   local function preview_score_toggle_callback(e)
      if not G.HUD then return end

      if G.SETTINGS.FN.preview_score then
         -- Preview was just enabled, so add preview node:
         G.HUD:add_child(FN.PRE.get_score_node(), G.HUD:get_UIE_by_ID("fn_pre_score_wrap"))
         FN.PRE.data = FN.PRE.simulate()
      else
         -- Preview was just disabled, so remove preview node:
         G.HUD:get_UIE_by_ID("fn_pre_score").parent:remove()
      end
      G.HUD:recalculate()
   end

   local function preview_dollars_toggle_callback(_)
      if not G.HUD then return end

      if G.SETTINGS.FN.preview_dollars then
         -- Preview was just enabled, so add preview node:
         G.HUD:add_child(FN.PRE.get_dollars_node(), G.HUD:get_UIE_by_ID("fn_pre_dollars_wrap"))
         FN.PRE.data = FN.PRE.simulate()
      else
         -- Preview was just disabled, so remove preview node:
         G.HUD:get_UIE_by_ID("fn_pre_dollars").parent:remove()
      end
      G.HUD:recalculate()
   end

   local function face_down_toggle_callback(_)
      if not G.HUD then return end

      FN.PRE.data = FN.PRE.simulate()
      G.HUD:recalculate()
   end

   return
      {n=G.UIT.ROOT, config={align = "cm", padding = 0.05, colour = G.C.CLEAR}, nodes={
          create_toggle({id = "score_toggle",
                         label = "Enable Score Preview",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "preview_score",
                         callback = preview_score_toggle_callback}),
          create_toggle({id = "dollars_toggle",
                         label = "Enable Money Preview",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "preview_dollars",
                         callback = preview_dollars_toggle_callback}),
          create_toggle({label = "Hide Preview if Any Card is Face-Down",
                         ref_table = G.SETTINGS.FN,
                         ref_value = "hide_face_down",
                         callback = face_down_toggle_callback})
      }}
end
