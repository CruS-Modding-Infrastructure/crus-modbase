#!zsh

#region Config

local cbase=/mnt/c/csquad

# (Assumes repo is script directory)
local repo=${0:A:h}
local proj=${cbase}/project
local comp=${cbase}/export/modbase
local godot_path=/mnt/c/tools/bin/godot.exe

#endregion Config

if [[ ! -d $proj || ! -d $repo || ! -d $comp ]]
then
    builtin print -Pu2 -l -- "%F{1}Missing one or more required directories:" \
                        $proj $repo
    return 2
fi

function winpath() { [[ $WSLENV ]] && wslpath -m $1 || builtin print -n $1 }

function rebuild-artifacts()
{
    # Rebuild artifacts
    local out_zip=${cbase}/export/modbase.zip
    local zip_dir=${out_zip:r}
    local -a godot_args=(
        --path "$(winpath $proj)"
        --no-window
        --export-pack modbase
        --export-path "$(winpath $out_zip)"
    )
    command $godot_path "${(@)^godot_args}" || {
        builtin print -Pu2 -- "%F{1}Error during artifacts build%f"
        return 1
    }

    command 7z x $out_zip -o"${zip_dir}" -y || {
        builtin print -Pu2 -- "%F{1}Error during artifacts expansion.%f"
        return 2
    }
}

function sync-csquad-modbase-project-resources()
{
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
        command cp -f -r -v {$comp,$repo}/addons/qodot/src/util/qodot_texture_loader.gdc  || {
            builtin print -Pu2 -- "%F{1}Error copying resources/artifacts to repo.%f"
        }


    } | while { read line } {
        builtin print -P -- ${${line[2,-2]//$PWD/${(%):-$'%~'}}//\' -> \'/$'\n' -> %F\{32\}}"%f"
    }
}

rebuild-artifacts && sync-csquad-modbase-project-resources || {
    builtin print -Pu2 -- "%F{1}Error returned, cancelling early.%f"
    return 7
}

# Run powershell packaging script while we're here
pwsh.exe -NoProfile -NoLogo "$(winpath $repo/build.ps1)"