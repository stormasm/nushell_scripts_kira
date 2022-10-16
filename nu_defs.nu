#zoxide completion
export def "nu-complete zoxide path" [line : string, pos: int] {
  let prefix = ( $line | str trim | split row ' ' | append ' ' | skip 1 | get 0)
  let data = (^zoxide query $prefix --list | lines)
  {
      completions : $data,
                  options: {
                   completion_algorithm: "fuzzy"
                  }
  }
}

#helper for displaying left prompt
export def left_prompt [] {
  if not ($env.MY_ENV_VARS | is-column l_prompt) {
      $env.PWD | path parse | get stem
  } else if ($env.MY_ENV_VARS.l_prompt | is-empty) || ($env.MY_ENV_VARS.l_prompt == 'short') {
      $env.PWD | path parse | get stem
  } else {
      $env.PWD | str replace $nu.home-path '~' -s
  }
}

# Switch-case like instruction
export def switch [
  var                #input var to test
  cases: record      #record with all cases
  otherwise?: record #record code for otherwise
  #
  # Example:
  # let x = "3"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # }
  #
  # let x = "4"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # } { otherwise: { echo "otherwise" }}
  #
] {
  if ($cases | is-column $var) {
    $cases 
    | get $var 
    | do $in
  } else if not ($otherwise | is-empty) {
    $otherwise 
    | get "otherwise" 
    | do $in
  }
}

#update nu config (after nu update)
export def update-nu-config [] {
  ls (build-string $env.MY_ENV_VARS.nushell_dir "/**/*") 
  | find -i default_config 
  | update name {|n| 
      $n.name 
      | ansi strip
    }  
  | cp-pipe $nu.config-path

  open ([$env.MY_ENV_VARS.linux_backup "append_to_config.nu"] | path join) | save --append $nu.config-path
  nu -c $"source-env ($nu.config-path)"
}

