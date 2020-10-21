#!/bin/bash
# a script to discover and measure flexlm licence usage
#
# 1. input the template into zabbix server
# 2. put this script into C:\zabbix\ and make it executable
# 3. create a file called /etc/zabbix_agentd.conf.d/flexlm_licence_usage.conf
# and make it contain the following three lines:
#UserParameter=flexlm.discovery,powershell.exe -NoProfile -ExecutionPolicy bypass -File C:\zabbix\flexlm_licence_usage.ps1 discovery
#UserParameter=flexlm.used[*],powershell.exe -NoProfile -ExecutionPolicy bypass -File C:\zabbix\flexlm_licence_usage.ps1 used $1
#UserParameter=flexlm.total[*],powershell.exe -NoProfile -ExecutionPolicy bypass -File C:\zabbix\flexlm_licence_usage.ps1 total $1
# 4. restart the zabbix agent

# capture $1 and $2 before they're lost
$ARG1=$Args[0]
$ARG2=$Args[1]

$LICENCE_FILE="C:\Program Files (x86)\ArcGIS\LicenseManager\service.txt"
$LM_BIN_DIR="C:\Program Files (x86)\ArcGIS\LicenseManager\bin\"
#$LM_BIN_DIR=".\"

# we keep a cache of flexlm status so we don't have to
# keep interrogating the manager daemon
$STAT_FILE="C:\Program Files (x86)\ArcGIS\LicenseManager\bin\stat_file.stat"
$MAX_AGE=-55	# -300 = 5 mins max age of stat file

### cache maintenance ###
# if the stat file exists, then see how old it,
# if too old delete it
if (Test-Path $STAT_FILE -OlderThan (Get-Date).AddSeconds($MAX_AGE))
{
    Remove-Item $STAT_FILE;
    #echo "Debug, deleting too old stat file"
}


# generate the stat file if it doesn't exist
if (-Not (Test-Path $STAT_FILE)) {
	& $LM_BIN_DIR"lmutil.exe" lmstat -a -c 27000@localhost | Select-String  -Pattern "^Users of" | % {$_ -replace("\:","")} > $STAT_FILE
}


if (-Not ((Test-Path $STAT_FILE) -AND ((Get-Item $STAT_FILE).length -gt '0')))
 { echo "-999" }

 #### handle the specific query from zabbix ###
 


if ($ARG1 -eq "discovery") {
    $FEATURES= Get-Content -Path $STAT_FILE | %{ $_.Split(' ')[2]; }
    

    Write-Host '{"data":[' -NoNewLine
    $FIRSTLOOP=1

    ForEach ($FF in $FEATURES)
    {
        if ($FIRSTLOOP -eq 0) {
            Write-Host ", " -NoNewLine
        }
            Write-Host '{"{#FEATURE}":" ' $FF ' "}' -NoNewLine
            $FIRSTLOOP=0
    }
   

    Write-Host "]}" -NoNewLine

    } 
 else
  {
  

    if ($ARG1 -eq "total") {
        $value = Get-Content -Path $STAT_FILE | Where-Object{$_ -match " $ARG2 "} | %{ $_.Split(' ')[6] };
    }
    elseif ($ARG1 -eq "used") {
        $value = Get-Content -Path $STAT_FILE | Where-Object{$_ -match " $ARG2 "} | %{ $_.Split(' ')[12] };
    }
    else {
        $value = -5 
        }
        Write-Host $value
  }



# end of hacky zabbix agent-side flexlm_check extension
