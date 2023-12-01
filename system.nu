#nushell banner
export def show_banner [] {
    let ellie = [
        "     __  ,"
        " .--()°'.'"
        "'|, . ,'  "
        ' !_-(_\   '
    ]
    let s = (sys)
    print $"(ansi reset)(ansi green)($ellie.0)"
    print $"(ansi green)($ellie.1)  (ansi yellow) (ansi yellow_bold)Nushell (ansi reset)(ansi yellow)v(version | get version)(ansi reset)"
    print $"(ansi green)($ellie.2)  (ansi light_blue) (ansi light_blue_bold)RAM (ansi reset)(ansi light_blue)($s.mem.used) / ($s.mem.total)(ansi reset)"
    print $"(ansi green)($ellie.3)  (ansi light_purple)ﮫ (ansi light_purple_bold)Uptime (ansi reset)(ansi light_purple)($s.host.uptime)(ansi reset)"
}

#neofetch but nu (in progress)
export def nufetch [--table(-t)] {
  if not $table {
    show_banner
    return 
  } 

  let s  = sys
  let s2 = (
    hostnamectl 
    | lines 
    | parse "{headers}: {value}"
    | str trim
    | transpose -ird 
  )
  let os = ($s2 | get "Operating System") + " " + $nu.os-info.arch
  let host = (open /sys/devices/virtual/dmi/id/product_name | lines | get 0)
  let shell = ($env.SHELL | path parse | get stem) + " " + (version | get version)
  let screen_res = (
    xrandr 
    | lines 
    | find "*+" 
    | parse "   {resolution} {rest}" 
    | get resolution 
    | str join ", "
  )
  let theme = (
    gsettings get org.gnome.desktop.interface gtk-theme 
    | lines 
    | get 0 
    | str replace -a "'" ""
  )
  let icons = (
    gsettings get org.gnome.desktop.interface icon-theme 
    | lines 
    | get 0
    | str replace -a "'" ""
  )
  let free_disk = ($s.disks | where mount == / | get free | get 0)
  let total_disk = ($s.disks | where mount == / | get total | get 0)
  let disk = (($total_disk - $free_disk) | into string) + " / " + ($total_disk | into string)
  let mem = ($s.mem.used | into string) + " / " + ($s.mem.total | into string)
  let gpus = (
    lspci 
    | lines 
    | find -i vga 
    | parse "{col2} VGA compatible controller: {col1}" 
    | each {|row| 
        [$row.col1 $row.col2] 
        | str join " "
      }
    )
  let wm = (
    if $env.XDG_CURRENT_DESKTOP == "ubuntu:GNOME" {
      "Mutter"
    } else {
      wmctrl -m | lines | first | split row ": " | last
    }
  )
  let terminal = (
    xdotool getactivewindow | xargs -I {} xprop -id {} WM_CLASS 
    | split row = 
    | get 1 
    | str trim 
    | split row , 
    | get 0 
    | str replace -a "\"" ""
  )
  let wmtheme = gsettings get org.gnome.shell.extensions.user-theme name | str replace -a "'" ""
  let info = {} 

  $info
  | upsert user $env.USERNAME
  | upsert hostname $s.host.hostname
  | upsert os $os
  | upsert host $host
  | upsert kernel $s.host.kernel_version
  | upsert uptime $s.host.uptime
  | upsert dpkgPackages (dpkg --get-selections | lines | length)
  | upsert snapPackages ((snap list  | lines | length) - 1)
  | upsert shell $shell
  | upsert resolution $screen_res
  | upsert de $env.XDG_CURRENT_DESKTOP
  | upsert wm $wm
  | upsert wmTheme $wmtheme
  | upsert theme $theme
  | upsert icons $icons
  | upsert terminal $terminal
  | upsert cpu ($s.cpu | get brand | uniq | get 0)
  | upsert cores (($s.cpu | length) / 2)
  | upsert gpu $gpus
  | upsert disk $disk
  | upsert memory $mem
  | table -e
}