#short help
export def ? [...search] {
  if ($search | is-empty) {
    help commands
  } else {
    if ($search | first) =~ "commands" {
      if ($search | first) =~ "my" {
        help commands | where is_custom == true
      } else {
        help commands 
      }
    } else if ($search | first | str contains "^") {
      tldr ($search | str collect "-" | split row "^" | get 0) | nu-highlight
    } else if (which ($search | first) | get path | get 0) =~ "Nushell" {
      if (which ($search | first) | get path | get 0) =~ "alias" {
        get-aliases | find ($search | first)
      } else {
        help ($search | str collect " ") | nu-highlight
      }
    } else {
      tldr ($search | str collect "-") | nu-highlight
    }
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

#wrapper for describe
export def typeof [--full(-f)] {
  describe 
  | if not $full { 
      split row '<' | get 0 
    } else { 
      $in 
    }
}

#copy pwd
export def cpwd [] {
  $env.PWD | xclip -sel clip
}

#xls/ods 2 csv
export def xls2csv [
  inputFile:string
  --outputFile:string
] {
  let output = (
    if ($outputFile | is-empty) || (not $outputFile) {
      $"($inputFile | path parse | get stem).csv"
    } else {
      $outputFile
    }
  )
  libreoffice --headless --convert-to csv $inputFile
}

#compress to 7z using max compression
export def 7zmax [
  filename: string  #filename without extension
  ...rest:  string  #files to compress and extra flags for 7z (add flags between quotes)
  --delete(-d)      #delete files after compression
  #
  # Example:
  # compress all files in current directory and delete them
  # 7zmax filename * "-sdel"
  # compress all files in current directory and split into pieces of 3Gb (b|k|m|g)
  # 7zmax filename * "-v3g"
  # both
  # 7zmax filename * "-v3g -sdel"
] {
  if ($rest | is-empty) {
    echo-r "no files to compress specified"
  } else if ($delete | is-empty) || (not $delete) {
    7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  } else {
    7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  }
}

#check if drive is mounted
export def is-mounted [drive:string] {
  (ls "~/media" | find $"($drive)" | length) > 0
}

#get phone number from google contacts
export def get-phone-number [search:string] {
  goobook dquery $search 
  | from ssv 
  | rename results 
  | where results =~ '(?P<plus>\+)(?P<nums>\d+)'
  
}

#update-upgrade system
export def supgrade [--old(-o)] {
  if not $old {
    echo-g "updating and upgrading..."
    sudo nala upgrade -y

    echo-g "autoremoving..."
    sudo nala autoremove -y
  } else {
    echo-g "updating..."
    sudo apt update -y

    echo-g "upgrading..."
    sudo apt upgrade -y

    echo-g "autoremoving..."
    sudo apt autoremove -y
  }

  echo-g "updating rust..."
  rustup update

  # echo-g "upgrading pip3 packages..."
  # pip3-upgrade
}

#upgrade pip3 packages
export def pip3-upgrade [] {
  pip3 list --outdated --format=freeze 
  | lines 
  | split column "==" 
  | each {|pkg| 
      echo-g $"upgrading ($pkg.column1)..."
      pip3 install --upgrade $pkg.column1
    }
}

#green echo
export def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}

#red echo
export def echo-r [string:string] {
  echo $"(ansi -e { fg: '#ff0000' attr: b })($string)(ansi reset)"
}

#open mcomix
export def mcx [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  bash -c $'mcomix "($file)" 2>/dev/null &'
}

#open file 
export def openf [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  let file = (
    switch ($file | typeof) {
      "record": { 
        $file
        | get name
        | ansi strip
      },
      "table": { 
        $file
        | get name
        | get 0
        | ansi strip
      },
    } { 
        "otherwise": { 
          $file
        }
      }
  )
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#open google drive file 
export def openg [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
   
  let url = (open $file 
    | lines 
    | find -i url 
    | split row "URL=" 
    | get 0
  )

  $url | copy
  echo-g $"($url) copied to clipboard!"
}

#send to printer
export def print-file [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
  lp $file
}

#play first/last downloaded youtube video
export def myt [file?, --reverse(-r)] {
  let inp = $in
  let video = (
    if not ($inp | is-empty) {
      $inp | get name
    } else if not ($file | is-empty) {
      $file
    } else if $reverse {
      ls | sort-by modified -r | where type == "file" | last | get name
    } else {
      ls | sort-by modified | where type == "file" | last | get name
    }
  )
  
  mpv --ontop --window-scale=0.4 --save-position-on-quit --no-border $video

  let delete = (input "delete file? (y/n): ")
  if $delete == "y" {
    rm $video
  } else {
    let move = (input "move file to pending? (y/n): ")
    if $move == "y" {
      mv $video pending
    }
  } 
}

#search for specific process
export def psn [name: string] {
  ps -l | find -i $name
}

#kill specified process in name
export def killn [name?] {
  if not ($name | is-empty) {
    ps -l
    | find -i $name 
    | par-each {
        kill -f $in.pid
      }
  } else {
    $in
    | par-each {|row|
        kill -f $row.pid
      }
  }
}

#jdownloader downloads info
export def jd [
  --ubb(-b)#check ubb jdownloader
] {
  if ($ubb | is-empty) || (not $ubb) {
    jdown
  } else {
    jdown -b 1
  }
  | lines 
  | each { |line| 
      $line 
      | from nuon 
    } 
  | flatten 
  | flatten
}

#select column of a table (to table)
export def column [n] { 
  transpose 
  | select $n 
  | transpose 
  | select column1 
  | headers
}

#get column of a table (to list)
export def column2 [n] { 
  transpose 
  | get $n 
  | transpose 
  | get column1 
  | skip 1
}

#short pwd
export def pwd-short [] {
  $env.PWD 
  | str replace $nu.home-path '~' -s
}

#string repeat
export def "str repeat" [count: int] { 
  each {|it| 
    let str = $it; echo 1..$count 
    | each { 
        echo $str 
      } 
  } 
}

#string prepend
export def "str prepend" [toprepend] { 
  build-string $toprepend $in
}

#string append
export def "str append" [toappend] { 
  build-string $in $toappend
}

#join 2 lists
export def union [a: list, b: list] {
  $a 
  | append $b 
  | uniq
}

#nushell source files info
export def 'nu-sloc' [] {
  let stats = (
    ls **/*.nu
    | select name
    | insert lines { |it| 
        open $it.name 
        | size 
        | get lines 
      }
    | insert blank {|s| 
        $s.lines - (open $s.name | lines | find --regex '\S' | length) 
      }
    | insert comments {|s| 
        open $s.name 
        | lines 
        | find --regex '^\s*#' 
        | length 
      }
    | sort-by lines -r
  )

  let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
  let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
  let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
  let total = ($stats | length)
  let avg = ($lines / $total | math round)

  $'(char nl)(ansi pr) SLOC Summary for Nushell (ansi reset)(char nl)'
  print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
  $'(char nl)Source file stat detail:'
  print $stats
}

#go to dir (via pipe)
export def-env cd-pipe [] {
  let input = $in
  cd (
      if ($input | path type) == file {
          ($input | path dirname)
      } else {
          $input
      }
  )
}

#go to bash path (must be the last one in PATH)
export def-env cdto-bash [] {
  cd ($env.PATH | last)
}

#cd to the folder where a binary is located
export def-env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#delete non wanted media in mps (youtube download folder)
export def delete-mps [] {
  if $env.MY_ENV_VARS.mps !~ $env.PWD {
    echo-r "wrong directory to run this"
  } else {
     le
     | where type == "file" && ext !~ "mp4|mkv|webm|part" 
     | par-each {|it| 
         rm $"($it.name)" 
         | ignore
       }     
  }
}

#push to git
export def git-push [m: string] {
  git add -A
  git status
  git commit -am $"($m)"
  git push #origin main  
}

#web search in terminal
export def gg [...search: string] {
  ddgr -n 5 ($search | str collect ' ')
}

#habitipy dailies done all
export def hab-dailies-done [] {
  let to_do = (habitipy dailies 
    | grep ✖ 
    | detect columns -n 
    | select column0 
    | each {|row| 
        $row.column0 
        | str replace -s '.' ''
      }  
    | into int  
  )

  habitipy dailies done $to_do 
}

#countdown alarm 
export def countdown [
  n: int #time in seconds
] {
  let BEEP = ([$env.MY_ENV_VARS.linux_backup "alarm-clock-elapsed.oga"] | path join)
  let muted = (pacmd list-sinks 
    | lines 
    | find muted 
    | parse "{state}: {value}" 
    | get value 
    | get 0
  )

  if $muted == 'no' {
    termdown $n
    mpv --no-terminal $BEEP  
  } else {
    termdown $n
    unmute
    mpv --no-terminal $BEEP
    mute
  }   
}

#get aliases
export def get-aliases [] {
  $nu
  | get scope 
  | get aliases
  | update expansion {|c|
      $c.expansion | nu-highlight
    }
}

#ping with plot
export def png-plot [ip?] {
  let ip = if ($ip | is-empty) {"1.1.1.1"} else {$ip}

  bash -c $"ping ($ip) | sed -u 's/^.*time=//g; s/ ms//g' | ttyplot -t \'ping to ($ip)\' -u ms"
}

#plot download-upload speed
export def speedtest-plot [] {
  echo "fast --single-line --upload |  stdbuf -o0 awk '{print $2 \" \" $6}' | ttyplot -2 -t 'Download/Upload speed' -u Mbps" | bash 
}

#plot data table using gnuplot
export def gnu-plot [
  data?           #1 or 2 column table
  --title:string  #title
  #
  #Example: If $x is a table with 2 columns
  #$x | gnu-plot
  #($x | column 0) | gnu-plot
  #($x | column 1) | gnu-plot
  #($x | column 0) | gnu-plot --title "My Title"
  #gnu-plot $x --title "My Title"
] {
  let x = if ($data | is-empty) {$in} else {$data}
  let n_cols = ($x | transpose | length)
  let name_cols = ($x | transpose | column2 0)

  let ylabel = if $n_cols == 1 {$name_cols | get 0} else {$name_cols | get 1}
  let xlabel = if $n_cols == 1 {""} else {$name_cols | get 0}

  let title = if ($title | is-empty) {
    if $n_cols == 1 {
      $ylabel | str upcase
    } else {
      $"($ylabel) vs ($xlabel)"
    }
  } else {
    $title
  }

  $x | to tsv | save data0.txt 
  sed 1d data0.txt | save data.txt
  
  gnuplot -e $"set terminal dumb; unset key;set title '($title)';plot 'data.txt' w l lt 0;"

  rm data*.txt | ignore
} 

#check validity of a link
export def check-link [link?,timeout?:int] {
  let link = if ($link | is-empty) {$in} else {$link}

  if ($timeout | is-empty) {
    not (do -i { fetch $link } | is-empty)
  } else {
    not (do -i { fetch $link -t $timeout} | is-empty)
  }
}

#rm trough pipe
#
#Example
#ls *.txt | first 5 | rm-pipe
export def rm-pipe [] {
  if not ($in | is-empty) {
    get name 
    | ansi strip
    | par-each {|file| 
        rm -rf $file
      } 
    | flatten
  }
}

#cp trough pipe to same dir
export def cp-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | cp-pipe ~/temp
] {
  get name 
  | each {|file| 
      echo-g $"copying ($file)..." 
      cp -r $file ($to | path expand)
    } 
  | flatten
}

#mv trough pipe to same dir
export def mv-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | mv-pipe ~/temp
] {
  get name 
  | each {|file|
      echo-g $"moving ($file)..." 
      mv $file ($to | path expand)
    }
  | flatten
}

#ls by date (newer last)
export def lt [
  --reverse(-r) #reverse order
] {
  if ($reverse | is-empty) || (not $reverse) {
    ls | sort-by modified  
  } else {
    ls | sort-by modified -r
  } 
}

#ls in text grid
export def lg [
  --date(-t)    #sort by date
  --reverse(-r) #reverse order
] {
  let t = if $date {"true"} else {"false"}
  let r = if $reverse {"true"} else {"false"}

  switch $t {
    "true": { 
      switch $r {
        "true": { 
          ls | sort-by -r modified | grid -c
        },
        "false": { 
          ls | sort-by modified | grid -c
        }
      }
    },
    "false": { 
      switch $r {
        "true": { 
          ls | sort-by -i -r type name | grid -c
        },
        "false": { 
          ls | sort-by -i type name | grid -c
        }
      }
    }
  }
}

#ls sorted by name
export def ln [--du(-d)] {
  if $du {
    ls --du | sort-by -i type name 
  } else {
    ls | sort-by -i type name 
  }
}

#ls only name
export def lo [] {
  ls 
  | sort-by -i type name 
  | reject type size modified 
}

#ls sorted by extension
export def le [] {
  ls
  | sort-by -i type name 
  | insert "ext" { 
      $in.name 
      | path parse 
      | get extension 
    } 
  | sort-by ext
}

#get list of files recursively
export def get-files [] {
  ls **/* 
  | where type == file 
  | sort-by -i name
}


#find file in dir recursively
export def find-file [search] {
  get-files 
  | where name =~ $search
}

#get list of directories in current path
export def get-dirs [dir?] {
  if ($dir | is-empty) {
    ls 
    | where type == dir 
    | sort-by -i name
  } else {
    ls $dir
    | where type == dir 
    | sort-by -i name
  }
}

#get devices connected to network
export def get-devices [
  device = "wlo1" #wlo1 for wifi (export default), eno1 for lan
  #
  #It needs nmap2json, installable (ubuntu at least) via
  #
  #sudo gem install nmap2json
] {
  let ipinfo = (
    if (? | where name == net | length) > 0 {
      net 
      | where name == ($device) 
      | get 0 
      | get ips 
      | where type == v4 
      | get 0 
      | get addr
      | str replace '(?P<nums>\d+/)' '0/'
    } else {
      ip -json add 
      | from json 
      | where ifname =~ $"($device)" 
      | select addr_info 
      | flatten 
      | find -v inet6 
      | flatten 
      | get local prefixlen 
      | flatten 
      | str collect '/' 
      | str replace '(?P<nums>\d+/)' '0/'
    }
  )

  let nmap_output = (sudo nmap -oX nmap.xml -sn $ipinfo --max-parallelism 10)

  let nmap_output = (nmap2json convert nmap.xml | from json | get nmaprun | get host | get address)

  let this_ip = ($nmap_output | last | get addr)

  let ips = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype =~ ipv4 
    | select addr 
    | rename ip
  )
  
  let macs_n_names = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype =~ mac 
    | select addr vendor 
    | rename mac name
    | update name {|f|
        if ($f.name | is-empty) {
          "Unknown"
        } else {
          $f.name
        }
      }
  )

  let devices = ( $ips | merge { $macs_n_names} )

  let known_devices = open ([$env.MY_ENV_VARS.linux_backup "known_devices.csv"] | path join)
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {any it.mac in $known_macs} | wrap known)

  let devices = ($devices | merge {$known})

  let aliases = (
    $devices 
    | each {|row| 
        if $row.known {
          $known_devices | find $row.mac | get alias
        } else {
          " "
        }
      } 
    | flatten 
    | wrap alias
  )
   
  rm nmap.xml | ignore 

  $devices | merge {$aliases}
}

