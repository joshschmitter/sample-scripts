function MyFunction (
		[parameter(Mandatory = $false)]
		[String]$Version
	)
{
    function FunctionA ($Version)
    {
        if ($Version)
        {
            return $Version
        }

        try 
        {
            $versionLine = Select-String -Pattern "required_version" -Path "versions.tf"
        }
        catch
        {
            throw "Could not find a versions.tf file in your current directory.  Please specify a version."
        }

        if ($versionLine -match '(?<tfVersion>[0-9]\.[0-9]+\.[0-9]+)')
        {
            # $Matches is a special variable populated by the -match operator if the match returns true.
            return $Matches.tfVersion 
        }
        else
        {
            throw "Failed to find a terraform version in your versions.tf file.  Please specify a version."
        }
    }

    function FunctionB ($version, $installPath)
    {
        # make sure the base install directory exists
        $baseInstallDir = (Split-Path $installPath)

        if (!(Test-Path $baseInstallDir)) {
            $null = New-Item $baseInstallDir -ItemType Directory -Force
        }

        # Download binary
        $url = "https://releases.hashicorp.com/terraform/$($version)/terraform_$($version)_windows_amd64.zip"
        $webClient = New-Object System.Net.WebClient

        try
        {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $webClient.DownloadFile($url, "$installPath.zip")
        }
        catch
        {
            throw "Failed downloading terraform version $version from $url to location $($installPath).zip.`r`n$_"
        }
        finally
        {
            $webClient.Dispose()
        }

        Expand-Archive -Path "$installPath.zip" -DestinationPath $installPath
        Remove-Item "$installPath.zip" -Force
    }

    function FunctionC ($tfExecutableDir)
    {
        $tfPathList = $env:PATH.Split(";").Where({$_ -like "*terraform*"})
        $extraPaths = [array]$tfPathList.Where({$_ -ne $tfExectableDir})

        if ($tfPathList.Count -gt 1 -or $tfExecutableDir -notin $tfPathList)
        {
            Write-Warning "You have duplicate values in your PATH.  Please remove the following paths from your PATH and restart your powershell session:`r`n`r`n$extraPaths"
        }
    }


    #----------# Main #----------#
    $Version = FunctionA $Version
    $VersionPath = "$HOME\.tfVersions\$($Version.Replace(".", "-"))"
    $tfVersionFullName = Join-Path $VersionPath "terraform.exe"
    $tfExecutableDir = "$HOME\Terraform"
    $tfVersionExists = Test-Path (Join-Path $VersionPath "terraform.exe")
    $tfExecutableDirExists = Test-Path $tfExecutableDir

    if (!$tfVersionExists)
    {
        FunctionB $Version $VersionPath
    }

    if (!$tfExecutableDirExists)
    {
        $null = New-Item $tfExecutableDir -ItemType Directory

        [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$tfExecutableDir", "User")
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") # reload path into powershell session
    }

    FunctionC $tfExecutableDir

    Copy-Item -Path $tfVersionFullName -Destination $tfExecutableDir

    terraform -v
}
