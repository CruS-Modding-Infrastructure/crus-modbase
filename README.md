# CruS Mod Base

Adds useful modding things (in the future), custom level support and more.

Requires the [CRUELTY SQUAD MOD LOADER](https://github.com/crustyrashky/crus-modloader)

## Features

- Custom level support
- Button in settings that tells you what mods you have installed
- Build custom levels right from TrenchBroom with minimal Godot use
- Cheats
- Take fun little snapshots of levels

## Install

1. Download the [latest release](https://github.com/CruS-Modding-Infrastructure/crus-modbase/releases)
2. Extract the `CruS Mod Base` folder to  `%appdata%\Godot\app_userdata\Cruelty Squad\mods`

## Adding custom levels

1. Download a level
2. Extract its folder to `%appdata%\Godot\app_userdata\Cruelty Squad\levels`
   - This folder is created automatically if you run the game with the mod installed, or you can create it yourself

## Where to find custom levels

Check out [CRUS.CC](https://crus.cc/maps/newest/) for all the released maps

See [this guide](https://hackmd.io/@OsM6oUcXSwG3mLNvTlPMZg/SkYQwbONu) if you want to make your own


- [Sin Space Extended](https://github.com/crustyrashky/crus-modbase/files/6559547/SinSpaceExtended.zip) by Uggo and Consumer Softproducts
- [Belgha Festival](https://github.com/crustyrashky/crus-modbase/files/6595422/Belgha_Festival_V1.3.zip) by oldmankai and Just_Matt
- [McMansion Estate](https://github.com/crustyrashky/crus-modbase/files/6949799/McMansion_Estate_V1.1.zip)
 by Oskodos and voxelectrica
- [Church Schizm](https://github.com/crustyrashky/crus-modbase/files/6985599/Church_Schizm_V1.0.zip) by Oskodos
- [dust2](https://github.com/crustyrashky/crus-modbase/files/7147188/dust2_v0.1.zip) ported by StookyPotato
- [Armed Men In A Building](https://github.com/crustyrashky/crus-modbase/files/7230712/level.zip) by ConsulCast
- [Financial Ruins](https://github.com/crustyrashky/crus-modbase/files/7333658/Financial.Ruins.-.Public.Release.V1.4.zip) by Keith Mason and Asaklair
- [Funko Factory](https://github.com/crustyrashky/crus-modbase/files/7240174/Funko_Factory.zip) by Ringo
   - Requires [Ringo's Mapping Enhancements for Cruelty Squad](https://github.com/Ringo5103/Ringos-Mapping-Enhancements-for-Cruelty-Squad) mod
- [Golf Resort](https://github.com/crustyrashky/crus-modbase/files/7886469/Golf.Resort.1.1.5.zip) by Keith Mason




## Cheats/Commands

When in-game, activate the command input by pressing the key under escape on US keyboards or ['/@] on UK layout keyboards. You can also use the F1 key.

`NOCLIP` - Enable noclip

- V to toggle noclip, Ctrl to fly downwards, Space to fly upwards, Shift-scroll to change flyspeed

`GOD` - God mode (no longer lose health when hit)

`INVISIBLE` - Hostile enemies will no longer target and/or damage you

`INFAMMO` - Infinite magazine

`JUMP` - Infinite gunkboost jumps, whether you have them equipped or not

`INFIMPLANT` - Infinite arm implant uses

`AI` - Toggle AI on/off 

`DEATHMODE` - Toggle life/death health

`FFA` - Toggle hostile AI going berserk

`DEBUGMENU` - Enable level debug menu

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

https://github.com/Matoking for making [this pull request](https://github.com/Shfty/qodot-plugin/pull/97), which my own fork of Qodot builds off of
