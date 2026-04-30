local mp = require 'mp'

-- Active ontop quand la vidéo joue, le désactive quand elle est en pause
local function on_pause_change(name, value)
    if value then
        -- En pause
        mp.set_property_bool("ontop", false)
    else
        -- En lecture
        mp.set_property_bool("ontop", true)
    end
end

mp.observe_property("pause", "bool", on_pause_change)
