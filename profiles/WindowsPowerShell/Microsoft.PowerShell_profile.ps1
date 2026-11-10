Function global:prompt {
  $dirSep = [IO.Path]::DirectorySeparatorChar
  $pathComponents = $PWD.Path.Split($dirSep)
  $displayPath = if ($pathComponents.Count -le 3) {
    $PWD.Path
  } else {
    '{0}{1}' -f $dirSep, ($pathComponents[-2,-1] -join $dirSep)
  }
  "PS {0}$('>' * ($nestedPromptLevel + 1)) " -f $displayPath
}


function redis-cli { memurai-cli }

function claude-o { claude --model claude-opus-4-7 @args }
function claude-o2 { claude --model claude-opus-4-8 @args }
function claude-s { claude --model claude-sonnet-4-6 @args }