#helper for displaying left prompt
export def left_prompt [] {
  if not ($env.MY_ENV_VARS | is-column l_prompt) {
      $env.PWD | path parse | get stem
  } else if ($env.MY_ENV_VARS.l_prompt | is-empty) or ($env.MY_ENV_VARS.l_prompt == 'short') {
      $env.PWD | path parse | get stem
  } else {
      $env.PWD | str replace $nu.home-path '~'
  }
}

#short help
export def ? [...search] {
  if ($search | is-empty) {
    print (help commands)
    return
  } 

  if ($search | str join " ") =~ "commands" {
   if ($search | first) =~ "my" {
     help commands | where command_type == custom | reject command_type
   } else {
     help commands 
   }
  } else if (which ($search | str join " ") | get type | get 0) =~ "external" {
   tldr (which ($search | str join " ") | get command | get 0)
  } else {
   help (which ($search | str join " ") | get command | get 0)
  }
}

#last 100 elements in history with highlight
export def h [howmany = 100] {
  history
  | last $howmany
  | update command {|f|
      $f.command 
      | nu-highlight
    }
}

#search for specific process
export def psn [name?: string] {
  let name = if ($name | is-empty) {$in} else {$name}
  ps -l | find -i $name
}

#kill specified process
#
#Receives a name or a list of processes
export def killn [name?] {
  if not ($name | is-empty) {
    ps -l
    | find -i $name 
    | par-each {||
        kill -f $in.pid
      }
  } else {
    $in
    | par-each {|row|
        kill -f $row.pid
      }
  }
}

#short pwd
export def pwd-short [] {
  $env.PWD | str replace $nu.home-path '~'
}

#go to dir (via pipe)
export def --env cd-pipe [] {
  let input = $in
  cd (
      if ($input |  get name | path type) == file {
          ($input | path expand | path dirname)
      } else {
          $input | get name
      }
  )
}

#cd to the folder where a binary is located
export def --env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#get aliases
export def get-aliases [] {
  scope aliases
  | update expansion {|c|
      $c.expansion | nu-highlight
    }
}

#get code of custom command
export def code [command,--raw] {
  if not $raw {
    view source $command | nu-highlight
  } else {
    view source $command
  }
}

#stop network applications
export def stop-net-apps [] {
  sudo service transmission-daemon stop
  yandex-disk stop
  maestral stop
  killn jdown
}

#create dir and cd into it
export def --env mkcd [name: path] {
  mkdir $name
  cd $name
}

#second screen positioning
export def set-screen [
  side: string = "right"  #which side, left or right (default)
  --home                  #for home pc
  --hdmi = "right"        #for home pc, which hdmi port: left or right (default)
] {
  if not $home {
    match $side {
      "right" => {xrandr --output HDMI-1-1 --auto --right-of eDP},
      "left" => {xrandr --output HDMI-1-1 --auto --left-of eDP},
      _ => {return-error "Side argument should be either right or left"}
    }
    return
  } 

  match $side {
    "right" => {
      if $hdmi == "right" {
        xrandr --output HDMI-1-1 --auto --right-of eDP-1-1
      } else {
        xrandr --output HDMI-0 --auto --right-of eDP-1-1
      } 
    },
    "left" => {
      if $hdmi == "right" {
        xrandr --output HDMI-1-1 --auto --left-of eDP-1-1 
      } else {
        xrandr --output HDMI-0 --auto --left-of eDP-1-1 
      }
    },
    _ => {return-error "Side argument should be either right or left"}
  }
}

#umount all drives 
#
#needs duf installed
export def umall [user?] {
  let user = if ($user | is-empty) {$env.USER} else {$user}

  try {
    duf -json 
    | from json 
    | find $"/media/($user)" 
    | get mount_point
    | each {|drive| 
        print (echo-g $"umounting ($drive  | ansi strip)...")
        umount ($drive | ansi strip)
      }
  } catch {
    return-error "device is busy!"
  }
}

#fix docker run error
export def fix-docker [] {
  sudo usermod -aG docker $env.USER
  newgrp docker
}

#generate error output
export def return-error [msg] {
  error make -u {msg: $"(echo-r $msg)"}
}

#get monitors
export def get-monitors [] {
  xrandr | lines | range 1..5 | parse -r '(\S+)\s+(\S+).*'
}