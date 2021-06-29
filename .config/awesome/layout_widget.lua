local wibox = require("wibox")

local layout_widget = {}

setmetatable(layout_widget, wibox.widget.textbox)
layout_widget.__index = wibox.widget.textbox

function layout_widget:new(screen)
	o = {}
	setmetatable(o, self)
	self.__index = self
	o.widget = wibox.widget.textbox()
	o.screen = screen
	o:update()
	return o
end

function layout_widget:update()
	self.widget.text = self.screen.selected_tag.layout.name
	--self.widget.text = "hi"
end

return layout_widget
