#!zsh

local proj=/mnt/c/csquad/project repo=/mnt/c/Users/disk0/git.local/crus-modbase/crus-modbase.disco0

if [[ ! -d $proj || ! -d $repo ]]
then
    print -Pu2 -l -- "%F{1}Missing either one or both required directories:" \
          $proj $repo
    return 2
fi

{ 
    command cp -f -r -v $proj/MOD_CONTENT/CruS\ Mod\ Base $repo/MOD_CONTENT/          &&
    command cp -f -r -v {$proj,$repo}/Menu_Test.gd                                    &&
    command cp -f -r -v {$proj,$repo}/Entities/Game_Manager.gd                        &&
    command cp -f -r -v {$proj,$repo}/Scripts/Cutscene.gd                             &&
    command cp -f -r -v {$proj,$repo}/addons/qodot/src/nodes/qodot_map.gd             &&
    command cp -f -r -v {$proj,$repo}/addons/qodot/src/util/qodot_texture_loader.gd
} | while { read line } {
    print -P -- ${${line[2,-2]//$PWD/${(%):-$'%~'}}//\' -> \'/$'\n' -> %F\{32\}}"%f"
}
