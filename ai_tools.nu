#ai tools
export def ai [] {
  print (
    echo "This set of tools need a few dependencies installed:\n
      whisper:\n
        pip install git+https://github.com/openai/whisper.git\n
      chatgpt-wrapper:\n
        pip install git+https://github.com/mmabrouk/chatgpt-wrapper\n
      METHODS\n
      - `ai audio2text`
      - `ai screen2text`
      - `ai transcription-summary`
      - `ai audio2summary`
      - `ai git-push`\n"
    | nu-highlight
  ) 
}

#audio to text transcription via whisper
export def "ai audio2text" [
  filename                    #audio file input
  --language(-l) = "Spanish"  #language of audio file
  --output_format(-o) = "txt" #output format: txt (default), vtt, srt, tsv, json, all
] {
  let file = ($filename | path parse | get stem)

  print (echo-g $"reproduce ($filename) and select start and end time for noise segment, leave empty if no noise..." )
  let start = (input "start? (hh:mm:ss): ")
  let end = (input "end? (hh:mm:ss): ")

  if ($start | is-empty) or ($end | is-empty) {
    print (echo-g "generating temp file...")
    if ($filename | path parse | get extension) =~ "mp3" {
      cp $filename $"($file)-clean.mp3"
    } else {
      ffmpeg -loglevel 1 -i $"($filename)" -acodec libmp3lame -ab 128k -vn $"($file)-clean.mp3"
    }
  } else {
    media remove-noise $filename $start $end 0.2 $"($file)-clean" -d false -E mp3
  }

  print (echo-g "transcribing to text...")
  whisper $"($file)-clean.mp3" --language $language --output_format $output_format --verbose False
}

#screen record to text transcription 
export def "ai screen2text" [
--transcribe = true #whether to transcribe or not. Default true, false means it just extracts audio
] {
  let file = (date now | date format "%Y%m%d_%H%M%S")

  if not ("~/Documents/Transcriptions" | path exists) {
    ^mkdir -p ~/Documents/Transcriptions 
  }

  cd ~/Documents/Transcriptions
  
  try {
    media screen-record $file
  }

  media extract-audio $"($file).mp4"

  ai audio2text $"($file).wav"

  if $transcribe {
    ai transcription-summary $"($file | path parse | get stem)-clean.txt"
  }
}

#resume transcription text via gpt 
export def "ai transcription-summary" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
] {
  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = 2000
  let n_words = (wc -w $file | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting input file ($file)...")

    let filenames = $"($file | path parse | get stem)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "int(total/" + $"($max_words)" + ")" + "\".txt\"}'" + $" \"($file)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary)

    $files | each {|split_file|
      ai transcription-summary-single ($split_file | get name | ansi strip) -u false -g $gpt4
    }

    let temp_output = $"($file | path parse | get stem)_summaries.md"
    print (echo-g $"combining the results into ($temp_output)...")
    touch $temp_output

    let files = (ls | find split | find summary | enumerate)

    $files | each {|split_file|
      echo $"Parte ($split_file.index):\n" | save --append $temp_output
      open ($split_file.item.name | ansi strip) | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let pre_prompt = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) | get prompt2)

    let prompt = (
      $pre_prompt
      | str append "\n" 
      | str append "```"
      | str append "\n" 
      | str append (open $temp_output)
      | str append "\n" 
      | str append "```"
    )

    print (echo-g $"asking chatgpt to combine the results in ($temp_output)...")
    if $gpt4 {
      chatgpt -p temp05_summarizer_gpt4 $prompt | save -f $output
    } else {
      chatgpt -p temp05_summarizer_gpt3.5 $prompt | save -f $output
    }

    if $upload {
      if not $mounted {
        print (echo-g "mounting gdrive...")
        mount-ubb
      }

      print (echo-g "uploading summary to gdrive...")
      cp $output $up_folder
    }

    return
  }
  
  ai transcription-summary-single $file -u $upload -g $gpt4 
}

#resume transcription via gpt in one go
export def "ai transcription-summary-single" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
] {
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  let pre_prompt = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) | get prompt1)

  let prompt = (
    $pre_prompt
    | str append "\n" 
    | str append "```"
    | str append "\n" 
    | str append (open $file)
    | str append "\n" 
    | str append "```"
  )

  print (echo-g $"asking chatgpt for a summary of the file ($file)...")
  if $gpt4 {
    chatgpt -p temp05_summarizer_gpt4 $prompt | save -f $output
  } else {
    chatgpt -p temp05_summarizer_gpt3.5 $prompt | save -f $output
  }

  if $upload {
    if not $mounted {
      print (echo-g "mounting gdrive...")
      mount-ubb
    }

    print (echo-g "uploading summary to gdrive...")
    cp $output $up_folder
  }
}

#audio 2 transcription summary via chatgpt
export def "ai audio2summary" [
  file
  --upload = true #whether to upload the summary to gdrive (dafault true)
] {
  ai audio2text $file
  ai transcription-summary $"($file | path parse | get stem)-clean.txt" --upload $upload
  if $upload {
    print (echo-g $"uploading ($file)...")
    cp $"($file | path parse | get stem)-clean.mp3" ($env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory)
  }
}

#generate subtitles of video file via whisper and mymemmory api
export def "ai generate-subtitles" [
  file                               #input video file
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper (default en-US/English)
  --translate(-t) = false            #to translate to spanish (default false)
  #
  #`? trans` and `whisper --help` for more info on languages
] {
  let filename = ($file | path parse | get stem)

  media extract-audio $file 
  ai audio2text $"($filename).mp3" -o srt -l ($language | split row "/" | get 1)

  if $translate {
    media trans-sub $"($filename).srt" --from ($language | split row "/" | get 0)
  }
}

#generate subtitles of video file via whisper and mymemmory api for piping
export def "ai generate-subtitles-pipe" [
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper (default en-US/English)
  --translate(-t) = false            #to translate to spanish
  #
  #`? trans` and `whisper --help` for more info on languages
] {
  $in
  | get name 
  | each {|file| 
      ai generate-subtitles ($file | ansi strip) -l $language -t $translate
    }
}

#generate a git commit message via chatgot and push the changes
export def "ai git-push" [
  --gpt4
  #
  #Inspired by https://github.com/zurawiki/gptcommit
] {
  print (echo-g "asking chatgpt to summarize the differences in the repository...")
  let pre_prompt = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) | get prompt4)
  let git_diff = (git diff)
  let prompt = ($pre_prompt + "\n" + $git_diff)
  let commit = (
    if $gpt4 {
      chatgpt -p temp03_gitcommits_summarizer_gpt4 $prompt
    } else {
      chatgpt -p temp03_gitcommits_summarizer_gpt3.5 $prompt
    }
  )

  print (echo-g "resulting commit message:")
  print (echo $commit)

  print (echo-g "pushing the changes with that commit message\n")
  git add -A
  git status
  git commit -am $commit
  git push #origin main
}