## add my local dir and the development lib ahead of prod...
## 
## p = prod set prod libs in path
## u = set my local libs
## d = add dev libs
## g = git currently C:\users\greg\ASLLibs\ASLPythonLibs.... (some
## r == clear 
param (
   [switch]$p,
   [switch]$u,
   [switch]$d,
   [switch]$r,
   [switch]$g,
   [switch]$v
)

$PROD_LIB="\\aslfile01\aslcap\IT\software\Production\python"
$PROD_SRCH="*/software/Production*"
$DEV_LIB="\\aslfile01\aslcap\IT\software\Development\python"
# $DEV_LIB="N:\IT\software\Development\python"
$DEV_SRCH="*/software/Development*"
$MY_LIB="C:\Users\greg.mahoney\my_python_libs"
$MY_SRCH="*\Users\greg.mahoney\my_python_libs*" 
$GIT_LIB="C:\Users\greg.mahoney\ASLLibs\ASLPythonLibs"
$GIT_SRCH="*\Users\greg.mahoney\ASLLibs\ASLPythonLibs*" 

$new_path=$Env:PYTHONPATH

## reset the var
if ($r) {
  $new_path=""
}

if ($p) { 
  if (-NOT($new_path -like "$PROD_SRCH")) {
    $new_path="$PROD_LIB;"
  }
} else {
   $new_path=$new_path.Replace("$PROD_LIB;", "")
}

if ($d) { 
  if (-NOT($new_path -like "$DEV_SRCH")) {
    $new_path="$DEV_LIB;$new_path"
  }
} else {
   $new_path=$new_path.Replace("$DEV_LIB;", "")
}

if ($u) {
  if (-NOT($new_path -like "$MY_SRCH")) {
   $new_path="$MY_LIB;$new_path"
  }
} else {
   $new_path=$new_path.Replace("$MY_LIB;", "")
}

if ($g) {
  if (-NOT($new_path -like "$GIT_SRCH")) {
   $new_path="$GIT_LIB;$new_path"
  }
} else {
   $new_path=$new_path.Replace("$GIT_LIB;", "")
}

$Env:PYTHONPATH=$new_path
write-Output("New PYTHONPATH = $Env:PYTHONPATH")


