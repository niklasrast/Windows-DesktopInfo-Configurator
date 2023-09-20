<#
    .SYNOPSIS 
    Windows 10 Software packaging wrapper

    .DESCRIPTION
    Install:   C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\INSTALL-Desktop-Info.ps1 -install
    Uninstall: C:\Windows\SysNative\WindowsPowershell\v1.0\PowerShell.exe -ExecutionPolicy Bypass -Command .\INSTALL-Desktop-Info.ps1 -uninstall
    
    .ENVIRONMENT
    PowerShell 5.0
    
    .AUTHOR
    Niklas Rast

    .CLASS
    SMALL
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, ParameterSetName = 'install')]
	[switch]$install,
	[Parameter(Mandatory = $true, ParameterSetName = 'uninstall')]
	[switch]$uninstall
)

$ErrorActionPreference = "SilentlyContinue"
#Use "C:\Windows\Logs" for System Installs and "$env:TEMP" for User Installs
$logFile = ('{0}\{1}.log' -f "C:\Windows\Logs", [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name))

#Test if registry folder exists
if ($true -ne (test-Path -Path "HKLM:\SOFTWARE\COMPANY")) {
    New-Item -Path "HKLM:\SOFTWARE\" -Name "COMPANY" -Force
}

if ($install)
{
    Start-Transcript -path $logFile -Append
        try
        {       
            #Stop existing processes
            Stop-Process -Name DesktopInfo64.exe -Force

            #Create app folder
            New-Item -Path "C:\Program Files" -Name "DesktopInfoTool" -ItemType Directory -Force

            #Add File or Folder
            Copy-Item -Path "$PSScriptRoot\DesktopInfo64.exe" -Destination "C:\Program Files\DesktopInfoTool" -Recurse -Force
            Copy-Item -Path "$PSScriptRoot\hostname.ini" -Destination "C:\Program Files\DesktopInfoTool" -Recurse -Force

            #Register schedule task for all users
            $schtaskName = "DesktopInfoTool"
            $schtaskDescription = "Auto-Start for the DesktopInfoTool for all users."
            $runCmd = 'Start-Process -FilePath "C:\Program Files\DesktopInfoTool\DesktopInfo64.exe" -ArgumentList "/ini=C:\Program Files\DesktopInfoTool\hostname.ini"'
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $principal= New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -Id "Author"
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy bypass -windowstyle hidden -command `"$runCmd`""
            $settings= New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger -Action $action -Principal $principal -Settings $settings -Description $schtaskDescription -Force
            Start-ScheduledTask -TaskName $schtaskName

            #Start DesktopInfoTool manually
            #Start-Process -FilePath "C:\Program Files\DesktopInfoTool\DesktopInfo64.exe" -ArgumentList "/ini=C:\Program Files\DesktopInfoTool\hostname.ini"

            #Register package in registry
            New-Item -Path "HKLM:\SOFTWARE\COMPANY\" -Name "Desktop-Info"
            New-ItemProperty -Path "HKLM:\SOFTWARE\COMPANY\Desktop-Info" -Name "Version" -PropertyType "String" -Value "3.1.0" -Force

            return $true        
        } 
        catch
        {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}

if ($uninstall)
{
    Start-Transcript -path $logFile -Append
        try
        {
            #Uninstall EXE
            Stop-Process -Name DesktopInfo64.exe 

            #Unregister schedule task for all users
            $schtaskName = "DesktopInfoTool"
            Unregister-ScheduledTask -TaskName $schtaskName -Confirm:$false

            #Remove File or Folder
            Remove-Item -Path "C:\Program Files\DesktopInfoTool" -Recurse -Force

            #Remove package registration in registry
            Remove-Item -Path "HKLM:\SOFTWARE\COMPANY\Desktop-Info" -Recurse -Force 

            return $true     
        }
        catch
        {
            $PSCmdlet.WriteError($_)
            return $false
        }
    Stop-Transcript
}
