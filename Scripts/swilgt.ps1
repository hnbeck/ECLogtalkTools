#############################################################################
## 
##   Integration script for SWI-Prolog
##   Last updated on May 17, 2018
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
##   Translated to PowerShell by Hans N. Beck (2022)
## 
#############################################################################



<# if ! [ "$LOGTALKHOME" ]; then
	echo "The environment variable LOGTALKHOME should be defined first, pointing"
	echo "to your Logtalk installation directory!"
	echo "Trying the default locations for the Logtalk installation..."
	if [ -d "/usr/local/share/logtalk" ]; then
		LOGTALKHOME=/usr/local/share/logtalk
		echo "... using Logtalk installation found at /usr/local/share/logtalk"
	elif [ -d "/usr/share/logtalk" ]; then
		LOGTALKHOME=/usr/share/logtalk
		echo "... using Logtalk installation found at /usr/share/logtalk"
	elif [ -d "/opt/local/share/logtalk" ]; then
		LOGTALKHOME=/opt/local/share/logtalk
		echo "... using Logtalk installation found at /opt/local/share/logtalk"
	elif [ -d "/opt/share/logtalk" ]; then
		LOGTALKHOME=/opt/share/logtalk
		echo "... using Logtalk installation found at /opt/share/logtalk"
	elif [ -d "$HOME/share/logtalk" ]; then
		LOGTALKHOME="$HOME/share/logtalk"
		echo "... using Logtalk installation found at $HOME/share/logtalk"
	elif [ -f "$( cd "$( dirname "$0" )" && pwd )/../core/core.pl" ]; then
		LOGTALKHOME="$( cd "$( dirname "$0" )" && pwd )/.."
		echo "... using Logtalk installation found at $( cd "$( dirname "$0" )" && pwd )/.."
	else
		echo "... unable to locate Logtalk installation directory!" >&2
		echo
		exit 1
	fi
	echo
	export LOGTALKHOME=$LOGTALKHOME
elif ! [ -d "$LOGTALKHOME" ]; then
	echo "The environment variable LOGTALKHOME points to a non-existing directory!" >&2
	echo "Its current value is: $LOGTALKHOME" >&2
	echo "The variable must be set to your Logtalk installation directory!" >&2
	echo
	exit 1
fi

if ! [ "$LOGTALKUSER" ]; then
	echo "The environment variable LOGTALKUSER should be defined first, pointing"
	echo "to your Logtalk user directory!"
	echo "Trying the default location for the Logtalk user directory..."
	echo
	export LOGTALKUSER=$HOME/logtalk
fi

if [ -d "$LOGTALKUSER" ]; then
	if ! [ -f "$LOGTALKUSER/VERSION.txt" ]; then
		echo "Cannot find version information in the Logtalk user directory at $LOGTALKUSER!"
		echo "Creating an up-to-date Logtalk user directory..."
		logtalk_user_setup
	else
		system_version=$(cat "$LOGTALKHOME/VERSION.txt")
		user_version=$(cat "$LOGTALKUSER/VERSION.txt")
		if [ "$user_version" \< "$system_version" ]; then
			echo "Logtalk user directory at $LOGTALKUSER is outdated: "
			echo "    $user_version < $system_version"
			echo "Creating an up-to-date Logtalk user directory..."
			logtalk_user_setup
		fi
	fi
else
	echo "Cannot find \$LOGTALKUSER directory! Creating a new Logtalk user directory"
	echo "by running the \"logtalk_user_setup\" shell script:"
	logtalk_user_setup
fi
#>
[CmdletBinding()]
param(
    [Parameter()]
    [String]$goal,
    [String]$terminate
)

function Get-Logtalkhome {

    if ($null -eq $env:LOGTALKHOME) 
    {
        Write-Output "The environment variable LOGTALKHOME should be defined first, pointing"
        Write-Output "to your Logtalk installation directory!"
        Write-Output "Trying the default locations for the Logtalk installation..."
       
        # TODO This has to be modified to the correct Window distribution cases
        $DEFAULTPATH = [string[]]( "/usr/local/share/logtalk",
                        "/usr/share/logtalk",
                         "/opt/share/logtalk")
        # One possibility is using HOME environment
        if (-not ($null -eq $env:HOME)) 
        {
            $DEFAULTPATH += $env:HOME + '\share\logtalk' #TODO really correct for windows?
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

Get-Logtalkhome

# Check for existence
if (Test-Path $env:LOGTALKHOME)
{
    $output = "Found LOGTALKHOME at: " + $env:LOGTALKHOME
    Write-Output $output
}
else
{
    Write-Output "... unable to locate Logtalk installation directory!"
	Start-Sleep -Seconds 2
    Exit
}

$env:LOGTALK_STARTUP_DIRECTORY= $pwd

Write-Output ("Compile goal: " + $goal)
$sourcen = $env:LOGTALKHOME + '\integration\logtalk_swi.pl'
#invoke-expression $command

swipl-win.exe -s $sourcen -g $goal -t $terminate
Wait-Process -name swipl-win