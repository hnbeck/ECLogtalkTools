#############################################################################
## 
##   This script creates a SWI-Prolog logtalk.qlf file with the Logtalk
##   compiler and runtime and optionally an application.qlf file with a
##   Logtalk application
## 
##   Last updated on March 24, 2022
## 
##   This file is part of Logtalk <https://logtalk.org/>  
##   Copyright 1998-2022 Paulo Moura <pmoura@logtalk.org>
##   SPDX-License-Identifier: Apache-2.0
##   
##   Licensed under the Apache License, Version 2.0 (the "License");
##   you may not use this file except in compliance with the License.
##   You may obtain a copy of the License at
##   
##       http://www.apache.org/licenses/LICENSE-2.0
##   
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.
## 
##   Adapted to Windows PowerShell by Hans N. Beck (2022)
#############################################################################


[CmdletBinding()]
param(
    [Parameter()]
    [Switch]$compile, 
    [Switch]$save_state,
    [String]$directory = $pwd,
    [String]$temporary,
    [String]$name ="application",
    [String]$path = ($env:LOGTALKHOME + '\paths\paths_core.pl'),
    [String]$hooks = ($env:LOGTALKHOME + '\adapters\swihooks.pl'),
    [String]$settings, 
    [String]$loader,
    [String]$goal = "true",
    [Switch]$version,
    [Switch]$help
)

function Get-ScriptVersion {

    $myFullName = $MyInvocation.ScriptName
    $myName = Split-Path -Path $myFullName -leaf -Resolve
    Write-Output ($myName + " 0.1")
}

function Get-Logtalkhome {

    if ($null -eq $env:LOGTALKHOME) 
    {
        Write-Output "The environment variable LOGTALKHOME should be defined first, pointing"
        Write-Output "to your Logtalk installation directory!"
        Write-Output "Trying the default locations for the Logtalk installation..."
       
        # TODO This has to be modified to the correct Window distribution cases
        $DEFAULTPATH = [string[]]( $StdProgramDir)
        # One possibility is using LOCALAPPDATA environment
        if (-not ($null -eq $env:LOCALAPPDATA)) 
        {
            $DEFAULTPATH += $env:LOCALAPPDATA + '\logtalk' #TODO really correct for windows?
        }    
       
        # Checking all possibilites               
        foreach ($P in $DEFAULTPATH)
         { 
            Write-Output ("Looking for: " + $P)
             if (Test-Path $P)
             {
               Write-Output  ("... using Logtalk installation found at " + $P)
               $env:LOGTALKHOME = $P
               break
             }
        }
    }
    # At the end LOGTALKHOME was set already or now is set
}

function Get-Usage()
{
    $myFullName = $MyInvocation.ScriptName
    $myName = Split-Path -Path $myFullName -leaf -Resolve 

	Write-Output "This script creates a SWI-Prolog logtalk.qlf file with the Logtalk compiler"
	Write-Output "and runtime and an optional application.qlf file from an application source"
	Write-Output "code given its loader file. It can also generate a standalone saved state."
	Write-Output ""
	Write-Output "Usage:"
	Write-Output ($myName + " [-c] [-x] [-d directory] [-t tmpdir] [-n name] [-p paths] [-k hooks] [-s settings] [-l loader] [-g goal]")
	Write-Output ($myName + "-v")
	Write-Output ($myName + "-h")
	Write-Output ""
	Write-Output "Optional arguments:"
	Write-Output "  -c compile library alias paths in paths and settings files"
	Write-Output "  -x also generate a standalone saved state"
	Write-Output "  -d directory for generated QLF files (absolute path; default is current directory)"
	Write-Output "  -t temporary directory for intermediate files (absolute path; default is an auto-created directory)"
	Write-Output "  -n name of the generated saved state (default is application)"
	Write-Output ("  -p library paths file (absolute path; default is " + $paths)
	Write-Output ("  -k hooks file (absolute path; default is " + $hooks)
	Write-Output "  -s settings file (absolute path)"
	Write-Output "  -l loader file for the application (absolute path)"
	Write-Output "  -g startup goal for the saved state in canonical syntax (default is true)"
	Write-Output ("  -v print version of " +  $myName)
	Write-Output "  -h help"
	Write-Output ""
}

