extends RichTextLabel

var cheats = null
var active = false
var already_paused = false

func _input(ev):
	if ev is InputEventKey and ev.is_pressed() and is_instance_valid(cheats):
		if Global.menu.visible:
			active = false
			self.hide()
			get_tree().paused = true
		else:
			if ev.get_scancode() == KEY_QUOTELEFT:
				raise()
				active = !active
			if ev.get_scancode() == KEY_ENTER:
				active = false
				get_tree().paused = false
				self.hide()
				match text.substr(2):
					"NOCLIP":
						Global.player.UI.notify("Noclip activated, press Shift-N to toggle", Color(1, 0, 1))
						cheats.enabled.append("noclip")
						cheats.reset_noclip()
					"ZOMBIE":
						cheats.toggle_zombie()
					"PSYCHOPASS":
						cheats.toggle_vanish()
					"MAGPUMP":
						cheats.toggle_infinite_magazine()
					"HOPTOIT":
						cheats.toggle_infinite_jump()
					"KITTED":
						cheats.toggle_infinite_arm_aug()
					"LIGHTSOUT":
						cheats.toggle_disable_ai()
					"SOULSWAP":
						cheats.toggle_death()
					"FRIDAY":
						cheats.toggle_npc_ffa()
					"PLEROMA":
						cheats.enable_debug_menus()
				self.text = "> "
				
			get_tree().paused = active
			self.visible = active
		if active:
			var key = ev.as_text()
			if len(key) == 1:
				self.text += key
			if ev.get_scancode() == KEY_SPACE:
				self.text += " "
			if ev.get_scancode() == KEY_BACKSPACE:
				if self.text.length() > 2:
					self.text = self.text.substr(0, self.text.length() - 1)
