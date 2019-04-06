<#
    .SYNOPSIS
        Get a list of all Resources imported in a DSC Config

    .DESCRIPTION
        Uses RegEx to pull a list of Resources that are imported in a DSC Configuration using the
        Import-DSCResource cmdlet.

        If The -ModuleVersion parameter is included then the ModuleVersion property in the returned
        LabDSCModule object will be set, otherwise it will be null.

    .PARAMETER DSCConfigFile
        Contains the path to the DSC Config file to extract resource module names from.

    .PARAMETER DSCConfigContent
        Contains the content of the DSC Config to extract resource module names from.

    .EXAMPLE
        Get-LabModulesInDSCConfig -DSCConfigFile c:\mydsc\Server01.ps1
        Return the DSC Resource module list from file c:\mydsc\server01.ps1

    .EXAMPLE
        Get-LabModulesInDSCConfig -DSCConfigContent $DSCConfig
        Return the DSC Resource module list from the DSC Config in $DSCConfig.

    .OUTPUTS
        An array of LabDSCModule objects containing the DSC Resource modules required by this DSC
        configuration file.
#>
function Get-LabModulesInDSCConfig
{
    [CmdLetBinding(DefaultParameterSetName = "Content")]
    [OutputType([Object[]])]
    Param
    (
        [parameter(
            Position = 1,
            ParameterSetName = "Content",
            Mandatory = $true)]
        [System.String] $dscConfigContent,

        [parameter(
            Position = 2,
            ParameterSetName = "File",
            Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $DSCConfigFile
    )

    [LabDSCModule[]] $modules = $null

    if ($PSCmdlet.ParameterSetName -eq 'File')
    {
        $dscConfigContent = Get-Content -Path $DSCConfigFile -Raw
    } # if

    $regex = "[ \t]*?Import\-DscResource[ \t]+(?:\-ModuleName[ \t])?'?`"?([A-Za-z0-9._-]+)`"?'?(([ \t]+-ModuleVersion)?[ \t]+'?`"?([0-9.]+)`"?`?)?[ \t]*?[\r\n]+?"
    $moduleMatches = [regex]::matches($dscConfigContent, $regex, 'IgnoreCase')

    foreach ($moduleMatch in $moduleMatches)
    {
        $moduleName = $moduleMatch.Groups[1].Value
        $moduleVersion = $moduleMatch.Groups[4].Value
        # Make sure this module isn't already in the list

        if ($moduleName -notin $Modules.ModuleName)
        {
            $module = [LabDSCModule]::New($moduleName)

            if (-not [System.String]::IsNullOrWhitespace($moduleVersion))
            {
                $module.moduleVersion = [Version] $moduleVersion
            } # if

            $modules += @( $module )
        } # if
    } # foreach

    return $modules
}
