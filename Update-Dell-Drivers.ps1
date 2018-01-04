#install CCTK
Start-Process -FilePath .\HAPI\HAPIInstall.bat -wait -WindowStyle Hidden

#runs Dell Command update and exports the xml report
start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/report c:\windows\temp\dell_report.xml /reportall /silent" -Wait -WindowStyle Hidden

#import Dell Reports
$data = [XML](Get-Content c:\windows\temp\dell_report.xml)

foreach($update in $data.updates.update)
    {
        $release = $update.release
        if($update.name -like "*bios*")
            {
                if($osv -like "*windows 10*")
                    {
                        Suspend-BitLocker -MountPoint "C:" -RebootCount 1
                    }
                else
                    {
                        Manage-bde.exe -protectors -disable c:
                    }
                Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd= --valsetuppwd=YOURCURRENTPASSWORD" -Wait -WindowStyle Hidden
                start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
                Start-Process -FilePath .\cctk.exe -ArgumentList "--setuppwd=YOURDESIREDPASSWORD" -Wait -WindowStyle Hidden
            }
        else
            {
                start-process -FilePath ".\dcu-cli.exe" -ArgumentList "/forceupdate $release" -Wait -WindowStyle Hidden
            }
    }