extends SceneTree
func _init():
    var config = ConfigFile.new()
    config.save("user://keybinds.cfg") # saving empty overrides it
    var dir = DirAccess.open("user://")
    dir.remove("keybinds.cfg")
    quit()
