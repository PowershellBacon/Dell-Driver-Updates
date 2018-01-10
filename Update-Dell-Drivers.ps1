<#
.SYNOPSIS
    .

.DESCRIPTION
    This script will leverage the Dell CCTK and Dell Command Update to check for and apply BIOS, Firmware, and Driver updates.
    This can be used as part of a task sequence and independently via the software center.

.PARAMETER action
    This allows you to specify the type of update that you would like to check for and apply.

.EXAMPLE
    C:\PS> Update-Dell-Drivers -action All
    
    This will check for and apply all types of updates. Applications, BIOS, Drivers, Firmware, etc.

.EXAMPLE
    C:\PS> Update-Dell-Drivers -action BIOS
    
    This will check for and apply BIOS updates.

.EXAMPLE
    C:\PS> Update-Dell-Drivers -action Display
    
    This will check for and apply display driver updates.

.EXAMPLE
    C:\PS> Update-Dell-Drivers -action Drivers
    
    This will check for and apply all driver and firmware updates.

.NOTES
    Author: PowershellBacon
    Date  : January 05, 2018  
    Original Source: https://github.com/PowershellBacon/Dell-Driver-Updates
    Updated by: AFJ001@shsu.edu
    Updated on: January 09, 2018
#>



param(
[Parameter (Mandatory=$true)]
[Validateset("All","BIOS","Display","Drivers")]
[string]$action
)

#homogenize parameter and prepare for script
$action=$action.ToUpper()
If (Test-Path c:\windows\temp\dell_report.xml)
{
    Remove-Item c:\windows\temp\dell_report.xml
}

#install CCTK
Write-Host -ForegroundColor Green "Preparing the Dell CCTK for use..."
Start-Process -FilePath .\HAPI\HAPIInstall.bat -wait -WindowStyle Hidden

#process the parameter to check for the appropriate updates
switch ($action)
{
    "All" 
        {
            Write-Host -ForegroundColor Green "Checking for all update types..."
            Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/report c:\windows\temp\dell_report.xml /reportall /silent" -Wait -WindowStyle Hidden
        }
    "BIOS" 
        {
            Write-Host -ForegroundColor Green "Checking for BIOS updates..."
            Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/policy .\BIOS.xml /report c:\windows\temp\dell_report.xml /silent" -Wait -WindowStyle Hidden
        }
    "DISPLAY" 
        {
            Write-Host -ForegroundColor Green "Checking for display drivers..."
            Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/policy .\Display.xml /report c:\windows\temp\dell_report.xml /silent" -Wait -WindowStyle Hidden
        }
    "DRIVERS" 
        {
            Write-Host -ForegroundColor Green "Checking for all device drivers..."
            Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/policy .\Drivers.xml /report c:\windows\temp\dell_report.xml /silent" -Wait -WindowStyle Hidden
        }
}
#runs Dell Command update and exports the xml report


#import Dell Reports
Try
{
    $data = [XML](Get-Content c:\windows\temp\dell_report.xml -ErrorAction stop)
}
Catch
{
    Write-Host -ForegroundColor Yellow "No updates available at this time."
    Exit
}

#check to see if the $osv value is set, if not set it to the current OS Version
If ($osv -eq $null)
{
    $osv = (Get-WmiObject win32_OperatingSystem).caption
}

#Test to see if the report xml is generated from above. If not it will assume there are no updates and exit.
If (Test-Path c:\windows\temp\dell_report.xml)
{
    foreach($update in $data.updates.update)
        {
            $release = $update.release
            Write-Host -ForegroundColor green "Installing: " -NoNewline; Write-Host -ForegroundColor white $update.name
            if($update.name -like "*bios*" -OR $update.name -like "*thunderbolt*") #BIOS and thunderbolt firmware updates require disabling of BIOS passwords and suspending bitlocker for a reboot.
                {
                    #bitlocker Check, powershell for windows10, manage-bde for windows 7
                    if($osv -like "*windows 10*")
                        {
                            Suspend-BitLocker -MountPoint "C:" -RebootCount 1
                        }
                    else
                        {
                            Manage-bde.exe -protectors -disable c:
                        }
                    #disable bios password with dell cctk
                    Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd= --valsetuppwd=password" -Wait -WindowStyle Hidden
                    #install BIOS update
                    Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
                    #enable bios password with dell cctk
                    Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd=password" -Wait -WindowStyle Hidden
                }
            else
                {
                    Start-Process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
                }
        }
}
Else
{
    Write-Host -ForegroundColor Red "Something didn't go as planned."
    Exit
}