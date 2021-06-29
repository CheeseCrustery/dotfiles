pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful") -- Standard awesome library
require("awful.autofocus")
local wibox = require("wibox") -- Widget and layout library
local beautiful = require("beautiful") -- Theme handling library
local naughty = require("naughty") -- Notification library
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys") -- Enable hotkeys help widget for VIM and other apps
local debian = require("debian.menu") -- Load Debian menu entries
local has_fdo, freedesktop = pcall(require, "freedesktop")
require("email")
local volume_widget = require('awesome-wm-widgets.volume-widget.volume')


--------------------------------------------------------------------------------
-- ERROR HANDLING
--------------------------------------------------------------------------------

if awesome.startup_errors then
	naughty.notify({ preset = naughty.config.presets.critical,
					 title = "Oops, there were errors during startup!",
					 text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
	local in_error = false
	awesome.connect_signal("debug::error", function (err)
		-- Make sure we don't go into an endless error loop
		if in_error then return end
		in_error = true

		naughty.notify({ preset = naughty.config.presets.critical,
						 title = "Oops, an error happened!",
						 text = tostring(err) })
		in_error = false
	end)
end


--------------------------------------------------------------------------------
-- VARIABLES
--------------------------------------------------------------------------------

modkey = "Mod4"
alt = "Mod1"
terminal = "x-terminal-emulator"
editor = os.getenv("EDITOR") or "editor"
editor_cmd = terminal .. " -e " .. editor

-- Theme
beautiful.init(gears.filesystem.get_configuration_dir() .. "themes/custom/theme.lua")


-------------------------------------------------------------------------------
-- SCREEN SETUP
-------------------------------------------------------------------------------

-- Keyboard layout widget
awful.spawn.with_shell("setxkbmap -option 'grp:alt_shift_toggle' -layout us,de -variant euro")
mykeyboardlayout = awful.widget.keyboardlayout()

-- Textclock widget
mytextclock = wibox.widget.textclock()

-- Taglist widget controls
local taglist_buttons = gears.table.join(
	awful.button({ }, 1, function(t) t:view_only() end),
	awful.button({ modkey }, 1,
		function(t)
			if client.focus then
				client.focus:move_to_tag(t)
			end
		end),
	awful.button({ }, 3, awful.tag.viewtoggle),
	awful.button({ modkey }, 3,
		function(t)
			if client.focus then
				client.focus:toggle_tag(t)
			end
		end),
	awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
	awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

local function set_wallpaper(s)
	-- Wallpaper
	if beautiful.wallpaper then
		local wallpaper = beautiful.wallpaper
		-- If wallpaper is a function, call it with the screen
		if type(wallpaper) == "function" then
			wallpaper = wallpaper(s)
		end
		gears.wallpaper.maximized(wallpaper, s)
	end
end

-- Re-set wallpaper when a screen's geometry changes
screen.connect_signal("property::geometry", set_wallpaper)

-- Individual screen configuration
awful.screen.connect_for_each_screen(function(s)
	
	-- Wallpaper
	set_wallpaper(s)

	-- Layouts
	local l = awful.layout.suit
	if s.index == 1 then
		s.layouts = {
			l.tile,
			l.fair,
			l.spiral.dwindle,
			l.corner.nw
		}
	else
		s.layouts = {
			l.tile.bottom,
			l.fair.horizontal,
			l.spiral.dwindle,
			l.corner.nw
		}
	end

	-- Each screen has its own tag table.
	awful.tag(
		{ "1", "2", "3", "4", "5", "6", "7", "8", "9" },
		s,
		s.layouts[1]
	)

	-- Layout blocklet
	s.mylayoutbox = awful.widget.layoutbox(s)
	s.mylayoutbox:buttons(gears.table.join(
		awful.button({ }, 1, function () awful.layout.inc(1, s, s.layouts) end),
		awful.button({ }, 3, function () awful.layout.inc(-1, s, s.layouts) end),
		awful.button({ }, 4, function () awful.layout.inc(1, s, s.layouts) end),
		awful.button({ }, 5, function () awful.layout.inc(-1, s, s.layouts) end))
	)

	-- Taglist blocklet
	s.mytaglist = awful.widget.taglist {
		screen  = s,
		filter  = awful.widget.taglist.filter.all,
		buttons = taglist_buttons
	}

	-- Wibar
	s.mywibar = awful.wibar({ position = "bottom", screen = s })
	s.mywibar:setup {
		layout = wibox.layout.align.horizontal,
		{
			-- Left widgets
			layout = wibox.layout.fixed.horizontal,
			s.mytaglist,
			s.mypromptbox,
		},
		{
			-- Center widgets
			layout = wibox.layout.fixed.horizontal,
			wibox.container.background()
		},
		{
			-- Right widgets
			layout = wibox.layout.fixed.horizontal,
			wibox.widget.systray(),
			mykeyboardlayout,
			email_icon,
			email_widget,
			volume_widget(),
			mytextclock,
			s.mylayoutbox,
		},
	}
end)


--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

-- Spawn process in current screen and move focus to window
function new_window(cmd)
	local id = awful.spawn.spawn(cmd, {screen=awful.screen.focused()})
	if type(id) == "number" then
		-- All good, we have a process id
		for c in awful.client.iterate(function(c) return c.pid == id end) do
			move_mouse_onto_client(c)
		end
	else
		-- Whoops, we got an error message
		naughty.notify({
			preset = naughty.config.presets.critical,
			title = "Error while spawning '" .. cmd .. "'!",
			text = id
		})
	end
end


-- Global keybindings
globalkeys = gears.table.join(
	
	-- Volume
	awful.key({ }, "XF86AudioRaiseVolume", function() awful.spawn("amixer set Master 5%+"); volume_widget:inc() end),
	awful.key({ }, "XF86AudioLowerVolume", function() awful.spawn("amixer set Master 5%-"); volume_widget:inc() end),
	
	-- System
	awful.key({ modkey, alt }, "s", function() awful.spawn.with_shell("systemctl suspend") end, {description="suspend", group="system"}),
	awful.key({ modkey, alt }, "d", function() awful.spawn.with_shell("systemctl poweroff") end, {description="shutdown", group="system"}),
	awful.key({ modkey, alt }, "r", function() awful.spawn.with_shell("systemctl reboot") end, {description="reboot", group="system"}),
	
	-- Awesome
	awful.key({ modkey, "Control" }, "r",
		function ()
			awful.spawn.easy_async_with_shell("parser", function()
				awful.spawn.easy_async_with_shell("xrandrsetup", awesome.restart)
			end)
		end,
		{description = "reload awesome", group = "awesome"}),
	awful.key({ modkey }, "x",
		function ()
			awful.prompt.run {
				prompt = "Run Lua code: ",
				textbox = awful.screen.focused().mypromptbox.widget,
				exe_callback = awful.util.eval,
				history_path = awful.util.get_cache_dir() .. "/history_eval"
			}
		end,
		{description = "lua execute prompt", group = "awesome"}),
	
	-- Launch programs
	awful.key({ modkey }, "Return", function () new_window(terminal) end, {description = "terminal", group = "programs"}),
	awful.key({ modkey }, "d", function () awful.spawn.spawn("dmenu_run -m 0 -nf '" .. beautiful.fg_normal .. "' -nb '" .. beautiful.bg_normal .. "' -sf '" .. beautiful.fg_focus .. "' -sb '" .. beautiful.bg_focus .. "'") end, {description = "dmenu", group = "programs"}),
	awful.key({ modkey }, "b", function () new_window("vivaldi-stable") end, {description = "vivaldi", group = "programs"}),
	awful.key({ modkey }, "r", function () new_window(terminal .. " -e ranger") end, {description = "ranger", group = "programs"}),
	awful.key({ modkey }, "s", hotkeys_popup.show_help, {description = "hotkey help", group = "programs"}),
	
	-- Focus
	awful.key({ modkey }, "h",
		function ()
			client.focus = awful.client.getmaster()
			client.focus:raise()
			move_mouse_onto_client()
		end,
		{description = "master", group = "focus"}),
	awful.key({ modkey }, "j",
		function ()
			awful.client.focus.byidx(1)
			move_mouse_onto_client()
		end,
		{description = "next client by index", group = "focus"}),
	awful.key({ modkey }, "k",
		function ()
			awful.client.focus.byidx(-1)
			move_mouse_onto_client()
		end,
		{description = "previous client by index", group = "focus"}),
	awful.key({ modkey }, "l", function () awful.screen.focus_relative(1) end, {description = "next screen", group = "focus"}),

	-- Tag
	awful.key({ modkey, alt }, "h", awful.tag.viewprev, {description = "view previous", group = "tag"}),
	awful.key({ modkey, alt }, "l", awful.tag.viewnext, {description = "view next", group = "tag"}),

	-- Move client
	awful.key({ modkey, "Shift" }, "j",	function ()	awful.client.swap.byidx(1) end, {description = "to lower priority", group = "move"}),
	awful.key({ modkey, "Shift" }, "k",	function ()	awful.client.swap.byidx(-1) end, {description = "to higher priority", group = "move"}),
	
	awful.key({ modkey, "Control" }, "n",
		function ()
			local c = awful.client.restore()
			-- Focus restored client
			if c then
				c:emit_signal(
					"request::activate", "key.unminimize", {raise = true}
				)
			end
		end,
		{description = "restore minimized", group = "client"}),

	-- Layout
	awful.key({ modkey, "Control" }, "h", function () awful.tag.incmwfact(-0.05) end, {description = "decrease master size", group = "layout"}),
	awful.key({ modkey, "Control" }, "j", function () awful.layout.inc(1, awful.screen.focused(), awful.screen.focused().layouts) end, {description = "previous layout", group = "layout"}),
	awful.key({ modkey, "Control" }, "k", function () awful.layout.inc(1, awful.screen.focused(), awful.screen.focused().layouts) end, {description = "next layout", group = "layout"}),
	awful.key({ modkey, "Control" }, "l", function () awful.tag.incmwfact(0.05) end, {description = "increase master size", group = "layout"})
)

-- Bind all key numbers to tags
for i = 1, 9 do
	globalkeys = gears.table.join(globalkeys,
		-- View tag
		awful.key({ modkey }, "#" .. i + 9,
			function ()
				local screen = awful.screen.focused()
				local tag = screen.tags[i]
				if tag then
					tag:view_only()
				end
			end,
			{description = "view tag #"..i, group = "tag"}),
		-- Toggle tag display
		awful.key({ modkey, "Control" }, "#" .. i + 9,
			function ()
				local screen = awful.screen.focused()
				local tag = screen.tags[i]
				if tag then
					awful.tag.viewtoggle(tag)
				end
			end,
			{description = "toggle tag #" .. i, group = "tag"}),
		-- Move client to tag
		awful.key({ modkey, "Shift" }, "#" .. i + 9,
			function ()
				if client.focus then
					local tag = client.focus.screen.tags[i]
					if tag then
						client.focus:move_to_tag(tag)
					end
				end
			end,
			{description = "move focused client to tag #"..i, group = "tag"}),
		-- Toggle tag on focused client
		awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
			function ()
				if client.focus then
					local tag = client.focus.screen.tags[i]
					if tag then
						client.focus:toggle_tag(tag)
					end
				end
			end,
			{description = "toggle focused client on tag #" .. i, group = "tag"})
	)
end

-- Set global keybindings
root.keys(globalkeys)

-- Global mouse actions
root.buttons(gears.table.join(
	awful.button({ }, 3, function () awful.spawn.spawn("dmenu_run -m 0 -nf '" .. beautiful.fg_normal .. "' -nb '" .. beautiful.bg_normal .. "' -sf '" .. beautiful.fg_focus .. "' -sb '" .. beautiful.bg_focus .. "'") end),
	awful.button({ }, 4, awful.tag.viewnext),
	awful.button({ }, 5, awful.tag.viewprev)
))

-- Client hotkeys
clientkeys = gears.table.join(

	-- Close, but keep mouse position and focus
	awful.key({ modkey }, "c", function (c)
		c:kill()
		if mouse.current_client then
			naughty.notify({text=tostring(c)})
			client.focus = mouse.current_client
			client.focus:raise()
		end
	end, {description = "close", group = "client"}),

	-- Move
	awful.key({ modkey, "Shift" }, "h",
		function (c)
			c:swap(awful.client.getmaster())
			--c:emit_signal("swapped", c, awful.client.getmaster())
		end,
		{description = "to master", group = "move"}),
	awful.key({ modkey, "Shift" }, "l", function (c) c:move_to_screen() end, {description = "to next screen", group = "move"}),

	-- Toggle
	awful.key({ modkey, "Control" }, "space", awful.client.floating.toggle, {description = "toggle floating", group = "client"}),
	awful.key({ modkey }, "t", function (c) c.ontop = not c.ontop end, {description = "toggle keep on top", group = "client"}),
	
	-- Maximize / minimize
	awful.key({ modkey }, "f",
		function (c)
			c.maximized = not c.maximized
			c:raise()
		end,
		{description = "toggle maximize", group = "client"}),
	awful.key({ modkey, "Control" }, "f",
		function (c)
			c.maximized_vertical = not c.maximized_vertical
			c:raise()
		end,
		{description = "toggle vertical maximize", group = "client"}),
	awful.key({ modkey, "Shift" }, "f",
		function (c)
			c.maximized_horizontal = not c.maximized_horizontal
			c:raise()
		end,
		{description = "toggle horizontal maximize", group = "client"}),
	awful.key({ modkey }, "n", function (c) c.minimized = true end,	{description = "minimize", group = "client"})
)

-- Client mouse actions
clientbuttons = gears.table.join(

	-- Left click to focus
	awful.button({ }, 1, function (c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
	end),

	-- Mod + Left click to move
	awful.button({ modkey }, 1, function (c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
		awful.mouse.client.move(c)
	end),

	-- Mod + Right click to resize
	awful.button({ modkey }, 2, function (c)
		c:emit_signal("request::activate", "mouse_click", {raise = true})
		awful.mouse.client.resize(c)
	end)
)


--------------------------------------------------------------------------------
-- CLIENT RULES
--------------------------------------------------------------------------------

awful.rules.rules = {

	-- All clients
	{
		rule = { },
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			raise = true,
			keys = clientkeys,
			buttons = clientbuttons,
			screen = awful.screen.preferred,
			placement = awful.placement.no_overlap+awful.placement.no_offscreen
		}
	},

	-- Automatically float clients
	{
		rule_any = {
			instance = {
				"DTA",  -- Firefox addon DownThemAll.
				"copyq",  -- Includes session name in class.
				"pinentry"
			},
			class = {
				"Arandr",
				"Blueman-manager",
				"Gpick",
				"Kruler",
				"MessageWin",  -- kalarm.
				"Sxiv",
				"Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
				"Wpa_gui",
				"veromix",
				"xtightvncviewer"
			},
			name = {
				"Event Tester"  -- xev.
			},
			role = {
				"AlarmWindow",  -- Thunderbird's calendar.
				"ConfigManager",  -- Thunderbird's about:config.
				"pop-up"       -- e.g. Google Chrome's (detached) Developer Tools.
			}
		},
		properties = {
			floating = true
		}
	},

	-- Add titlebars to normal clients and dialogs
	{
		rule_any = {
			type = { "normal", "dialog" }
		},
		properties = { titlebars_enabled = true }
	},

	-- Set Firefox to always map on the tag named "2" on screen 1.
	-- { rule = { class = "Firefox" },
	--   properties = { screen = 1, tag = "2" } },
}

--------------------------------------------------------------------------------
-- SIGNALS
--------------------------------------------------------------------------------

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
	-- Set the windows at the slave,
	-- i.e. put it at the end of others instead of setting it master.
	-- if not awesome.startup then awful.client.setslave(c) end

	if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
		-- Prevent clients from being unreachable after screen count changes.
		awful.placement.no_offscreen(c)
	end
end)

-- Focus follows mouse
client.connect_signal("mouse::enter", function(c)
	c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

-- Move the mouse if it's not already there
function move_mouse_onto_client(c, x_ratio, y_ratio)
	c = c or client.focus
	x_ratio = x_ratio or 0.5
	y_ratio = y_ratio or 0.5
	if x_ratio < 0 or x_ratio > 1 then x_ratio = 0.5 end
	if y_ratio < 0 or y_ratio > 1 then y_ratio = 0.5 end
	if mouse.object_under_pointer() ~= c then
		local geometry = c:geometry()
		local x = geometry.x + geometry.width * x_ratio
		local y = geometry.y + geometry.height * y_ratio
		mouse.coords({x = x, y = y}, true)
	end
end

-- Mouse follows focus; show border
client.connect_signal("focus", function(c)
	--naughty.notify({text="focus " .. tostring(c)})
	c.border_color = beautiful.border_focus
end)
client.connect_signal("unfocus", function(c)
	c.border_color = beautiful.border_normal
end)

-- The swap gets signaled to both clients, so only move to the unfocused one
client.connect_signal("swapped", function(c1, c2)
	--naughty.notify({text="swap"})
	if client.focus == c2 then
		move_mouse_onto_client(c1)
	else
		move_mouse_onto_client(c2)
	end
end)


--------------------------------------------------------------------------------
-- AUTOSTART
--------------------------------------------------------------------------------

awful.spawn.with_shell("compton")
awful.spawn.with_shell("xrandrsetup")
