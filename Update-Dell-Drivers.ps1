$osv = (get-wmiobject win32_operatingsystem).caption

#install CCTK
Start-Process -FilePath .\HAPI\HAPIInstall.bat -wait -WindowStyle Hidden

#runs Dell Command update and exports the xml report
start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/report c:\windows\temp\dell_report.xml /reportall /silent" -Wait -WindowStyle Hidden

#import Dell Reports
$data = [XML](Get-Content c:\windows\temp\dell_report.xml)

foreach($update in $data.updates.update)
    {
        $release = $update.release
        if($update.name -like "*bios*" -or $update.name -like "*thunderbolt*")
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
                Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd= --valsetuppwd=YOURCURRENTPASSWORD" -Wait -WindowStyle Hidden
                #install BIOS update
                Start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
                #enable bios password with dell cctk
                Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd=YOURDESIREDPASSWORD" -Wait -WindowStyle Hidden
            }
        else
            {
                start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
            }
    }