function Start-UserInstall()
{
    $process = $env:LOGTALKHOME + '/scripts/logtalk_user_setup.bat'
    Start-Process $process -Wait

    # The following code is a work arount if Logtalkhome use install fails
    # then it will set to LOGTALKHOME at the moment
    if ($null -eq $env:LOGTALKUSER)
    {
        $env:LOGTALKUSER = $env:LOGTALKHOME
    }
}

# check parameters for what is correct or needed
function Update-Parameter()
{
   
    if ($Script:help -eq $true)
    {
        Get-Usage
    }
    if ($Script:version -eq $true)
    {
        Get-ScriptVersion
    }
    if (-not(Test-Path $Script:path)) # cannot be ""
    {
        Write-Output ("The $Script:path library paths file does not exist!")
		Start-Sleep -Seconds 2
        Exit
    }
    if (-not(Test-Path $Script:hooks)) # cannot be ""
    {
        Write-Output ("The " + $Script:hooks + " hooks file does not exist!")
		Start-Sleep -Seconds 2
        Exit
    }
    if (($Script:settings -ne "") -and (-not(Test-Path $Script:settings)))
    {
        Write-Output ("The " + $Script:settings + " settings file does not exist!")
		Start-Sleep -Seconds 2
        Exit
    }
 
    if (($Script:loader -ne "") -and (-not(Test-Path $Script:loader)))
    {
        Write-Output ("The " + $Script:loader + " loader file does not exist!")
		Start-Sleep -Seconds 2
        Exit
    }

    if ($Script:temporary -eq "")
    {
        $Script:temporary = "$pwd\tmp"
    }
  
    if (-not (Test-Path $Script:temporary))
    {
        try
        {
            New-Item $Script:temporary -ItemType Directory
        } 
        catch
        {
            Write-Output ("Could not create temporary directory! at " + $Script:temporary)
            Start-Sleep -Seconds 2
            Exit 
        }
    }
    # Secure format of path string
    $Script:temporary = "$Script:temporary".Replace('\','/')
    $Script:path = "$Script:path".Replace('\','/')
    $Script:hooks = "$Script:hooks".Replace('\','/')
    $Script:directory = "$Script:directory".Replace('\','/')

    if ($Script:settings -ne "") 
    {
        $Script:settings = "$Script:settings".Replace('\','/')
    }
    if ($Script:loader -ne "") 
    {
        $Script:loader = "$Script:loader".Replace('\','/')
    }
}

###################### here it starts ############################ 
# Determing OS
$Architecture = (Get-WmiObject -class Win32_OperatingSystem).OSArchitecture
$Name = (Get-WmiObject -class Win32_OperatingSystem).Caption
Write-Output "Script running on $Name - $Architecture"
if ($Architecture -eq "32-bit")
{   
    $StdProgramDir = 'C:\Program Files\Logtalk'
}
if ($Architecture -eq "64-bit")
{
    $StdProgramDir = 'C:\Program Files (x86)\Logtalk'
}


$StartupBackup = $Env:LOGTALK_STARTUP_DIRECTORY

Get-Logtalkhome

# Check for existence
if (Test-Path $env:LOGTALKHOME)
{
    $output = "Found LOGTALKHOME at: $env:LOGTALKHOME"
    Write-Output $output
}
else
{
    Write-Output "... unable to locate Logtalk installation directory!"
	Start-Sleep -Seconds 2
    Exit
}

Update-Parameter
Push-Location $temporary

if ($null -eq $env:LOGTALKUSER)
{
    # $env:LOGTALKUSER = $env:USERPROFILE + '/Documtents/Logtalk'
    Write-Output "Cannot find $LOGTALKUSER directory! Creating a new Logtalk user directory"
    Write-Output "by running the 'logtalk_user_setup' shell script:"
    Start-UserInstall
}
else
{
    if (Test-Path ($env:LOGTALKUSER + '\version.txt'))
    {
        [String]$UserVersion =  Get-Content $env:LOGTALKUSER/version.txt
        [String]$SystemVersion =  Get-Content $env:LOGTALKHOME/version.txt
        Write-Output ("User Version: $UserVersion; System version: $SystemVersion")

        if ($UserVersion -lt $SystemVersion)
        {
            Write-Output "Logtalk user directory at $env:LOGTALKUSER is outdated: "
 			Write-Output "    $UserVersion < $SystemVersion"
 			Write-Output "Creating an up-to-date Logtalk user directory..."
            Start-UserInstall
        }
    }
    else
    {
        Write-output "Cannot find version information in the Logtalk user directory at $LOGTALKUSER!"
		Write-output "Creating an up-to-date Logtalk user directory..."
        Start-UserInstall
    }
}

# Depending on Windows version create Logtalk User


###

Copy-Item ($env:LOGTALKHOME + '\adapters\swi.pl') .
Copy-Item ($env:LOGTALKHOME + '\core\core.pl') .
$ScratchDirOption = ", scratch_directory('$temporary')])"

$GoalParam = "logtalk_compile([core(expanding), core(monitoring), core(forwarding), core(user), core(logtalk), core(core_messages)],[optimize(on)" + $ScratchDirOption
../swilgt.ps1 -goal $GoalParam -terminate "halt" 

if ($compile -eq $true)
{
    $GoalParam = "logtalk_load(library(expand_library_alias_paths_loader)),logtalk_compile('$path',[hook(expand_library_alias_paths)" + $ScratchDirOption
    ../swilgt.ps1 -goal $GoalParam -terminate "halt" 

}
else
{
    Copy-Item $path $temporary/paths_lgt.pl
}

if ($settings -eq "")
{
    Get-Content swi*.pl, 
        paths_*.pl, 
        expanding*_lgt.pl, 
        monitoring*_lgt.pl, 
        forwarding*_lgt.pl, 
        user*_lgt.pl, 
        logtalk*_lgt.pl, 
        core_messages_*lgt.pl, 
        core.pl, 
        $hooks | Set-Content logtalk.pl
}
else
{
    if ($compile -eq $true)
    {
        $GoalParam = "logtalk_load(library(expand_library_alias_paths_loader)),logtalk_compile('$settings',[hook(expand_library_alias_paths),optimize(on)" + $ScratchDirOption
        ../swilgt.ps1 -goal $GoalParam -terminate "halt" 
    }
    else
    {
        $GoalParam = "logtalk_compile('$settings',[optimize(on)" + $ScratchDirOption 
        ../swilgt.ps1 -goal $GoalParam -terminate "halt" 
    }

    Get-Content swi.pl,
		paths_*.pl,
		expanding*_lgt.pl,
		monitoring*_lgt.pl,
		forwarding*_lgt.pl,
		user*_lgt.pl,
		logtalk*_lgt.pl,
		core_messages*_lgt.pl,
		settings*_lgt.pl,
		core.pl,
		$hooks | Set-Content logtalk.pl
}

swipl -g "qcompile(logtalk)" -t "halt"

Copy-item ./logtalk.qlf $directory

if ($loader -ne "")
{
    try
    {
        New-Item $temporary/application -ItemType Directory
        Push-Location $temporary/application
    }
    catch
    {
         Write-Output ("Could not create temporary directory! at $temporary/application")
         Start-Sleep -Seconds 2
         # a pop-location isn't needed becaus if try fails Push was not executed
         Exit 
    }

    $GoalParam = "consult('$directory/logtalk'), set_logtalk_flag(clean,off), set_logtalk_flag(scratch_directory,'" + $temporary + "/application'), logtalk_load('" + $loader + "')" 
   
    swipl -g $GoalParam -t "halt"
    Get-Item *.pl | 
        Sort-Object -Property @{Expression = "LastWriteTime"; Descending = $false} |
        Get-Content |
        Set-Content application.pl

    $GoalParam = "consult('$directory/logtalk'), qcompile(application)"
    swipl -g $GoalParam -t "halt"
   
    Copy-Item application.qlf $directory
    Pop-Location
}


if ($save_state -eq $true)
{
    Push-Location $directory
    if ($loader -ne "")
    {
        $GoalParam = "consult([logtalk, application]), qsave_program('$name', [goal($goal), stand_alone(true)])"
        swipl -g $GoalParam -t "halt"
    }
    else
    {
        $GoalParam = "[logtalk], qsave_program('$name', [goal($goal), stand_alone(true)])"
        swipl -g $GoalParam -t "halt"
    }
    Pop-Location
}

# restor situation at start
Pop-Location 
$Env:LOGTALK_STARTUP_DIRECTORY = $StartupBackup

try
{
    Remove-Item $temporary -Confirm -Recurse
}
catch
{
    Write-Output ("Error occured at clean-up")
    
}
