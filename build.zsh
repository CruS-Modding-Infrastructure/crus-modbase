#!zsh

local cbase=/mnt/c/csquad

local proj=${cbase}/project \
      repo=/mnt/c/Users/disk0/git.local/crus-modbase/crus-modbase.disco0 \
      comp=${cbase}/export/modbase

if [[ ! -d $proj || ! -d $repo || ! -d $comp ]]
then
    builtin print -Pu2 -l -- "%F{1}Missing one or more required directories:" \
                        $proj $repo
    return 2
fi

function winpath() { [[ $WSLENV ]] && wslpath -m $1 || builtin print -n $1 }

# Rebuild artifacts
local out_zip=${cbase}/export/modbase.zip
local zip_dir=${out_zip:r}
local godot_path=/mnt/c/tools/bin/godot.exe
$godot_path --path "$(winpath $proj)" \
            --no-window \
            --export-pack modbase \
            --export-path "$(winpath $out_zip)" \
&& command 7z x $out_zip -o"${zip_dir}" -y || {
    builtin print -Pu2 -- "%F{1}Error during artifacts build/expansion.%f"
    return
}

{
    # NOTE: Repeat of same files between MOD_CONTENT copies, might be issue?

    builtin print -Pu2 -- '%F{32}Synching sources%f'                                  &&
    command cp -f -r -v $proj/MOD_CONTENT/CruS\ Mod\ Base $repo/MOD_CONTENT/          &&
    command cp -f -r -v {$proj,$repo}/Menu_Test.gd                                    &&
    command cp -f -r -v {$proj,$repo}/Entities/Game_Manager.gd                        &&
    command cp -f -r -v {$proj,$repo}/Scripts/Cutscene.gd                             &&
    command cp -f -r -v {$proj,$repo}/Menu/Settings_Grid.gd                           &&
    command cp -f -r -v {$proj,$repo}/addons/qodot/src/nodes/qodot_map.gd             &&
    command cp -f -r -v {$proj,$repo}/addons/qodot/src/util/qodot_texture_loader.gd   &&
    builtin print -Pu2 -- '%F{32}Syncing artifacts%f'                                 &&
    command cp --update -f -r -v $comp/MOD_CONTENT/CruS\ Mod\ Base $repo/MOD_CONTENT/ &&
    command cp -f -r -v {$comp,$repo}/Menu_Test.gdc                                   &&
    command cp -f -r -v {$comp,$repo}/Entities/Game_Manager.gdc                       &&
    command cp -f -r -v {$comp,$repo}/Scripts/Cutscene.gdc                            &&
    command cp -f -r -v {$comp,$repo}/Menu/Settings_Grid.gdc                          &&
    command cp -f -r -v {$comp,$repo}/addons/qodot/src/nodes/qodot_map.gdc            &&
    command cp -f -r -v {$comp,$repo}/addons/qodot/src/util/qodot_texture_loader.gdc

} | while { read line } {
    print -P -- ${${line[2,-2]//$PWD/${(%):-$'%~'}}//\' -> \'/$'\n' -> %F\{32\}}"%f"
}

# Run powershell packaging script while we're here
pwsh.exe -NoProfile -NoLogo ./build.ps1