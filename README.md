# CruS Mod Base
Adds useful modding things (in the future) and custom level support.

Requires the [CRUELTY SQUAD MOD LOADER](https://github.com/crustyrashky/crus-modloader)

## Features

- Custom level support
- Button in settings that tells you what mods you have installed

## Install

1. Download the [latest release](https://github.com/crustyrashky/crus-modbase/releases/download/0.1.1/crus-modbase.zip)
2. Extract the `CruS Mod Base` folder to  `%appdata%\Godot\app_userdata\Cruelty Squad\mods`

## Adding custom levels

1. Download a level, like [this one](https://github.com/crustyrashky/crus-modbase/releases/download/0.1.1/SinSpaceExtended.zip)
2. Extract its folder to `%appdata%\Godot\app_userdata\Cruelty Squad\levels`
   - This folder is created automatically if you run the game with the mod installed, or you can create it yourself

## Level config JSON properties

- File paths are strings starting with `user://` (Godot equivalent of `%appdata%\Godot\app_userdata\Cruelty Squad\`) or `res://` (game files)
  - You can just write the file name if it's in its own level directory (e.g. `user://levels/MyLevel/dialogue.json` can be shortened to `dialogue.json`)

### Required

- `author` - String
  - Level author
- `version` - String
  - Level version
- `description` - String
  - The description that appears in-game when you select a level
- `objectives` - String[]
  - The objectives that appear in-game when you select a level
- `level_scene` - File path (.tscn)
  - The actual Godot scene file containing the level

### Optional

- `name` - String
  - Name of the level. Defaults to whatever the name of the mod's directory is
- `image` - File path (.png)
  - 240x240 image used for both the level icon and preview image in-game
- `music` - File path (.ogg)
  - Level music
- `ambience` - File path (.ogg)
  - If given, this music will play when not in combat
- `dialogue` - File path (.json containing a String[]) or String[] or whole number
  - Lines that NPCs in the level will say. If a whole number is given, the dialogue of the level corresponding to that number will be used.
  - Default: `["…"]`
- `reward` - Number
  - Money reward for clearing the level, default 0
- `fish` - String[]
  - Fish that can be caught in the level. Make sure to use the fish tickers and not their actual name (i.e. write `["WOF ", "HDRA"]` and not `["Wheel of Fortune", "Hydra"]`)
  - Defaults to `["FISH", "DEAD"]` if none are specified
- `ranks` - `{ "normal", "normal_stock_s", "hell", "hell_stock_s" }`
  - All values default to 0
  - `normal` - Number[3]
    - S, A and B rank normal thresholds in milliseconds
  - `normal_stock_s` - Number
    - S rank normal stock weapons threshold in milliseconds
  - `hell` - Number[3]
    - S, A and B rank cursed thresholds in milliseconds
  - `hell_stock_s` - Number
    - S rank cursed stock threshold in milliseconds

## Credits

a1337spy for the next and previous page buttons

Uggo for the Sin Space Extended sample map

Consumer Softproducts for granting me express permission to distribute the game's source code in these mods for non-commercial use

https://github.com/Gianclgar/ for the GDAudioScriptImport.gd script 