#verify if a column exist within a table
export def is-column [name] { 
  $name in ($in | columns) 
}

#grep for nu
export def grep-nu [
  search   #search term
  entrada?  #file or pipe
  #
  #Examples
  #grep-nu search file.txt
  #ls **/* | some_filter | grep-nu search 
  #open file.txt | grep-nu search
] {
  if ($entrada | is-empty) {
    if ($in | is-column name) {
      grep -ihHn $search ($in | get name)
    } else {
      ($in | into string) | grep -ihHn $search
    }
  } else {
      grep -ihHn $search $entrada
  }
  | lines 
  | parse "{file}:{line}:{match}"
  | str trim
  | update match {|f| 
      $f.match 
      | nu-highlight
    }
  | rename "source file" "line number"
}

#get ips
export def get-ips [
  device =  "wlo1"  #wlo1 for wifi (export default), eno1 for lan
] {
  let internal = (ip -json add 
    | from json 
    | where ifname =~ $"($device)" 
    | select addr_info 
    | flatten | find -v inet6 
    | flatten 
    | get local 
    | get 0
  )

  let external = (dig +short myip.opendns.com @resolver1.opendns.com)
  
  {internal: $internal, external: $external}
}

#join multiple pdfs
export def join-pdfs [
  ...rest: #list of pdf files to concatenate
] {
  if ($rest | is-empty) {
    echo-r "not enough pdfs provided"
  } else {
    pdftk $rest cat output output.pdf
    echo-g "pdf merged in output.pdf"
  }
}

