local Controls = require(script.Parent.Controls)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Store = require(script.Parent.Store)

Store.Init()
Hud.Init()
Menus.Init(Hud.Gui, Hud.Buttons)
Controls.Init()
