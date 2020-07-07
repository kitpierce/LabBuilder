function Get-Lab
{
    [CmdLetBinding()]
    [OutputType([XML])]
    param
    (
        [Parameter(
            Position = 1,
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ConfigPath,

        [Parameter(
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $labPath,

        [Parameter(
            Position = 3)]
        [Switch]
        $SkipXMLValidation
    )

    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}
    }
    process {
        # Convert relative path to absolute path
        if (-not [System.IO.Path]::IsPathRooted($ConfigPath))
        {
            Write-Debug "${callName}Converting relative path to absolute path: '$ConfigPath'"
            $ConfigPath = Join-Path `
                -Path (Get-Location).Path `
                -ChildPath $ConfigPath
        } # if

        Write-Debug "${callName}Using 'ConfigPath' value: '$ConfigPath'"

        if (-not (Test-Path -Path $ConfigPath))
        {
            $exceptionParameters = @{
                errorId       = 'ConfigurationFileNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.ConfigurationFileNotFoundError `
                        -f $ConfigPath)
            }
            New-LabException @exceptionParameters
        } # if

        Write-Debug "${callName}Invoking 'Get-Content' for path: '$ConfigPath'"
        $content = Get-Content -Path $ConfigPath -Raw

        if (-not $content)
        {
            $exceptionParameters = @{
                errorId       = 'ConfigurationFileEmptyError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.ConfigurationFileEmptyError `
                        -f $ConfigPath)
            }
            New-LabException @exceptionParameters
        } # if

        if (-not $SkipXMLValidation)
        {
            # Validate the XML
            Write-Debug "${callName}Validating XML file content"
            Assert-LabValidConfigurationXMLSchema `
                -ConfigPath $ConfigPath `
                -ErrorAction Stop
        }
        else {
            Write-Debug "${callName}Explicitly skipping XML file validation"
        }

        # The XML passes the Schema check so load it.
        $lab = New-Object -TypeName System.Xml.XmlDocument
        $lab.PreserveWhitespace = $true
        $lab.LoadXML($content)

        # Check the Required Windows Build
        $requiredWindowsBuild = $lab.labbuilderconfig.settings.requiredwindowsbuild
        Write-Debug "${callName}Using Windows required build: '$requiredWindowsBuild'"

        if ($requiredWindowsBuild -and `
            ($script:currentBuild -lt $requiredWindowsBuild))
        {
            $exceptionParameters = @{
                errorId       = 'RequiredBuildNotMetError'
                errorCategory = 'InvalidArgument'
                errorMessage  = $($LocalizedData.RequiredBuildNotMetError `
                        -f $script:currentBuild, $requiredWindowsBuild)
            }
            New-LabException @exceptionParameters
        } # if

        <#
            Figure out the Config path and load it into the XML object (if we can)
            This path is used to find any additional configuration files that might
            be provided with config
        #>
        [System.String] $ConfigPath = [System.IO.Path]::GetDirectoryName($ConfigPath)
        Write-Debug "${callName}Received 'GetDirectoryName' method data from ConfigPath: '$ConfigPath'"
        [System.String] $xmlConfigPath = $lab.labbuilderconfig.settings.configpath
        Write-Debug "${callName}Received 'XmlConfigPath' from XML data: '$XmlConfigPath'"

        if ($xmlConfigPath)
        {
            $xmlConfigPath = ConvertTo-LabAbsolutePath -Path $xmlConfigPath -BasePath $labPath
        }
        else
        {
            [System.String] $fullConfigPath = $ConfigPath
        }

        Write-Debug "${callName}Setting XML 'FullConfigPath' attribute: '$FullConfigPath'"
        $lab.labbuilderconfig.settings.setattribute('fullconfigpath', $fullConfigPath)

        # if the LabPath was passed as a parameter, set it in the config
        if ($labPath)
        {
            Write-Debug "${callName}Setting XML 'LabPath' attribute using passed parameter: '$labPath'"
            $lab.labbuilderconfig.settings.SetAttribute('labpath', $labPath)
        }
        else
        {
            [System.String] $labPath = $lab.labbuilderconfig.settings.labpath
            Write-Debug "${callName}No 'LabPath' parameter, setting using XML attribute: '$labPath'"
        }

        # Get the VHDParentPathFull - if it isn't supplied default
        [System.String] $vhdParentPath = $lab.labbuilderconfig.settings.vhdparentpath

        if (-not $vhdParentPath)
        {
            $vhdParentPath = 'Virtual Hard Disk Templates'
        }

        # if the resulting parent path is not rooted make the root the Lab Path
        Write-Debug "${callName}Validating absolute 'VhdParentPath' value: '$vhdParentPath'"
        $vhdParentPath = ConvertTo-LabAbsolutePath -Path $vhdParentPath -BasePath $labPath
        $lab.labbuilderconfig.settings.setattribute('vhdparentpathfull', $vhdParentPath)

        # Get the DSCLibraryPathFull - if it isn't supplied default
        [System.String] $dscLibraryPath = $lab.labbuilderconfig.settings.dsclibrarypath

        if (-not $dscLibraryPath)
        {
            $dscLibraryPath = Get-LabBuilderModulePath | Join-Path -ChildPath 'dsclibrary'
        } # if

        # if the resulting parent path is not rooted make the root the Full config path
        Write-Debug "${callName}Validating absolute 'DscLibraryPath' value: '$dscLibraryPath'"
        $dscLibraryPath = ConvertTo-LabAbsolutePath -Path $dscLibraryPath -BasePath $labPath
        $lab.labbuilderconfig.settings.setattribute('dsclibrarypathfull', $dscLibraryPath)

        # Get the ResourcePathFull - if it isn't supplied default
        [System.String] $resourcePath = $lab.labbuilderconfig.settings.resourcepath

        if (-not $resourcePath)
        {
            $resourcePath = 'Resource'
        } # if

        # if the resulting Resource path is not rooted make the root the Lab Path
        Write-Debug "${callName}Validating absolute 'ResourcePath' value: '$resourcePath'"
        $resourcePath = ConvertTo-LabAbsolutePath -Path $resourcePath -BasePath $labPath
        $lab.labbuilderconfig.settings.setattribute('resourcepathfull', $resourcePath)

        <#
            Determine the ModulePath where alternate Lab PowerShell Modules can be found.
            If a path is specified but it is relative, make it relative to the lab path.
            Otherwise use it as is.
        #>
        [System.String] $modulePath = $lab.labbuilderconfig.settings.modulepath

        if ($modulePath)
        {
            $modulePath = ConvertTo-LabAbsolutePath -Path $modulePath -BasePath $labPath

            # If the path is not included in the PSModulePath add it
            if (-not $env:PSModulePath.ToLower().Contains($modulePath.ToLower() + ';'))
            {
                $env:PSModulePath = "$modulePath;" + $env:PSModulePath
            } # if
        } # if

        Write-Verbose "${callName}Final 'Lab' object detail: $($lab | Format-List * | Out-String)"
        Write-Debug "${callName}Returning 'Lab' object to pipeline"
        return $lab
    } # Get-Lab
}
