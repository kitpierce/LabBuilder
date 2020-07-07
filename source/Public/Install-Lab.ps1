function Install-Lab
{
    [CmdLetBinding(DefaultParameterSetName="Lab")]
    param
    (
        [parameter(
            Position=1,
            ParameterSetName="File",
            Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String] $ConfigPath,

        [parameter(
            Position=2,
            ParameterSetName="File")]
        [ValidateNotNullOrEmpty()]
        [System.String] $LabPath,

        [Parameter(
            Position=3,
            ParameterSetName="Lab",
            Mandatory=$true,
            ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [Parameter(
            Position=4)]
        [Switch] $CheckEnvironment,

        [Parameter(
            Position=5)]
        [Switch] $Force,

        [Parameter(
            Position=6)]
        [Switch] $OffLine

    ) # Param

    begin
    {
        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        if ($DebugPreference -notlike 'SilentlyContinue') {
            $DebugPreference = 'Continue'
        }

        # Create a splat array containing force if it is set
        $ForceSplat = @{}

        if ($PSBoundParameters.ContainsKey('Force'))
        {
            $ForceSplat = @{ Force = $true }
        } # if

        # Remove some PSBoundParameters so we can Splat
        $null = $PSBoundParameters.Remove('CheckEnvironment')
        $null = $PSBoundParameters.Remove('Force')

        if ($CheckEnvironment)
        {
            Write-Debug "${callName}Invoking function 'Install-LabHyperV'"
            # Check Hyper-V
            Install-LabHyperV `
                -ErrorAction Stop
        } # if

        Write-Debug "${callName}Invoking function 'Enable-LabWSMan'"
        # Ensure WS-Man is enabled
        Enable-LabWSMan `
            @ForceSplat `
            -ErrorAction Stop

        if (!($PSBoundParameters.ContainsKey('OffLine')))
        {
        # Install Package Providers
        Write-Debug "${callName}Invoking function 'Install-LabPackageProvider'"
        Install-LabPackageProvider `
            @ForceSplat `
            -ErrorAction Stop

        # Register Package Sources
        Write-Debug "${callName}Invoking function 'Register-LabPackageSource'"
        Register-LabPackageSource `
            @ForceSplat `
            -ErrorAction Stop
        }

        $null = $PSBoundParameters.Remove('Offline')
    } # begin

    process
    {
        if ($PSCmdlet.ParameterSetName -eq 'File')
        {
            # Read the configuration
            Write-Debug "${callName}Invoking function 'Get-Lab"
            $Lab = Get-Lab `
                @PSBoundParameters `
                -ErrorAction Stop
        } # if

        # Initialize the core Lab components
        # Check Lab Folder structure
        Write-LabMessage -Message $($LocalizedData.InitializingLabFoldersMesage)

        # Check folders are defined
        [System.String] $LabPath = $Lab.labbuilderconfig.settings.labpath
        Write-Debug "${callName}Using 'LabPath' value: '${LabPath}'"

        if (-not (Test-Path -Path $LabPath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'LabPath',$LabPath)

            $null = New-Item `
                -Path $LabPath `
                -Type Directory
        }

        [System.String] $VHDParentPath = $Lab.labbuilderconfig.settings.vhdparentpathfull
        Write-Debug "${callName}Using 'VHDParentPath' value: '${VHDParentPath}'"

        if (-not (Test-Path -Path $VHDParentPath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'VHDParentPath',$VHDParentPath)

            $null = New-Item `
                -Path $VHDParentPath `
                -Type Directory
        }

        [System.String] $ResourcePath = $Lab.labbuilderconfig.settings.resourcepathfull
        Write-Debug "${callName}Using 'ResourcePath' value: '${ResourcePath}'"

        if (-not (Test-Path -Path $ResourcePath))
        {
            Write-LabMessage -Message $($LocalizedData.CreatingLabFolderMessage `
                -f 'ResourcePath',$ResourcePath)

            $null = New-Item `
                -Path $ResourcePath `
                -Type Directory
        }

        # Initialize the Lab Management Switch
        Write-Debug "${callName}Invoking function 'Initialize-LabManagementSwitch'"
        Initialize-LabManagementSwitch `
            -Lab $Lab `
            -ErrorAction Stop

        # Download any Resource Modules required by this Lab
        Write-Debug "${callName}Invoking function 'Get-LabResourceModule'"
        $ResourceModules = Get-LabResourceModule `
            -Lab $Lab

        Write-Debug "${callName}Invoking function 'Initialize-LabResourceModule'"
        Initialize-LabResourceModule `
            -Lab $Lab `
            -ResourceModules $ResourceModules `
            -ErrorAction Stop

        # Download any Resource MSUs required by this Lab
        Write-Debug "${callName}Invoking function 'Get-LabResourceMSU'"
        $ResourceMSUs = Get-LabResourceMSU `
            -Lab $Lab

        Write-Debug "${callName}Invoking function 'Initialize-LabResourceMSU'"
        Initialize-LabResourceMSU `
            -Lab $Lab `
            -ResourceMSUs $ResourceMSUs `
            -ErrorAction Stop

        # Initialize the Switches
        Write-Debug "${callName}Invoking function 'Get-LabSwitch'"
        $Switches = Get-LabSwitch `
            -Lab $Lab

        Write-Debug "${callName}Invoking function 'Initialize-LabSwitch'"
        Initialize-LabSwitch `
            -Lab $Lab `
            -Switches $Switches `
            -ErrorAction Stop

        # Initialize the VM Template VHDs
        Write-Debug "${callName}Invoking function 'Get-LabVMTemplateVHD'"
        $VMTemplateVHDs = Get-LabVMTemplateVHD `
            -Lab $Lab

        Write-Debug "${callName}Invoking function 'Initialize-LabVMTemplateVHD'"
        Initialize-LabVMTemplateVHD `
            -Lab $Lab `
            -VMTemplateVHDs $VMTemplateVHDs `
            -ErrorAction Stop

        # Initialize the VM Templates
        Write-Debug "${callName}Invoking function 'Get-LabVMTemplate'"
        $VMTemplates = Get-LabVMTemplate `
            -Lab $Lab

        Write-Debug "${callName}Invoking function 'Initialize-LabVMTemplate'"
        Initialize-LabVMTemplate `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -ErrorAction Stop

        # Initialize the VMs
        Write-Debug "${callName}Invoking function 'Get-LabVM'"
        $VMs = Get-LabVM `
            -Lab $Lab `
            -VMTemplates $VMTemplates `
            -Switches $Switches

        Write-Debug "${callName}Invoking function 'Initialize-LabVM'"
        Initialize-LabVM `
            -Lab $Lab `
            -VMs $VMs `
            -ErrorAction Stop

        Write-LabMessage -Message $($LocalizedData.LabInstallCompleteMessage `
            -f $Lab.labbuilderconfig.name,$Lab.labbuilderconfig.settings.labpath)
    } # process

    end
    {
        Write-Verbose "${callName}Finished lab installation workflow"
    } # end
} # Install-Lab