#send email via Gmail with signature files (posfix configuration required)
export def send-gmail [
  to:string                         #email to
  subject:string                    #email subject
  --body:string                     #email body, use double quotes to use escape characters like \n
  --from = $env.MY_ENV_VARS.mail    #email from, export default: $MY_ENV_VARS.mail
  ...attachments                    #email attachments file names list (in current directory), separated by comma
  #
  #Examples:
  #-Body from cli:
  #  send-gmail test@gmail.com "the subject" --body "the body"
  #  echo "the body" | send-gmail test@gmail.com "the subject"
  #-Body from a file:
  #  open file.txt | send-gmail test@gmail.com "the subject"
  #-Attachments:
  # send-gmail test@gmail.com "the subject" --body "the body" this_file.txt
  # echo "the body" | send-gmail test@gmail.com "the subject" this_file.txt,other_file.pdf
  # open file.txt | send-gmail test@gmail.com "the subject" this_file.txt,other_file.pdf,other.srt
] {
  let inp = if ($in | is-empty) { "" } else { $in | into string }

  if ($body | is-empty) && ($inp | is-empty) {
    echo-r "body unexport defined!!"
  } else if not (($from | str contains "@") && ($to | str contains "@")) {
    echo-r "missing @ in email-from or email-to!!"
  } else {
    let signature_file = (
      switch $from {
        $env.MY_ENV_VARS.mail : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_kurokirasama_signature"] | path join)},
        $env.MY_ENV_VARS.mail_ubb : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_ubb_signature"] | path join)},
        $env.MY_ENV_VARS.mail_lmgg : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_lmgg_signature"] | path join)}
      } {otherwise : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_other_signature"] | path join)}}
    )

    let signature = (open $signature_file)

    let BODY = (
      if ($inp | is-empty) { 
        $signature 
        | str prepend $"($body)\n" 
      } else { 
        $signature 
        | str prepend $"($inp)\n" 
      } 
    )

    if ($attachments | is-empty) {
      echo $BODY | mail -r $from -s $subject $to
    } else {
      let ATTACHMENTS = ($attachments 
        | split row ","
        | par-each {|file| 
            [$env.PWD $file] 
            | path join
          } 
        | str collect " --attach="
        | str prepend "--attach="
      )
      bash -c $"\'echo ($BODY) | mail ($ATTACHMENTS) -r ($from) -s \"($subject)\" ($to) --debug-level 10\'"
    }
  }
}

#get code of custom command
export def code [command] {
  view-source $command | nu-highlight
}

#register nu plugins
export def reg-plugins [] {
  ls ~/.cargo/bin
  | where type == file 
  | sort-by -i name
  | get name 
  | find nu_plugin 
  | find -v example
  | each {|file|
      if (grp $file $nu.plugin-path | length) == 0 {
        echo-g $"registering ($file)..."
        nu -c $'register ($file)'    
      } 
    }
}

#stop network applications
export def stop-net-apps [] {
  t-stop
  ydx-stop
  maestral stop
  killn jdown
}

#add a hidden column with the content of the # column
export def indexify [
  column_name: string = 'index' #export default: index
  ] { 
  each -n {|it| 
    $it.item 
    | upsert $column_name $it.index 
    | move $column_name --before ($it.item | columns).0 
  } 
}

#reset alpine authentification
export def reset-alpine-auth [] {
  rm ~/.pine-passfile
  touch ~/.pine-passfile
  alpine-notify -i
}

#run matlab in cli
export def matlab-cli [--ubb(-b)] {
  if not $ubb {
    matlab19 -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt"
  } else {
    matlab19_ubb -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt"
  }
}

#create dir and cd into it
export def-env mkcd [name: path] {
  cd (mkdir $name -s | first)
}

#backup sublime settings
export def backup-sublime [] {
  cd $env.MY_ENV_VARS.linux_backup
  let source_dir = "~/.config/sublime-text"
  
  7zmax sublime-installedPackages ([$source_dir "Installed Packages"] | path join)
  7zmax sublime-Packages ([$source_dir "Packages"] | path join)
}

#second screen positioning (work)
export def set-screen [
  side: string = "right"  #which side, left or right (default)
  --home                  #for home pc
  --hdmi = "right"        #for home pc, which hdmi port: left or right (default)
] {
  if not $home {
    switch $side {
      "right": { xrandr --output HDMI-1-1 --auto --right-of eDP },
      "left": { xrandr --output HDMI-1-1 --auto --left-of eDP }
    } { 
      "otherwise": { echo-r "Side argument should be either right or left" }
    }
  } else {
    switch $side {
      "right": { 
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --right-of eDP-1-1
        } else {
          xrandr --output HDMI-0 --auto --right-of eDP-1-1
        } 
      },
      "left": { 
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --left-of eDP-1-1 
        } else {
          xrandr --output HDMI-0 --auto --left-of eDP-1-1 
        }
      }
    } { 
      "otherwise": { echo-r "Side argument should be either right or left" }
    }
  }

}