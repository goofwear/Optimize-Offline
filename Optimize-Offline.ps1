﻿#Requires -RunAsAdministrator
#Requires -Version 5
#Requires -Module Dism
<#
	.SYNOPSIS
		Optimize-Offline is a Windows Image (WIM) optimization script designed for Windows 10 builds 1803-to-1903 64-bit architectures.

	.DESCRIPTION
		Primary focus' are the removal of unnecessary bloat, enhanced privacy, cleaner aesthetics, increased performance and a significantly better user experience.

	.PARAMETER SourcePath
		The path to a Windows 10 Installation ISO or install.wim

	.PARAMETER WindowsApps
		Accepts one of the three values that determines the method in which Appx Provisioned Packages are removed:

		Select = Populates and outputs a Gridview list of all Appx Provisioned Packages for selective removal.
		All = Automatically removes all Appx Provisioned Packages found in the image.
		Whitelist = Automatically removes all Appx Provisioned Packages NOT found in the AppxWhiteList.xml file.

	.PARAMETER SystemApps
		Populates and outputs a Gridview list of all System Applications for selective removal.
		Four System Applications that can be removed use a GUID namespace instead of an identifiable name:

		1527c705-839a-4832-9118-54d4Bd6a0c89 = Microsoft.Windows.FilePicker
		c5e2524a-ea46-4f67-841f-6a9465d9d515 = Microsoft.Windows.FileExplorer
		E2A4F912-2574-4A75-9BB0-0D023378592B = Microsoft.Windows.AppResolverUX
		F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE = Microsoft.Windows.AddSuggestedFoldersToLibraryDialog

	.PARAMETER Packages
		Populates and outputs a Gridview list of all Windows Capability Packages for selective removal.

	.PARAMETER Features
		Populates and outputs a Gridview list of all Windows Optional Features for selective disabling or enabling.

	.PARAMETER WindowsStore
		Integrates the Microsoft Windows Store and dependencies into the image.
		Only applicable for Windows 10 Enterprise LTSC 2019.

	.PARAMETER MicrosoftEdge
		Integrates the Microsoft Edge Browser into the image.
		Only applicable for Windows 10 Enterprise LTSC 2019.

	.PARAMETER Win32Calc
		Integrates the traditional Win32 Calculator into the image.
		NOT applicable for Windows 10 Enterprise LTSC 2019.

	.PARAMETER Dedup
		Integrates the Windows Server Data Deduplication Feature into the image.

	.PARAMETER DaRT
		Integrates the Microsoft Diagnostic and Recovery Toolset (DaRT 10) and Windows 10 Debugging Tools into Windows Setup and Windows Recovery.

	.PARAMETER Registry
		Integrates optimized registry values into the image.

	.PARAMETER Additional
		Integrates user specific content in the "Content/Additional" directory based on the parameters set in the Config.ini.

	.PARAMETER ISO
		Creates a new bootable Windows Installation Media ISO.
		Applicable only when a Windows Installation Media ISO is used as the source image.
		Accepts one of two values that determines the boot-type of the ISO:

		Prompt = The efisys.bin binary bootcode is written to the ISO which requires a key press when booted to begin Windows Setup.
		No-Prompt = The efisys_noprompt.bin binary bootcode is written to the ISO which does not require a key press when booted and will begin Windows Setup automatically.

	.EXAMPLE
		.\Optimize-Offline.ps1 -SourcePath "D:\Win10Pro\Win10Pro_Full.iso" -WindowsApps "Select" -SystemApps -Packages -Features -Win32Calc -Dedup -DaRT -Registry -ISO "No-Prompt"

	.EXAMPLE
		.\Optimize-Offline.ps1 -SourcePath "D:\Windows 10 ISOs\Win10ProForWorkstations_17663.iso" -WindowsApps "All" -SystemApps -Packages -Features -Additional -ISO "Prompt"

	.EXAMPLE
		.\Optimize-Offline.ps1 -SourcePath "D:\Win Images\install.wim" -WindowsApps "Whitelist" -SystemApps -Packages -Features -Dedup -Registry -Additional

	.EXAMPLE
		.\Optimize-Offline.ps1 -SourcePath "D:\Win10 LTSC 2019\install.wim" -SystemApps -Packages -Features -WindowsStore -MicrosoftEdge -Registry -DaRT

	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.167
		Created by:     BenTheGreat
		Filename:     	Optimize-Offline.ps1
		Version:        3.2.7.0
		Last updated:	09/03/2019
		===========================================================================

	.INPUTS
		IO.FileInfo

	.LINK
		https://github.com/DrEmpiricism/Optimize-Offline
#>
[CmdletBinding(HelpUri = 'https://github.com/DrEmpiricism/Optimize-Offline')]
Param
(
    [Parameter(Mandatory = $true,
        Position = 0,
        HelpMessage = 'The path to a Windows 10 Installation ISO or install.wim')]
    [ValidateScript( {
            If ((Test-Path -Path (Resolve-Path -Path $_)) -and ($_ -ilike "*.iso")) { $_ }
            ElseIf ((Test-Path -Path (Resolve-Path -Path $_)) -and ($_ -ilike "*.wim")) { $_ }
            Else { Write-Warning ('Invalid source path: "{0}"' -f $($_)); Break }
        })]
    [IO.FileInfo]$SourcePath,
    [Parameter(Mandatory = $false,
        HelpMessage = 'Determines the method in which Appx Provisioned Packages are removed.')]
    [ValidateSet('Select', 'All', 'Whitelist')]
    [string]$WindowsApps,
    [Parameter(HelpMessage = 'Populates and outputs a Gridview list of all System Applications for selective removal.')]
    [switch]$SystemApps,
    [Parameter(HelpMessage = 'Populates and outputs a Gridview list of all Windows Capability Packages for selective removal.')]
    [switch]$Packages,
    [Parameter(HelpMessage = 'Populates and outputs a Gridview list of all Windows Optional Features for selective disabling or enabling.')]
    [switch]$Features,
    [Parameter(HelpMessage = 'Integrates the Microsoft Windows Store and dependencies into the image.')]
    [switch]$WindowsStore,
    [Parameter(HelpMessage = 'Integrates the Microsoft Edge Browser into the image.')]
    [switch]$MicrosoftEdge,
    [Parameter(HelpMessage = 'Integrates the traditional Win32 Calculator into the image.')]
    [switch]$Win32Calc,
    [Parameter(HelpMessage = 'Integrates the Windows Server Data Deduplication Feature into the image.')]
    [switch]$Dedup,
    [Parameter(HelpMessage = 'Integrates the Microsoft Diagnostic and Recovery Toolset (DaRT 10) and Windows 10 Debugging Tools into Windows Setup and Windows Recovery.')]
    [switch]$DaRT,
    [Parameter(HelpMessage = 'Integrates optimized registry values into the image.')]
    [switch]$Registry,
    [Parameter(HelpMessage = 'Integrates user specific content in the "Content/Additional" directory based on the parameters set in the Config.ini.')]
    [switch]$Additional,
    [Parameter(Mandatory = $false,
        HelpMessage = 'Creates a new bootable Windows Installation Media ISO.')]
    [ValidateSet('Prompt', 'No-Prompt')]
    [string]$ISO
)

#region Script Variables
$DefaultVariables = (Get-Variable).Name
$Host.UI.RawUI.BackgroundColor = 'Black'; Clear-Host
$ScriptInfo = [PSCustomObject]@{ Name = 'Optimize-Offline'; Version = '3.2.7.0' }
#endregion Script Variables

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Warning "Elevation is required to process optimizations. Relaunch $($ScriptInfo.Name) as an administrator."
    Break
}

If (((Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) -notlike "Microsoft Windows 10*") -and ((Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption) -notlike "Microsoft Windows Server 2016*"))
{
    Write-Warning "$($ScriptInfo.Name) requires a Windows 10 or Windows Server 2016 environment."
    Break
}

If (!(Test-Path -Path "$PSScriptRoot\Lib\Functions.psm1"))
{
    Write-Warning ('The required functions module is missing from "{0}"' -f $(Split-Path -Path "$PSScriptRoot\Lib\Functions.psm1" -Parent))
    Break
}

Try
{
    Import-Module "$PSScriptRoot\Lib\Functions.psm1" -ErrorAction Stop
}
Catch
{
    Write-Warning ('Failed to import the required module: {0}' -f $(Split-Path -Path "$PSScriptRoot\Lib\Functions.psm1" -Leaf))
    Break
}

If (Get-WindowsImage -Mounted)
{
    $Host.UI.RawUI.WindowTitle = "Performing clean-up of current mount path."
    Write-Host "Performing clean-up of current mount path." -ForegroundColor Cyan
    Dismount-Images; Clear-Host
}

Try
{
    Set-Location -Path $PSScriptRoot
    [void](Clear-WindowsCorruptMountPoint)
    Get-ChildItem -Path $PSScriptRoot -Filter "OptimizeOfflineTemp_*" -Directory | Remove-Container
    @("$TempDirectory", $InstallMount, $ImageDirectory, $WorkDirectory, $ScratchDirectory, $LogDirectory) | New-Container
    $Timer = New-Object System.Diagnostics.Stopwatch
}
Catch
{
    Write-Warning $($_.Exception.Message)
    Get-ChildItem -Path $PSScriptRoot -Filter "OptimizeOfflineTemp_*" -Directory | Remove-Container
    Break
}

If ($SourcePath.Extension -eq '.ISO')
{
    $ISOMount = (Mount-DiskImage -ImagePath $($SourcePath.FullName) -StorageType ISO -PassThru | Get-Volume).DriveLetter + ':'
    [void](Get-PSDrive)
    If (!(Test-Path -Path "$($ISOMount)\sources\install.wim"))
    {
        Write-Warning ('"{0}" does not contain valid Windows Installation media.' -f $($SourcePath.Name))
        [void](Dismount-DiskImage -ImagePath $($SourcePath.FullName) -StorageType ISO)
        $TempDirectory | Remove-Container
        Break
    }
    Else
    {
        $ISOMedia = New-Container -Path (Join-Path -Path $TempDirectory -ChildPath $SourcePath.BaseName) -PassThru
        Try
        {
            Write-Host ('Exporting media from "{0}"' -f $($SourcePath.Name)) -ForegroundColor Cyan
            ForEach ($Item In Get-ChildItem -Path $ISOMount -Recurse)
            {
                $ISOExport = $ISOMedia.FullName + $Item.FullName.Replace($ISOMount, $null)
                Copy-Item -Path $($Item.FullName) -Destination $ISOExport
            }
            Get-ChildItem -Path "$($ISOMedia)\sources" -Include install.wim, boot.wim -Recurse | Move-Item -Destination $ImageDirectory
            $InstallWim = Get-ChildItem -Path $ImageDirectory -Filter install.wim | Select-Object -ExpandProperty FullName
            $BootWim = Get-ChildItem -Path $ImageDirectory -Filter boot.wim | Select-Object -ExpandProperty FullName
            @($InstallWim, $BootWim) | ForEach-Object { Set-ItemProperty -Path $($_) -Name IsReadOnly -Value $false }
        }
        Catch
        {
            Write-Error $($_.Exception.Message)
            $TempDirectory | Remove-Container
            Break
        }
        Finally
        {
            [void](Dismount-DiskImage -ImagePath $($SourcePath.FullName) -StorageType ISO)
        }
    }
}
ElseIf ($SourcePath.Extension -eq '.WIM')
{
    Try
    {
        Write-Host ('Copying WIM from "{0}"' -f $($SourcePath.DirectoryName)) -ForegroundColor Cyan
        Copy-Item -Path $($SourcePath.FullName) -Destination $ImageDirectory
        Get-ChildItem -Path $ImageDirectory -Filter $($SourcePath.Name) | Rename-Item -NewName install.wim
        $InstallWim = Get-ChildItem -Path $ImageDirectory -Filter install.wim | Select-Object -ExpandProperty FullName
        Set-ItemProperty -Path $InstallWim -Name IsReadOnly -Value $false
    }
    Catch
    {
        Write-Error $($_.Exception.Message)
        $TempDirectory | Remove-Container
        Break
    }
    Finally
    {
        If ($ISO) { Remove-Variable ISO }
    }
}

If ((Get-WindowsImage -ImagePath $InstallWim).Count -gt 1)
{
    Do
    {
        $EditionList = Get-WindowsImage -ImagePath $InstallWim | Select-Object -Property @{ Label = 'Index'; Expression = { ($_.ImageIndex) } }, @{ Label = 'Name'; Expression = { ($_.ImageName) } }, @{ Label = 'Size (GB)'; Expression = { '{0:N2}' -f ($_.ImageSize / 1GB) } } | Out-GridView -Title "Select Windows 10 Edition." -OutputMode Single
        $ImageIndex = $EditionList.Index
    }
    While ($EditionList.Length -eq 0)
}
Else { $ImageIndex = 1 }

Try
{
    $InstallWimInfo = Get-WimFileInfo -WimFile $InstallWim -Index $ImageIndex -ErrorAction Stop
}
Catch
{
    Write-Warning "Failed to retrieve all image metadata."
    Remove-Container -Path $TempDirectory
    Break
}

If (!$InstallWimInfo.Version.StartsWith(10))
{
    Write-Warning "Unsupported Image Version: [$($InstallWimInfo.Version)]"
    $TempDirectory | Remove-Container
    Break
}

If ($InstallWimInfo.Architecture -ne 'amd64')
{
    Write-Warning "Unsupported Image Architecture: [$($InstallWimInfo.Architecture)]"
    $TempDirectory | Remove-Container
    Break
}

If ($InstallWimInfo.InstallationType.Contains('Server') -or $InstallWimInfo.InstallationType.Contains('WindowsPE'))
{
    Write-Warning "Unsupported Image Installation Type: [$($InstallWimInfo.InstallationType)]"
    $TempDirectory | Remove-Container
    Break
}

If ($InstallWimInfo.Build -ge '17134' -and $InstallWimInfo.Build -le '18362')
{
    If ($InstallWimInfo.Build -eq '18362' -and $InstallWimInfo.Language -ne 'en-US' -and $MicrosoftEdge.IsPresent) { $MicrosoftEdge = $false }
    If ($InstallWimInfo.Build -lt '17763' -and $MicrosoftEdge.IsPresent) { $MicrosoftEdge = $false }
    If ($InstallWimInfo.Build -ne '17763' -and $InstallWimInfo.Language -ne 'en-US' -and $Win32Calc.IsPresent) { $Win32Calc = $false }
    If ($InstallWimInfo.Build -gt '17134' -and $InstallWimInfo.Language -ne 'en-US' -and $Dedup.IsPresent) { $Dedup = $false }
    If ($InstallWimInfo.Language -ne 'en-US' -and $DaRT.IsPresent) { $DaRT = $false }
    If ($InstallWimInfo.Name -like "*LTSC*")
    {
        $DynamicParams.Add('LTSC', $true)
        If ($WindowsApps) { Remove-Variable WindowsApps }
        If ($Win32Calc.IsPresent) { $Win32Calc = $false }
    }
    Else
    {
        If ($WindowsStore.IsPresent) { $WindowsStore = $false }
        If ($MicrosoftEdge.IsPresent) { $MicrosoftEdge = $false }
    }
}
Else
{
    Write-Warning "Unsupported Image Build: [$($InstallWimInfo.Build)]"
    $TempDirectory | Remove-Container
    Break
}

Try
{
    Remove-Container -Path "$Env:SystemRoot\Logs\DISM\dism.log"
    Write-Log -Header; Write-Log -Info "Supported Image Build: [$($InstallWimInfo.Build)]"
    Start-Sleep 3; $Timer.Start(); $Error.Clear()
    Write-Log -Info "Mounting $($InstallWimInfo.Name)"
    $MountWindowsImage = @{
        ImagePath        = $InstallWim
        Index            = $ImageIndex
        Path             = $InstallMount
        ScratchDirectory = $ScratchDirectory
        LogPath          = $DISMLog
        ErrorAction      = 'Stop'
    }
    [void](Mount-WindowsImage @MountWindowsImage)
}
Catch
{
    Write-Log -Error ('Failed to Mount {0}' -f $($InstallWimInfo.Name)) -ErrorRecord $Error[0]
    Stop-Optimize; Break
}

Try
{
    If ($BootWim)
    {
        $BootWimInfo = Get-WimFileInfo -WimFile $BootWim -Index 2 -ErrorAction Stop
        $DynamicParams.Add('Boot', $true)
    }
    If (Test-Path -Path (Join-Path -Path $InstallMount -ChildPath 'Windows\System32\Recovery\winre.wim'))
    {
        $WinREPath = Join-Path -Path $InstallMount -ChildPath 'Windows\System32\Recovery\winre.wim'
        Copy-Item -Path $WinREPath -Destination $ImageDirectory -Force
        $RecoveryWim = Get-ChildItem -Path $ImageDirectory -Filter winre.wim | Select-Object -ExpandProperty FullName
        $RecoveryWimInfo = Get-WimFileInfo -WimFile $RecoveryWim -Index 1 -ErrorAction Stop
        $DynamicParams.Add('Recovery', $true)
    }
}
Catch
{
    Write-Warning "Failed to retrieve all image metadata."
    Stop-Optimize; Break
}

If ($DynamicParams['Boot'])
{
    Try
    {
        New-Container -Path $BootMount
        $MountBootImage = @{
            Path             = $BootMount
            ImagePath        = $BootWim
            Index            = 2
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        Write-Log -Info "Mounting $($BootWimInfo.Name)"
        [void](Mount-WindowsImage @MountBootImage)
    }
    Catch
    {
        Write-Log -Error ('Failed to Mount {0}' -f $($BootWimInfo.Name)) -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($DynamicParams['Recovery'])
{
    Try
    {
        New-Container -Path $RecoveryMount
        $MountRecoveryImage = @{
            Path             = $RecoveryMount
            ImagePath        = $RecoveryWim
            Index            = 1
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        Write-Log -Info "Mounting $($RecoveryWimInfo.Name)"
        [void](Mount-WindowsImage @MountRecoveryImage)
    }
    Catch
    {
        Write-Log -Error ('Failed to Mount {0}' -f $($RecoveryWimInfo.Name)) -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ((Repair-WindowsImage -Path $InstallMount -CheckHealth).ImageHealthState -eq 'Healthy')
{
    Write-Log -Info "Pre-Optimization Image Health State: [Healthy]"
    Start-Sleep 3; Clear-Host
}
Else
{
    Write-Log -Error "The image has been flagged for corruption. Further servicing is required before the image can be optimized."
    Stop-Optimize; Break
}

If ($WindowsApps -and (Get-AppxProvisionedPackage -Path $InstallMount).Count -gt 0)
{
    $Host.UI.RawUI.WindowTitle = "Removing Appx Provisioned Packages."
    $RemovedAppxPackages = [System.Collections.ArrayList]@()
    Try
    {
        Switch ($WindowsApps)
        {
            'Select'
            {
                $SelectedAppxPackages = [System.Collections.ArrayList]@()
                Get-AppxProvisionedPackage -Path $InstallMount | ForEach-Object {
                    $AppxPackages = [PSCustomObject]@{
                        DisplayName = $_.DisplayName
                        PackageName = $_.PackageName
                    }
                    [void]$SelectedAppxPackages.Add($AppxPackages)
                }
                $SelectedAppxPackages = $SelectedAppxPackages | Out-GridView -Title "Remove Appx Provisioned Packages." -PassThru
                $PackageName = $SelectedAppxPackages.PackageName
                If ($PackageName)
                {
                    $PackageName | ForEach-Object {
                        Write-Log -Info ('Removing Appx Provisioned Package: {0}' -f $($_.Split('_')[0]))
                        $ParamsAppx = @{
                            Path             = $InstallMount
                            PackageName      = $($_)
                            ScratchDirectory = $ScratchDirectory
                            LogPath          = $DISMLog
                            ErrorAction      = 'Stop'
                        }
                        [void](Remove-AppxProvisionedPackage @ParamsAppx)
                        [void]$RemovedAppxPackages.Add($_.Split('_')[0])
                    }
                    Remove-Variable PackageName
                }; Break
            }
            'All'
            {
                Get-AppxProvisionedPackage -Path $InstallMount | ForEach-Object {
                    Write-Log -Info ('Removing Appx Provisioned Package: {0}' -f $($_.DisplayName))
                    $ParamsAppx = @{
                        Path             = $InstallMount
                        PackageName      = $($_.PackageName)
                        ScratchDirectory = $ScratchDirectory
                        LogPath          = $DISMLog
                        ErrorAction      = 'Stop'
                    }
                    [void](Remove-AppxProvisionedPackage @ParamsAppx)
                    [void]$RemovedAppxPackages.Add($_.DisplayName)
                }; Break
            }
            'Whitelist'
            {
                If (Test-Path -Path $AppxWhitelistPath)
                {
                    [XML]$Whitelist = Get-Content -Path $AppxWhitelistPath
                    Get-AppxProvisionedPackage -Path $InstallMount | ForEach-Object {
                        If ($_.DisplayName -notin $Whitelist.Appx.DisplayName)
                        {
                            Write-Log -Info ('Removing Appx Provisioned Package: {0}' -f $($_.DisplayName))
                            $ParamsAppx = @{
                                Path             = $InstallMount
                                PackageName      = $($_.PackageName)
                                ScratchDirectory = $ScratchDirectory
                                LogPath          = $DISMLog
                                ErrorAction      = 'Stop'
                            }
                            [void](Remove-AppxProvisionedPackage @ParamsAppx)
                            [void]$RemovedAppxPackages.Add($_.DisplayName)
                        }
                    }
                }; Break
            }
        }
    }
    Catch
    {
        Write-Log -Error "Failed to Remove Appx Provisioned Packages." -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
    Finally
    {
        Clear-Host
    }
    If ((Get-AppxProvisionedPackage -Path $InstallMount).Count -eq 0)
    {
        $Host.UI.RawUI.WindowTitle = "Removing Windows App Program Files."
        Write-Log -Info "Removing Windows App Program Files."
        $ACL = Get-Acl -Path "$InstallMount\Program Files\WindowsApps"
        Grant-FolderOwnership -Path "$InstallMount\Program Files\WindowsApps"
        Get-ChildItem -Path "$InstallMount\Program Files\WindowsApps" -Recurse -Force | Remove-Container
        $ACL | Set-Acl -Path "$InstallMount\Program Files\WindowsApps"
    }
}

If (Test-Path -Path $AppAssocPath)
{
    $Host.UI.RawUI.WindowTitle = "Importing Custom App Associations."
    Write-Log -Info "Importing Custom App Associations."
    $RunDism = Start-Executable -Executable "$Env:SystemRoot\System32\DISM.EXE" -Arguments ('/Image:"{0}" /Import-DefaultAppAssociations:"{1}"' -f $InstallMount, $AppAssocPath) -PassThru
    If ($RunDism.ExitCode -ne 0) { Write-Log -Error "Failed to Import Custom App Associations."; Start-Sleep 3 }
}

If ($SystemApps.IsPresent)
{
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "Removing System Applications."
    Write-Warning "Do NOT remove any System Application if you are unsure of its impact on a live installation."
    Start-Sleep 5
    $RemovedSystemApps = [System.Collections.ArrayList]@()
    $InboxAppsKey = "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications"
    Get-OfflineHives -Load
    $InboxAppPackages = Get-ChildItem -Path $InboxAppsKey -Name | Select-Object -Property @{ Label = 'Name'; Expression = { ($_.Split('_')[0]) } }, @{ Label = 'Package'; Expression = { ($_) } } | Out-GridView -Title "Remove System Applications." -PassThru
    $InboxAppsList = $InboxAppPackages.Package
    If ($InboxAppsList)
    {
        Try
        {
            Clear-Host
            $InboxAppsList | ForEach-Object {
                $FullKeyPath = Join-Path -Path $InboxAppsKey -ChildPath $($_)
                $FullKeyPath = $FullKeyPath -replace 'HKLM:', 'HKLM'
                Write-Log -Info "Removing System Application: $($_.Split('_')[0])"
                $RunReg = Start-Executable -Executable "$Env:SystemRoot\System32\REG.EXE" -Arguments ('DELETE "{0}" /F' -f $FullKeyPath) -PassThru
                If ($RunReg.ExitCode -eq 1) { Write-Log -Error "Failed to Remove System Application: $($_.Split('_')[0])"; Break }
                [void]$RemovedSystemApps.Add($_.Split('_')[0])
                Start-Sleep 2
            }
        }
        Catch
        {
            Write-Log -Error "Failed to Remove System Applications." -ErrorRecord $Error[0]
            Stop-Optimize; Break
        }
        Finally
        {
            Get-OfflineHives -Unload; Clear-Host
        }
    }
}

If ($Packages.IsPresent)
{
    Clear-Host
    $CapabilityPackages = [System.Collections.ArrayList]@()
    $Host.UI.RawUI.WindowTitle = "Removing Windows Capability Packages."
    Get-WindowsCapability -Path $InstallMount | Where-Object -Property State -EQ Installed | ForEach-Object {
        $Capabilities = [PSCustomObject]@{
            PackageName  = $_.Name
            PackageState = $_.State
        }
        [void]$CapabilityPackages.Add($Capabilities)
    }
    $CapabilityPackages = $CapabilityPackages | Out-GridView -Title "Remove Windows Capability Packages." -PassThru
    $PackageName = $CapabilityPackages.PackageName
    If ($PackageName)
    {
        Try
        {
            $PackageName | ForEach-Object {
                Write-Log -Info ('Removing Windows Capability Package: {0}' -f $($_.Split('~')[0]))
                $ParamsCapability = @{
                    Path             = $InstallMount
                    Name             = $($_)
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Remove-WindowsCapability @ParamsCapability)
            }
        }
        Catch
        {
            Write-Log -Error "Failed to Remove Windows Capability Packages." -ErrorRecord $Error[0]
            Stop-Optimize; Break
        }
        Finally
        {
            Remove-Variable PackageName; Clear-Host
        }
    }
}

If ($RemovedAppxPackages -or $RemovedSystemApps)
{
    $Visibility = [System.Text.StringBuilder]::New()
    [void]$Visibility.Append('hide:')
}

If ($RemovedSystemApps -contains 'Microsoft.Windows.SecHealthUI')
{
    $Host.UI.RawUI.WindowTitle = "Removing Windows Defender Remnants."
    Write-Log -Info "Disabling Windows Defender Services, Drivers and SmartScreen Integration."
    Get-OfflineHives -Load
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpyNetReporting" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 2 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "DisableBlockAtFirstSeen" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePus" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" -Name "DisableEnhancedNotifications" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIOAVProtection" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" -Name "AllowBehaviorMonitoring" -Value 2 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" -Name "AllowCloudProtection" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" -Name "AllowRealtimeMonitoring" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" -Name "SubmitSamplesConsent" -Value 2 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\UX Configuration" -Name "Notification_Suppress" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MRT" -Name "DontOfferThroughWUAU" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MRT" -Name "DontReportInfectionInformation" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" -Name "HideSystray" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows Security Health\State" -Name "AccountProtection_MicrosoftAccount_Disconnected" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "SmartScreenEnabled" -Value "Off" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name "EnableWebContentEvaluation" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type DWord
    @("SecurityHealthService", "WinDefend", "WdNisSvc", "WdNisDrv", "WdBoot", "WdFilter", "Sense") | ForEach-Object { If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\$($_)") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\$($_)" -Name "Start" -Value 4 -Type DWord } }
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\EPP"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\EPP"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Drive\shellex\ContextMenuHandlers\EPP"
    Remove-Container -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Control\WMI\AutoLogger\DefenderApiLogger"
    Remove-Container -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Control\WMI\AutoLogger\DefenderAuditLogger"
    Remove-ItemProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SecurityHealth" -Force
    If (!$DynamicParams['LTSC']) { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 0 -Type DWord }
    If ($InstallWimInfo.Build -ge '17763')
    {
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControlEnabled" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControl" -Value "Anywhere" -Type String
    }
    Get-OfflineHives -Unload
    If (Get-WindowsOptionalFeature -Path $InstallMount -FeatureName Windows-Defender-Default-Definitions | Where-Object -Property State -EQ Enabled)
    {
        Try
        {
            Write-Log -Info "Disabling Windows Feature: Windows-Defender-Default-Definitions"
            [void](Disable-WindowsOptionalFeature -Path $InstallMount -FeatureName Windows-Defender-Default-Definitions -ScratchDirectory $ScratchDirectory -LogPath $DISMLog -ErrorAction Stop)
        }
        Catch
        {
            Write-Log -Error "Failed to Disable Windows Feature: Windows-Defender-Default-Definitions" -ErrorRecord $Error[0]
            Stop-Optimize; Break
        }
    }
}

If ($RemovedAppxPackages -like "*Xbox*" -or $RemovedSystemApps -contains 'Microsoft.XboxGameCallableUI')
{
    $Host.UI.RawUI.WindowTitle = "Removing Xbox Remnants."
    Write-Log -Info "Disabling Xbox Services and Drivers."
    Get-OfflineHives -Load
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AudioCaptureEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "CursorCaptureEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
    @("xbgm", "XblAuthManager", "XblGameSave", "xboxgip", "XboxGipSvc", "XboxNetApiSvc") | ForEach-Object { If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\$($_)") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\$($_)" -Name "Start" -Value 4 -Type DWord } }
    Get-OfflineHives -Unload
}

If (Get-WindowsOptionalFeature -Path $InstallMount -FeatureName *SMB1* | Where-Object -Property State -EQ Enabled)
{
    Try
    {
        $Host.UI.RawUI.WindowTitle = "Disabling the SMBv1 Protocol Windows Features."
        Write-Log -Info "Disabling the SMBv1 Protocol Windows Features."
        [void](Get-WindowsOptionalFeature -Path $InstallMount | Where-Object FeatureName -Like *SMB1* | Disable-WindowsOptionalFeature -Path $InstallMount -ScratchDirectory $ScratchDirectory -LogPath $DISMLog -ErrorAction Stop)
    }
    Catch
    {
        Write-Log -Error "Failed to Disable the SMBv1 Protocol Windows Features." -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($Features.IsPresent)
{
    Clear-Host
    $OptionalFeatures = [System.Collections.ArrayList]@()
    $Host.UI.RawUI.WindowTitle = "Disabling Windows Features."
    Get-WindowsOptionalFeature -Path $InstallMount | Where-Object State -EQ Enabled | ForEach-Object {
        $EnabledFeatures = [PSCustomObject]@{
            FeatureName = $_.FeatureName
            State       = $_.State
        }
        [void]$OptionalFeatures.Add($EnabledFeatures)
    }
    $OptionalFeatures = $OptionalFeatures | Out-GridView -Title "Disable Windows Features." -PassThru
    $FeatureName = $OptionalFeatures.FeatureName
    If ($FeatureName)
    {
        Try
        {
            $FeatureName | ForEach-Object {
                Write-Log -Info "Disabling Windows Feature: $($_)"
                $ParamsFeature = @{
                    Path             = $InstallMount
                    FeatureName      = $($_)
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Disable-WindowsOptionalFeature @ParamsFeature)
            }
        }
        Catch
        {
            Write-Log -Error "Failed to Disable Windows Features." -ErrorRecord $Error[0]
            Stop-Optimize; Break
        }
        Finally
        {
            Remove-Variable FeatureName; Clear-Host
        }
        $OptionalFeatures = [System.Collections.ArrayList]@()
        $Host.UI.RawUI.WindowTitle = "Enabling Windows Features."
        Get-WindowsOptionalFeature -Path $InstallMount | Where-Object { $_.FeatureName -notlike "*SMB1*" -and $_.FeatureName -ne "Windows-Defender-Default-Definitions" -and $_.State -eq "Disabled" } | ForEach-Object {
            $DisabledFeatures = [PSCustomObject]@{
                FeatureName = $_.FeatureName
                State       = $_.State
            }
            [void]$OptionalFeatures.Add($DisabledFeatures)
        }
        $OptionalFeatures = $OptionalFeatures | Out-GridView -Title "Enable Windows Features." -PassThru
        $FeatureName = $OptionalFeatures.FeatureName
        If ($FeatureName)
        {
            Try
            {
                $FeatureName | ForEach-Object {
                    Write-Log -Info "Enabling Windows Feature: $($_)"
                    $EnableFeature = @{
                        Path             = $InstallMount
                        FeatureName      = $($_)
                        All              = $true
                        LimitAccess      = $true
                        NoRestart        = $true
                        ScratchDirectory = $ScratchDirectory
                        LogPath          = $DISMLog
                        ErrorAction      = 'Stop'
                    }
                    [void](Enable-WindowsOptionalFeature @EnableFeature)
                }
            }
            Catch
            {
                Write-Log -Error "Failed to Enable Windows Features." -ErrorRecord $Error[0]
                Stop-Optimize; Break
            }
            Finally
            {
                Clear-Host
            }
        }
    }
}

If ($WindowsStore.IsPresent -and (Test-Path -Path $StoreAppPath -Filter Microsoft.WindowsStore*.appxbundle))
{
    $Host.UI.RawUI.WindowTitle = "Integrating the Microsoft Store Application Packages."
    Write-Log -Info "Integrating the Microsoft Store Application Packages."
    Try
    {
        $StoreBundle = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.WindowsStore*.appxbundle -File | Select-Object -ExpandProperty FullName
        $PurchaseBundle = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.StorePurchaseApp*.appxbundle -File | Select-Object -ExpandProperty FullName
        $XboxBundle = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.XboxIdentityProvider*.appxbundle -File | Select-Object -ExpandProperty FullName
        $InstallerBundle = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.DesktopAppInstaller*.appxbundle -File | Select-Object -ExpandProperty FullName
        $StoreLicense = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.WindowsStore*.xml -File | Select-Object -ExpandProperty FullName
        $PurchaseLicense = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.StorePurchaseApp*.xml -File | Select-Object -ExpandProperty FullName
        $IdentityLicense = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.XboxIdentityProvider*.xml -File | Select-Object -ExpandProperty FullName
        $InstallerLicense = Get-ChildItem -Path $StoreAppPath -Filter Microsoft.DesktopAppInstaller*.xml -File | Select-Object -ExpandProperty FullName
        $DepAppx = @()
        $DepAppx += Get-ChildItem -Path $StoreAppPath -Filter Microsoft.VCLibs*.appx -File | Select-Object -ExpandProperty FullName
        $DepAppx += Get-ChildItem -Path $StoreAppPath -Filter *Native.Framework*.appx -File | Select-Object -ExpandProperty FullName
        $DepAppx += Get-ChildItem -Path $StoreAppPath -Filter *Native.Runtime*.appx -File | Select-Object -ExpandProperty FullName
        Get-OfflineHives -Load
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowAllTrustedApps" -Value 1 -Type DWord
        Get-OfflineHives -Unload
        $StorePackage = @{
            Path                  = $InstallMount
            PackagePath           = $StoreBundle
            DependencyPackagePath = $DepAppx
            LicensePath           = $StoreLicense
            ScratchDirectory      = $ScratchDirectory
            LogPath               = $DISMLog
            ErrorAction           = 'Stop'
        }
        [void](Add-AppxProvisionedPackage @StorePackage)
        $PurchasePackage = @{
            Path                  = $InstallMount
            PackagePath           = $PurchaseBundle
            DependencyPackagePath = $DepAppx
            LicensePath           = $PurchaseLicense
            ScratchDirectory      = $ScratchDirectory
            LogPath               = $DISMLog
            ErrorAction           = 'Stop'
        }
        [void](Add-AppxProvisionedPackage @PurchasePackage)
        $IdentityPackage = @{
            Path                  = $InstallMount
            PackagePath           = $XboxBundle
            DependencyPackagePath = $DepAppx
            LicensePath           = $IdentityLicense
            ScratchDirectory      = $ScratchDirectory
            LogPath               = $DISMLog
            ErrorAction           = 'Stop'
        }
        [void](Add-AppxProvisionedPackage @IdentityPackage)
        $DepAppx = @()
        $DepAppx += Get-ChildItem -Path $StoreAppPath -Filter *Native.Runtime*.appx -File | Select-Object -ExpandProperty FullName
        $InstallerPackage = @{
            Path                  = $InstallMount
            PackagePath           = $InstallerBundle
            DependencyPackagePath = $DepAppx
            LicensePath           = $InstallerLicense
            ScratchDirectory      = $ScratchDirectory
            LogPath               = $DISMLog
            ErrorAction           = 'Stop'
        }
        [void](Add-AppxProvisionedPackage @InstallerPackage)
    }
    Catch
    {
        Write-Log -Error "Failed to Integrate the Microsoft Store Application Packages." -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($MicrosoftEdge.IsPresent -and (Test-Path -Path $EdgeAppPath -Filter Microsoft-Windows-Internet-Browser-Package*.cab) -and $null -eq (Get-WindowsPackage -Path $InstallMount | Where-Object PackageName -Like *Internet-Browser*))
{
    Try
    {
        $Host.UI.RawUI.WindowTitle = "Integrating the Microsoft Edge Browser Application Packages."
        Write-Log -Info "Integrating the Microsoft Edge Browser Application Packages."
        $EdgeBasePackage = @{
            Path             = $InstallMount
            PackagePath      = "$($EdgeAppPath)\Microsoft-Windows-Internet-Browser-Package~$($InstallWimInfo.Architecture)~~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @EdgeBasePackage)
        $EdgeLanguagePackage = @{
            Path             = $InstallMount
            PackagePath      = "$($EdgeAppPath)\Microsoft-Windows-Internet-Browser-Package~$($InstallWimInfo.Architecture)~$($InstallWimInfo.Language)~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @EdgeLanguagePackage)
        Get-OfflineHives -Load
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "DisableEdgeDesktopShortcutCreation" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "AllowPrelaunch" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "AllowPrelaunch" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" -Name "PreventTabPreloading" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" -Name "PreventTabPreloading" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "DoNotTrack" -Value 1 -Type DWord
        If ($RemovedSystemApps -contains 'Microsoft.Windows.SecHealthUI') { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 0 -Type DWord }
        Get-OfflineHives -Unload; $DynamicParams.Add('Edge', $true)
    }
    Catch
    {
        Write-Log -Error "Failed to Integrate the Microsoft Edge Browser Application Packages." -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($Win32Calc.IsPresent -and $null -eq (Get-WindowsPackage -Path $InstallMount | Where-Object PackageName -Like *win32calc*))
{
    $Host.UI.RawUI.WindowTitle = "Integrating the Win32 Calculator Packages."
    Write-Log -Info "Integrating the Win32 Calculator Packages."
    If ($InstallWimInfo.Build -eq '17763' -and (Test-Path -Path $Win32CalcPath -Filter Microsoft-Windows-win32calc-Package*.cab))
    {
        Try
        {
            $CalcBasePackage = @{
                Path             = $InstallMount
                PackagePath      = "$($Win32CalcPath)\Microsoft-Windows-win32calc-Package~$($InstallWimInfo.Architecture)~~10.0.$($InstallWimInfo.Build).1.cab"
                IgnoreCheck      = $true
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Add-WindowsPackage @CalcBasePackage)
            $CalcLanguagePackage = @{
                Path             = $InstallMount
                PackagePath      = "$($Win32CalcPath)\Microsoft-Windows-win32calc-Package~$($InstallWimInfo.Architecture)~$($InstallWimInfo.Language)~10.0.$($InstallWimInfo.Build).1.cab"
                IgnoreCheck      = $true
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Add-WindowsPackage @CalcLanguagePackage)
            Get-OfflineHives -Load
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\RegisteredApplications" -Name "Windows Calculator" -Value "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Applets\\Calculator\\Capabilities" -Type String
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationName" -Value "@%SystemRoot%\System32\win32calc.exe" -Type ExpandString
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationDescription" -Value "@%SystemRoot%\System32\win32calc.exe,-217" -Type ExpandString
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities\URLAssociations" -Name "calculator" -Value "calculator" -Type String
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationName" -Value "@%SystemRoot%\System32\win32calc.exe" -Type ExpandString
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationDescription" -Value "@%SystemRoot%\System32\win32calc.exe,-217" -Type ExpandString
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities\URLAssociations" -Name "calculator" -Value "calculator" -Type String
            Get-OfflineHives -Unload; $DynamicParams.Add('Win32Calc', $true)
        }
        Catch
        {
            Write-Log -Error "Failed to Integrate the Win32 Calculator Packages." -ErrorRecord $Error[0]
            Stop-Optimize; Break
        }
    }
    Else
    {
        If (Test-Path -Path $Win32CalcPath -Filter Win32Calc.wim)
        {
            Try
            {
                $CalcPackage = @{
                    ImagePath        = "$($Win32CalcPath)\Win32Calc.wim"
                    Index            = 1
                    ApplyPath        = $InstallMount
                    CheckIntegrity   = $true
                    Verify           = $true
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Expand-WindowsImage @CalcPackage)
                $IniFile = "$InstallMount\ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories\desktop.ini"
                $CalcString = "Calculator.lnk=@%SystemRoot%\System32\shell32.dll,-22019"
                Add-Content -Path $IniFile -Value $CalcString -Encoding Unicode -Force
                Get-OfflineHives -Load
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\RegisteredApplications" -Name "Windows Calculator" -Value "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Applets\\Calculator\\Capabilities" -Type String
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\calculator" -Name "(default)" -Value "URL:calculator" -Type String
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\calculator" -Name "URL Protocol" -Value "" -Type String
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\calculator\DefaultIcon" -Name "(default)" -Value "@%SystemRoot%\System32\win32calc.exe,0" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\calculator\shell\open\command" -Name "(default)" -Value "@%SystemRoot%\System32\win32calc.exe" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationName" -Value "@%SystemRoot%\System32\win32calc.exe" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationDescription" -Value "@%SystemRoot%\System32\win32calc.exe,-217" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities\URLAssociations" -Name "calculator" -Value "calculator" -Type String
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationName" -Value "@%SystemRoot%\System32\win32calc.exe" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities" -Name "ApplicationDescription" -Value "@%SystemRoot%\System32\win32calc.exe,-217" -Type ExpandString
                Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Applets\Calculator\Capabilities\URLAssociations" -Name "calculator" -Value "calculator" -Type String
                Get-OfflineHives -Unload
            }
            Catch
            {
                Write-Log -Error "Failed to Integrate the Win32 Calculator Packages." -ErrorRecord $Error[0]
                Stop-Optimize; Break
            }
        }
    }
}

If ($Dedup.IsPresent -and (Test-Path -Path $DedupPath -Filter Microsoft-Windows-FileServer-ServerCore-Package*.cab) -and (Test-Path -Path $DedupPath -Filter Microsoft-Windows-Dedup-Package*.cab) -and $null -eq (Get-WindowsPackage -Path $InstallMount | Where-Object PackageName -Like *Windows-Dedup*) -and $null -eq (Get-WindowsPackage -Path $InstallMount | Where-Object PackageName -Like *Windows-FileServer-ServerCore*))
{
    $Host.UI.RawUI.WindowTitle = "Integrating the Data Deduplication Packages."
    Write-Log -Info "Integrating the Data Deduplication Packages."
    Try
    {
        $FileServerCore = @{
            Path             = $InstallMount
            PackagePath      = "$($DedupPath)\Microsoft-Windows-FileServer-ServerCore-Package~31bf3856ad364e35~$($InstallWimInfo.Architecture)~~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @FileServerCore)
        $FileServerLang = @{
            Path             = $InstallMount
            PackagePath      = "$($DedupPath)\Microsoft-Windows-FileServer-ServerCore-Package~31bf3856ad364e35~$($InstallWimInfo.Architecture)~$($InstallWimInfo.Language)~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @FileServerLang)
        $DedupCore = @{
            Path             = $InstallMount
            PackagePath      = "$($DedupPath)\Microsoft-Windows-Dedup-Package~31bf3856ad364e35~$($InstallWimInfo.Architecture)~~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @DedupCore)
        $DedupLang = @{
            Path             = $InstallMount
            PackagePath      = "$($DedupPath)\Microsoft-Windows-Dedup-Package~31bf3856ad364e35~$($InstallWimInfo.Architecture)~$($InstallWimInfo.Language)~10.0.$($InstallWimInfo.Build).1.cab"
            IgnoreCheck      = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Add-WindowsPackage @DedupLang)
        $EnableDedup = @{
            Path             = $InstallMount
            FeatureName      = "Dedup-Core"
            All              = $true
            LimitAccess      = $true
            NoRestart        = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Enable-WindowsOptionalFeature @EnableDedup)
        Get-OfflineHives -Load
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Defaults\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-DCOM-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=135|App=%SystemRoot%\\System32\\svchost.exe|Svc=RPCSS|Name=File Server Remote Management (DCOM-In)|Desc=Inbound rule to allow DCOM traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Defaults\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-SMB-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=445|App=System|Name=File Server Remote Management (SMB-In)|Desc=Inbound rule to allow SMB traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Defaults\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-Winmgmt-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=RPC|App=%SystemRoot%\\System32\\svchost.exe|Svc=Winmgmt|Name=File Server Remote Management (WMI-In)|Desc=Inbound rule to allow WMI traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-DCOM-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=135|App=%SystemRoot%\\System32\\svchost.exe|Svc=RPCSS|Name=File Server Remote Management (DCOM-In)|Desc=Inbound rule to allow DCOM traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-SMB-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=445|App=System|Name=File Server Remote Management (SMB-In)|Desc=Inbound rule to allow SMB traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        $FirewallRule = @{
            Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
            Name  = "FileServer-ServerManager-Winmgmt-TCP-In"
            Value = "v2.22|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=RPC|App=%SystemRoot%\\System32\\svchost.exe|Svc=Winmgmt|Name=File Server Remote Management (WMI-In)|Desc=Inbound rule to allow WMI traffic to manage the File Services role.|EmbedCtxt=File Server Remote Management|"
            Type  = 'String'
        }
        Set-KeyProperty @FirewallRule
        Get-OfflineHives -Unload
    }
    Catch
    {
        Write-Log -Error "Failed to Integrate the Data Deduplication Packages." -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($DaRT.IsPresent -and (Test-Path -Path $DaRTPath -Filter MSDaRT10_*.wim))
{
    $Host.UI.RawUI.WindowTitle = "Integrating Microsoft DaRT 10."
    If ($InstallWimInfo.Build -eq '17134') { $CodeName = 'RS4' }
    ElseIf ($InstallWimInfo.Build -eq '17763') { $CodeName = 'RS5' }
    ElseIf ($InstallWimInfo.Build -eq '18362') { $CodeName = 'RS6' }
    If ($DynamicParams['Boot'])
    {
        Try
        {
            Write-Log -Info "Integrating Microsoft DaRT 10 and Windows $($CodeName) Debugging Tools into $($BootWimInfo.Name)"
            $MSDaRT10Boot = @{
                ImagePath        = "$($DaRTPath)\MSDaRT10_$($CodeName).wim"
                Index            = 1
                ApplyPath        = $BootMount
                CheckIntegrity   = $true
                Verify           = $true
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Expand-WindowsImage @MSDaRT10Boot)
            If (!(Test-Path -Path "$BootMount\Windows\System32\fmapi.dll")) { Copy-Item -Path "$InstallMount\Windows\System32\fmapi.dll" -Destination "$BootMount\Windows\System32" -Force }
            @'
[LaunchApps]
%WINDIR%\System32\wpeinit.exe
%WINDIR%\System32\netstart.exe
%SYSTEMDRIVE%\setup.exe
'@ | Out-File -FilePath "$BootMount\Windows\System32\winpeshl.ini" -Force
        }
        Catch
        {
            Write-Log -Error "Failed to integrate Microsoft DaRT 10 into $($BootWimInfo.Name)" -ErrorRecord $Error[0]
        }
        Finally
        {
            Start-Sleep 3
        }
    }
    If ($DynamicParams['Recovery'])
    {
        Try
        {
            Write-Log -Info "Integrating Microsoft DaRT 10 and Windows $($CodeName) Debugging Tools into $($RecoveryWimInfo.Name)"
            $MSDaRT10Recovery = @{
                ImagePath        = "$($DaRTPath)\MSDaRT10_$($CodeName).wim"
                Index            = 1
                ApplyPath        = $RecoveryMount
                CheckIntegrity   = $true
                Verify           = $true
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Expand-WindowsImage @MSDaRT10Recovery)
            If (!(Test-Path -Path "$RecoveryMount\Windows\System32\fmapi.dll")) { Copy-Item -Path "$InstallMount\Windows\System32\fmapi.dll" -Destination "$RecoveryMount\Windows\System32" -Force }
            @'
[LaunchApps]
%WINDIR%\System32\wpeinit.exe
%WINDIR%\System32\netstart.exe
%SYSTEMDRIVE%\sources\recovery\recenv.exe
'@ | Out-File -FilePath "$RecoveryMount\Windows\System32\winpeshl.ini" -Force
        }
        Catch
        {
            Write-Log -Error "Failed to integrate Microsoft DaRT 10 into $($RecoveryWimInfo.Name)" -ErrorRecord $Error[0]
        }
        Finally
        {
            Start-Sleep 3
        }
    }
    Clear-Host
}

#region Registry Optimizations.
If ($Registry.IsPresent)
{
    $Host.UI.RawUI.WindowTitle = "Applying Optimizations to the Offline Registry Hives."
    Write-Log -Info "Applying Optimizations to the Offline Registry Hives."
    $RegLog = Join-Path -Path $LogDirectory -ChildPath Registry-Optimizations.log
    Get-OfflineHives -Load
    #****************************************************************#
    Write-Output "Disabling Cortana and Search Bar Web Connectivity." >> $RegLog
    #****************************************************************#
    If ($InstallWimInfo.Build -ge '18362') { Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Value 0 -Type DWord }
    ElseIf ($InstallWimInfo.Build -le '17763') { Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord }
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaInAmbientMode" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "HistoryViewEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "HasAboveLockTips" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "AllowSearchToUseLocation" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Speech_OneCore\Preferences" -Name "VoiceActivationEnableAboveLockscreen" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "DisableVoice" -Value 1 -Type DWord
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana ActionUriServer.exe"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=C:\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy\ActionUriServer.exe|Name=Block Cortana ActionUriServer.exe|Desc=Block Cortana Outbound UDP/TCP Traffic|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana PlacesServer.exe"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=C:\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy\PlacesServer.exe|Name=Block Cortana PlacesServer.exe|Desc=Block Cortana Outbound UDP/TCP Traffic|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana RemindersServer.exe"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=C:\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy\RemindersServer.exe|Name=Block Cortana RemindersServer.exe|Desc=Block Cortana Outbound UDP/TCP Traffic|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana RemindersShareTargetApp.exe"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=C:\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy\RemindersShareTargetApp.exe|Name=Block Cortana RemindersShareTargetApp.exe|Desc=Block Cortana Outbound UDP/TCP Traffic|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana SearchUI.exe"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|App=C:\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy\SearchUI.exe|Name=Block Cortana SearchUI.exe|Desc=Block Cortana Outbound UDP/TCP Traffic|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    $FirewallParams = @{
        Path  = "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules"
        Name  = "Block Cortana Package"
        Value = "v2.26|Action=Block|Active=TRUE|Dir=Out|RA42=IntErnet|RA62=IntErnet|Name=Block Cortana Package|Desc=Block Cortana Outbound UDP/TCP Traffic|AppPkgId=S-1-15-2-1861897761-1695161497-2927542615-642690995-327840285-2659745135-2630312742|Platform=2:6:2|Platform2=GTEQ|"
        Type  = 'String'
    }
    Set-KeyProperty @FirewallParams
    #****************************************************************#
    Write-Output "Disabling System Telemetry, Data Collecting and Advertisements." >> $RegLog
    #****************************************************************#
    If ($DynamicParams['LTSC'] -or $InstallWimInfo.Name -like "*Enterprise*" -or $InstallWimInfo.Name -like "*Education*") { $TelemetryLevel = 0 } Else { $TelemetryLevel = 1 }
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value $TelemetryLevel -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value $TelemetryLevel -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value $TelemetryLevel -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisablePCA" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableUAR" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\AppV\CEIP" -Name "CEIPEnable" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform" -Name "NoGenTicket" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput" -Name "AllowLinguisticDataCollection" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation" -Name "value" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\International\User Profile" -Name "HttpAcceptLanguageOptOut" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 100 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowWindowsInkWorkspace" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Input\TIPC" -Name "Enabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "EnableFeaturedSoftware" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Disabling Windows Tracking." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DontUsePowerShellOnWinX" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord
    If (!$DynamicParams['LTSC'] -and !$DynamicParams['Edge']) { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "DoNotTrack" -Value 1 -Type DWord }
    #****************************************************************#
    Write-Output "Disabling System Location Sensors." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type String
    If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\lfsvc") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\lfsvc" -Name "Start" -Value 4 -Type DWord }
    If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\lfsvc\Service\Configuration") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\lfsvc\Service\Configuration" -Name "Status" -Value 0 -Type DWord }
    #****************************************************************#
    Write-Output "Disabling Cross-Device Sharing and Shared Experiences." >>  $RegLog
    #***************************************************************
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" -Name "CdpSessionUserAuthzPolicy" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" -Name "RomeSdkChannelUserAuthzPolicy" -Value 0 -Type DWord
    #****************************************************************#
    If ($InstallWimInfo.Build -ge '17763')
    {
        #****************************************************************#
        Write-Output "Disabling Clipboard History and Service." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowClipboardHistory" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowCrossDeviceClipboard" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 0 -Type DWord
        If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\cbdhsvc") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\cbdhsvc" -Name "Start" -Value 4 -Type DWord }
        [void]$Visibility.Append('clipboard;')
    }
    #****************************************************************#
    Write-Output "Disabling WiFi Sense." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "value" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "value" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "AutoConnectAllowedOEM" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name "WiFISenseAllowed" -Value 0 -Type DWord
    #****************************************************************#
    If ($RemovedAppxPackages -contains 'Microsoft.WindowsMaps')
    {
        If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\MapsBroker")
        {
            #****************************************************************#
            Write-Output "Disabling the Windows Maps App Service." >> $RegLog
            #****************************************************************#
            Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\MapsBroker" -Name "Start" -Value 4 -Type DWord
        }
        #****************************************************************#
        Write-Output "Disabling Windows Maps Auto Update." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\Maps" -Name "AutoUpdateEnabled" -Value 0 -Type DWord
    }
    If ($RemovedAppxPackages -contains 'Microsoft.Wallet' -and (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\WalletService"))
    {
        #****************************************************************#
        Write-Output "Disabling the Microsoft Wallet App Service." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\WalletService" -Name "Start" -Value 4 -Type DWord
    }
    If ($RemovedSystemApps -contains 'Microsoft.BioEnrollment')
    {
        #****************************************************************#
        Write-Output "Disabling Biometric and Microsoft Hello Services." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Biometrics" -Name "Enabled" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\Credential Provider" -Name "Domain Accounts" -Value 0 -Type DWord
        If (Test-Path -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\WbioSrvc") { Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Services\WbioSrvc" -Name "Start" -Value 4 -Type DWord }
    }
    If ($RemovedSystemApps -contains 'Microsoft.Windows.SecureAssessmentBrowser')
    {
        #****************************************************************#
        Write-Output "Disabling Text Suggestions and Screen Monitoring." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\SecureAssessment" -Name "AllowScreenMonitoring" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\SecureAssessment" -Name "AllowTextSuggestions" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\SecureAssessment" -Name "RequirePrinting" -Value 0 -Type DWord
    }
    If ($RemovedSystemApps -contains 'Microsoft.Windows.ContentDeliveryManager')
    {
        #****************************************************************#
        Write-Output "Disabling Subscribed Content Delivery and Live Tiles." >> $RegLog
        #****************************************************************#
        @("SubscribedContent-202914Enabled", "SubscribedContent-280810Enabled", "SubscribedContent-280811Enabled", "SubscribedContent-280813Enabled", "SubscribedContent-280815Enabled", "SubscribedContent-310091Enabled",
            "SubscribedContent-310092Enabled", "SubscribedContent-310093Enabled", "SubscribedContent-314381Enabled", "SubscribedContent-314559Enabled", "SubscribedContent-314563Enabled", "SubscribedContent-338380Enabled",
            "SubscribedContent-338387Enabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-338393Enabled", "SubscribedContent-353698Enabled", "ContentDeliveryAllowed",
            "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled", "PreInstalledAppsEverEnabled", "RemediationRequired", "RotatingLockScreenEnabled", "RotatingLockScreenOverlayEnabled",
            "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SystemPaneSuggestionsEnabled", "SubscribedContentEnabled") | ForEach-Object { Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name $($_) -Value 0 -Type DWord }
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "NoCloudApplicationNotification" -Value 1 -Type DWord
    }
    #****************************************************************#
    Write-Output "Disabling Microsoft Toast and Lockscreen Notifications." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "NoToastApplicationNotification" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "NoToastApplicationNotificationOnLockScreen" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Disabling Connected Drive Autoplay and Autorun." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255 -Type DWord
    #****************************************************************#
    Write-Output "Disabling Automatic Download File Blocking." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name "SaveZoneInformation" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Disabling the Modern UI Swap File." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Control\Session Manager\Memory Management" -Name "SwapfileControl" -Value 0 -Type DWord
    #****************************************************************#
    If ($InstallWimInfo.Build -ge '18362')
    {
        #****************************************************************#
        Write-Output "Disabling Reserved Storage." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "BaseHardReserveSize" -Value 0 -Type QWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "BaseSoftReserveSize" -Value 0 -Type QWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "HardReserveAdjustment" -Value 0 -Type QWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "MinDiskSize" -Value 0 -Type QWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name "ShippedWithReserves" -Value 0 -Type DWord
    }
    #****************************************************************#
    Write-Output "Disabling the First Log-on Animation." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Disabling the Windows Start-up Sound." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" -Name "DisableStartupSound" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Optimizing Taskbar Icons and Transparency." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowDriveLettersFirst" -Value 4 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "UseOLEDTaskbarTransparency" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Setting File Explorer to Open to This PC and Disabling Recently and Frequently Used Folders." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Disabling Wallpaper .JPEG Quality Reduction." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Desktop" -Name "JPEGImportQuality" -Value 100 -Type DWord
    #****************************************************************#
    If ($InstallWimInfo.Build -ge '18362')
    {
        #****************************************************************#
        Write-Output "Disabling the Sign-in Screen Acrylic Blur." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableAcrylicBackgroundOnLogon" -Value 1 -Type DWord
    }
    #****************************************************************#
    Write-Output "Removing the '-Shortcut' Trailing Text for Shortcuts." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -Value (0, 0, 0, 0) -Type Binary
    #****************************************************************#
    If (!$DynamicParams['LTSC'] -and !$DynamicParams['Edge'])
    {
        #****************************************************************#
        Write-Output "Disabling the Microsoft Edge Desktop Shortcut Creation." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "DisableEdgeDesktopShortcutCreation" -Value 1 -Type DWord
        #****************************************************************#
        Write-Output "Disabling the Microsoft Edge Start-up Pre-Launch." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "AllowPrelaunch" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" -Name "AllowPrelaunch" -Value 0 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" -Name "PreventTabPreloading" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" -Name "PreventTabPreloading" -Value 1 -Type DWord
    }
    #****************************************************************#
    Write-Output "Disabling the Windows Store and Windows Mail Icons from Taskbar." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoPinningStoreToTaskbar" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband\AuxilliaryPins" -Name "MailPin" -Value 2 -Type DWord
    #****************************************************************#
    Write-Output "Disabling the People Icon from Taskbar." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Reducing Start Menu Delay." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Desktop" -Name "MenuShowDelay" -Value 50 -Type String
    #****************************************************************#
    Write-Output "Enabling TaskBar Icon Combining." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarGlomLevel" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Enabling Small TaskBar Icons." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarSmallIcons" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Disabling the 'How do you want to open this file?' Prompt." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoNewAppAlert" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Adding the Classic Personalization Panel and Classic Control Panel Icons." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "(default)" -Value "Personalization (Classic)" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "InfoTip" -Value "@%SystemRoot%\\System32\\themecpl.dll,-2#immutable1" -Type ExpandString
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "System.ApplicationName" -Value "Microsoft.Personalization" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "System.ControlPanel.Category" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "System.Software.TasksFileUrl" -Value "Internal" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}\DefaultIcon" -Name "(default)" -Value "%SystemRoot%\\System32\\themecpl.dll,-1" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}\shell\Open\Command" -Name "(default)" -Value "explorer.exe shell:::{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{580722FF-16A7-44C1-BF74-7E1ACD00F4F9}" -Name "(default)" -Value "Personalization" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Value 1 -Type DWord
    #****************************************************************#
    If ($InstallWimInfo.Build -ge '17763')
    {
        #****************************************************************#
        Write-Output "Enabling the Floating Immersive Control Panel." >> $RegLog
        #****************************************************************#
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "ImmersiveSearch" -Value 1 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search\Flighting\Override" -Name "CenterScreenRoundedCornerRadius" -Value 9 -Type DWord
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search\Flighting\Override" -Name "ImmersiveSearchFull" -Value 1 -Type DWord
    }
    #****************************************************************#
    Write-Output "Adding 'This PC' Icon to Desktop." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Type DWord
    #****************************************************************#
    Write-Output "Removing 'Edit with Paint 3D and 3D Print' from the Context Menu." >> $RegLog
    #****************************************************************#
    @('.3mf', '.bmp', '.fbx', '.gif', '.jfif', '.jpe', '.jpeg', '.jpg', '.png', '.tif', '.tiff') | ForEach-Object { Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\SystemFileAssociations\$($_)\shell\3D Edit" }
    @('.3ds', '.3mf', '.dae', '.dxf', '.obj', '.ply', '.stl', '.wrl') | ForEach-Object { Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\SystemFileAssociations\$($_)\shell\3D Print" }
    #****************************************************************#
    Write-Output "Restoring Windows Photo Viewer." >> $RegLog
    #****************************************************************#
    @(".bmp", ".cr2", ".dib", ".gif", ".ico", ".jfif", ".jpe", ".jpeg", ".jpg", ".jxr", ".png", ".tif", ".tiff", ".wdp") | ForEach-Object {
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Classes\$($_)" -Name "(default)" -Value "PhotoViewer.FileAssoc.Tiff" -Type String
        Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$($_)\OpenWithProgids" -Name "PhotoViewer.FileAssoc.Tiff" -Value 0 -Type Binary
    }
    @("Paint.Picture", "giffile", "jpegfile", "pngfile") | ForEach-Object {
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\$($_)\shell\open" -Name "MuiVerb" -Value "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043" -Type ExpandString
        Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\$($_)\shell\open\command" -Name "(Default)" -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -Type ExpandString
    }
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Applications\photoviewer.dll\shell\open" -Name "MuiVerb" -Value "@photoviewer.dll,-3043" -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Applications\photoviewer.dll\shell\open\command" -Name "(Default)" -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -Type ExpandString
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Applications\photoviewer.dll\shell\open\DropTarget" -Name "Clsid" -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}" -Type String
    #****************************************************************#
    Write-Output "Removing User Folders from This PC and Explorer." >> $RegLog
    #****************************************************************#
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}"
    #****************************************************************#
    Write-Output "Increasing the Icon Cache Size." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "Max Cached Icons" -Value 8192 -Type String
    #****************************************************************#
    Write-Output "Disabling the Sticky Keys Prompt." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value 506 -Type String
    #****************************************************************#
    Write-Output "Disabling Enhanced Pointer Precision." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Mouse" -Name "MouseSpeed" -Value 0 -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Mouse" -Name "MouseThreshold1" -Value 0 -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\Control Panel\Mouse" -Name "MouseThreshold2" -Value 0 -Type String
    #****************************************************************#
    Write-Output "Removing 'Give Access To' from the Context Menu." >> $RegLog
    #****************************************************************#
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\Background\shellex\ContextMenuHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\shellex\CopyHookHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\shellex\PropertySheetHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Drive\shellex\ContextMenuHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Drive\shellex\PropertySheetHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing"
    #****************************************************************#
    Write-Output "Removing 'Share' from the Context Menu." >> $RegLog
    #****************************************************************#
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\*\shellex\ContextMenuHandlers\ModernSharing"
    #****************************************************************#
    Write-Output "Removing 'Cast To Device' from the Context Menu." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{7AD84985-87B4-4a16-BE58-8B72A5B390F7}" -Value "Play to Menu" -Type String
    #****************************************************************#
    Write-Output "Removing 'Restore Previous Versions' from the Context Menu." >> $RegLog
    #****************************************************************#
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\AllFilesystemObjects\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"
    Remove-Container -Path "HKLM:\WIM_HKLM_SOFTWARE\Classes\Drive\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}"
    #****************************************************************#
    Write-Output "Enabling Long File Paths." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SYSTEM\ControlSet001\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord
    #****************************************************************#
    Write-Output "Enabling Strong Cryptography for .NET Applications." >> $RegLog
    #****************************************************************#
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 -Type DWord
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" -Name "SchUseStrongCrypto" -Value 1 -Type DWord
    #****************************************************************#
    Get-OfflineHives -Unload
}
#endregion Registry Optimizations

If ($Visibility)
{
    If ($RemovedSystemApps -contains 'Microsoft.Windows.SecHealthUI') { [void]$Visibility.Append('windowsdefender;') }
    If ($RemovedAppxPackages -like "*Xbox*" -or $RemovedSystemApps -contains 'Microsoft.XboxGameCallableUI')
    {
        [void]$Visibility.Append('gaming-gamebar;gaming-gamedvr;gaming-broadcasting;gaming-gamemode;gaming-xboxnetworking;quietmomentsgame;')
        If ($InstallWimInfo.Build -lt '17763') { [void]$Visibility.Append('gaming-trueplay;') }
    }
    If ($RemovedAppxPackages -contains 'Microsoft.WindowsMaps') { [void]$Visibility.Append('maps;maps-downloadmaps;') }
    If ($RemovedAppxPackages -contains 'Microsoft.YourPhone' -or $RemovedSystemApps -contains 'Microsoft.Windows.CallingShellApp') { [void]$Visibility.Append('mobile-devices;mobile-devices-addphone;mobile-devices-addphone-direct;') }
    $Visibility = $Visibility.ToString().TrimEnd(';')
    Get-OfflineHives -Load
    Set-KeyProperty -Path "HKLM:\WIM_HKLM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "SettingsPageVisibility" -Value $Visibility -Type String
    Set-KeyProperty -Path "HKLM:\WIM_HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "SettingsPageVisibility" -Value $Visibility -Type String
    Get-OfflineHives -Unload
}

If ($Additional.IsPresent -and (Test-Path -Path $ConfigFilePath))
{
    Clear-Host
    $AdditionalParams = Import-Config
    If ($AdditionalParams.Unattend -eq $true -and (Test-Path -Path "$AdditionalPath\Unattend\unattend.xml"))
    {
        Try
        {
            $Host.UI.RawUI.WindowTitle = "Applying Answer File."
            Write-Log -Info "Applying Answer File."
            $UnattendParams = @{
                UnattendPath     = "$AdditionalPath\Unattend\unattend.xml"
                Path             = $InstallMount
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Use-WindowsUnattend @UnattendParams)
            New-Container -Path "$InstallMount\Windows\Panther"
            Copy-Item -Path "$AdditionalPath\Unattend\unattend.xml" -Destination "$InstallMount\Windows\Panther"
            Start-Sleep 3
        }
        Catch
        {
            Write-Log -Error "Failed to Apply Answer File." -ErrorRecord $Error[0]
            Remove-Container -Path "$InstallMount\Windows\Panther"
            Start-Sleep 3
        }
    }
    If ($AdditionalParams.Setup -eq $true -and (Test-Path -Path "$AdditionalPath\Setup\*"))
    {
        $Host.UI.RawUI.WindowTitle = "Applying Setup Content."
        Write-Log -Info "Applying Setup Content."
        New-Container -Path "$InstallMount\Windows\Setup\Scripts"
        Get-ChildItem -Path "$AdditionalPath\Setup" -Exclude README.md | Copy-Item -Destination "$InstallMount\Windows\Setup\Scripts" -Recurse
        Start-Sleep 3
    }
    If ($AdditionalParams.Wallpaper -eq $true -and (Test-Path -Path "$AdditionalPath\Wallpaper\*"))
    {
        $Host.UI.RawUI.WindowTitle = "Applying Wallpaper."
        Write-Log -Info "Applying Wallpaper."
        Get-ChildItem -Path "$AdditionalPath\Wallpaper" -Directory | Copy-Item -Destination "$InstallMount\Windows\Web\Wallpaper" -Recurse
        Get-ChildItem -Path "$AdditionalPath\Wallpaper\*" -Include *.jpg, *.png, *.bmp, *.gif -File | Copy-Item -Destination "$InstallMount\Windows\Web\Wallpaper"
        Start-Sleep 3
    }
    If ($AdditionalParams.SystemLogo -eq $true -and (Test-Path -Path "$AdditionalPath\SystemLogo\*.bmp"))
    {
        $Host.UI.RawUI.WindowTitle = "Applying System Logo."
        Write-Log -Info "Applying System Logo."
        New-Container -Path "$InstallMount\Windows\System32\oobe\info\logo"
        Copy-Item -Path "$AdditionalPath\SystemLogo\*.bmp" -Destination "$InstallMount\Windows\System32\oobe\info\logo" -Recurse
        Start-Sleep 3
    }
    If ($AdditionalParams.RegistryTemplates -eq $true -and (Test-Path -Path "$AdditionalPath\RegistryTemplates\*.reg"))
    {
        $Host.UI.RawUI.WindowTitle = "Importing Registry Templates."
        Write-Log -Info "Importing Registry Templates."
        Import-RegistryTemplates
    }
    If ($AdditionalParams.Drivers -eq $true)
    {
        If (Get-ChildItem -Path "$AdditionalPath\Drivers\Install" -Filter *.inf -Recurse)
        {
            Try
            {
                $Host.UI.RawUI.WindowTitle = "Injecting Driver Packages into $($InstallWimInfo.Name)"
                Write-Log -Info "Injecting Driver Packages into $($InstallWimInfo.Name)"
                $InstallDriverParams = @{
                    Path             = $InstallMount
                    Driver           = "$AdditionalPath\Drivers\Install"
                    Recurse          = $true
                    ForceUnsigned    = $true
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Add-WindowsDriver @InstallDriverParams)
                $DynamicParams.Add('InstallDrivers', $true)
            }
            Catch
            {
                Write-Log -Error "Failed to Injecting Driver Packages into $($InstallWimInfo.Name)" -ErrorRecord $Error[0]
                Start-Sleep 3
            }
        }
        If ($DynamicParams['Boot'] -and (Get-ChildItem -Path "$AdditionalPath\Drivers\Boot" -Filter *.inf -Recurse))
        {
            Try
            {
                $Host.UI.RawUI.WindowTitle = "Injecting Driver Packages into $($BootWimInfo.Name)"
                Write-Log -Info "Injecting Driver Packages into $($BootWimInfo.Name)"
                $BootDriverParams = @{
                    Path             = $BootMount
                    Driver           = "$AdditionalPath\Drivers\Boot"
                    Recurse          = $true
                    ForceUnsigned    = $true
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Add-WindowsDriver @BootDriverParams)
                $DynamicParams.Add('BootDrivers', $true)
            }
            Catch
            {
                Write-Log -Error "Failed to Injecting Driver Packages into $($BootWimInfo.Name)" -ErrorRecord $Error[0]
                Start-Sleep 3
            }
        }
        If ($DynamicParams['Recovery'] -and (Get-ChildItem -Path "$AdditionalPath\Drivers\Recovery" -Filter *.inf -Recurse))
        {
            Try
            {
                $Host.UI.RawUI.WindowTitle = "Injecting Driver Packages into $($RecoveryWimInfo.Name)"
                Write-Log -Info "Injecting Driver Packages into $($RecoveryWimInfo.Name)"
                $RecoveryDriverParams = @{
                    Path             = $RecoveryMount
                    Driver           = "$AdditionalPath\Drivers\Recovery"
                    Recurse          = $true
                    ForceUnsigned    = $true
                    ScratchDirectory = $ScratchDirectory
                    LogPath          = $DISMLog
                    ErrorAction      = 'Stop'
                }
                [void](Add-WindowsDriver @RecoveryDriverParams)
                $DynamicParams.Add('RecoveryDrivers', $true)
            }
            Catch
            {
                Write-Log -Error "Failed to Injecting Driver Packages into $($RecoveryWimInfo.Name)" -ErrorRecord $Error[0]
                Start-Sleep 3
            }
        }
    }
    If ($AdditionalParams.NetFx3 -eq $true -and $ISOMedia -and (Get-WindowsOptionalFeature -Path $InstallMount -FeatureName NetFx3 | Where-Object -Property State -EQ DisabledWithPayloadRemoved) -and (Get-ChildItem -Path "$ISOMedia\sources\sxs" -Filter *netfx3*.cab -Recurse))
    {
        Try
        {
            $Host.UI.RawUI.WindowTitle = "Enabling Windows Feature: NetFx3"
            Write-Log -Info "Enabling Windows Feature: NetFx3"
            $NetFx3Params = @{
                Path             = $InstallMount
                FeatureName      = 'NetFx3'
                Source           = "$ISOMedia\sources\sxs"
                All              = $true
                LimitAccess      = $true
                NoRestart        = $true
                ScratchDirectory = $ScratchDirectory
                LogPath          = $DISMLog
                ErrorAction      = 'Stop'
            }
            [void](Enable-WindowsOptionalFeature @NetFx3Params)
        }
        Catch
        {
            Write-Log -Error "Failed to Enable Windows Feature: NetFx3" -ErrorRecord $Error[0]
            Start-Sleep 3
        }
    }
}

Try
{
    $Host.UI.RawUI.WindowTitle = "Cleaning-up the Start Menu Layout."
    Write-Log -Info "Cleaning-up the Start Menu Layout."
    $LayoutModTemplate = @'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
  xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1"
  xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
  xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="">
          <start:DesktopApplicationTile Size="2x2" Column="0" Row="0" DesktopApplicationID="Microsoft.Windows.ControlPanel" />
          <start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\UWP File Explorer.lnk" />
          <start:DesktopApplicationTile Size="2x2" Column="4" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell ISE.lnk" />
        </start:Group>
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
</LayoutModificationTemplate>
'@
    If ($RemovedSystemApps -contains 'c5e2524a-ea46-4f67-841f-6a9465d9d515')
    {
        $UWPFileExplorer = '<start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\UWP File Explorer.lnk" />'
        $FileExplorer = '<start:DesktopApplicationTile Size="2x2" Column="2" Row="0" DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\File Explorer.lnk" />'
        $LayoutModTemplate = $LayoutModTemplate.Replace($UWPFileExplorer, $FileExplorer)
    }
    Else
    {
        $UWPShell = New-Object -ComObject WScript.Shell
        $UWPShortcut = $UWPShell.CreateShortcut("$InstallMount\ProgramData\Microsoft\Windows\Start Menu\Programs\UWP File Explorer.lnk")
        $UWPShortcut.TargetPath = "%SystemRoot%\explorer.exe"
        $UWPShortcut.Arguments = "shell:AppsFolder\c5e2524a-ea46-4f67-841f-6a9465d9d515_cw5n1h2txyewy!App"
        $UWPShortcut.WorkingDirectory = "%SystemRoot%"
        $UWPShortcut.Description = "UWP File Explorer"
        $UWPShortcut.Save()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($UWPShell)
    }
    $LayoutModTemplate | Out-File -FilePath "$InstallMount\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" -Encoding UTF8 -Force
}
Catch
{
    Write-Log -Error "Failed to Clean-up the Start Menu Layout." -ErrorRecord $Error[0]
}
Finally
{
    Start-Sleep 3; Clear-Host
}

Try
{
    $Host.UI.RawUI.WindowTitle = "Creating a Package Summary Log."
    Write-Log -Info "Creating a Package Summary Log."
    If ($WindowsStore.IsPresent) { "`tIntegrated Appx Provisioned Packages:", (Get-AppxProvisionedPackage -Path $InstallMount | Select-Object -Property DisplayName) | Out-File -FilePath $PackageLog -Append }
    Else { If ($WindowsApps -eq 'Select' -or $WindowsApps -eq 'Whitelist') { "`tAppx Provisioned Packages:", (Get-AppxProvisionedPackage -Path $InstallMount | Select-Object -Property DisplayName) | Out-File -FilePath $PackageLog -Append } }
    If ($MicrosoftEdge.IsPresent -or $Dedup.IsPresent -or $DynamicParams['Win32Calc']) { "`tIntegrated Windows Packages:", (Get-WindowsPackage -Path $InstallMount | Where-Object { $_.PackageName -like "*win32calc*" -or $_.PackageName -like "*Internet-Browser*" -or $_.PackageName -like "*Windows-FileServer-ServerCore*" -or $_.PackageName -like "*Windows-Dedup*" } | Select-Object -Property PackageName, PackageState) | Out-File -FilePath $PackageLog -Append }
    If ($Packages.IsPresent) { "`tCapability Packages:", (Get-WindowsCapability -Path $InstallMount | Where-Object -Property State -EQ Installed | Select-Object -Property Name, State) | Out-File -FilePath $PackageLog -Append }
    If ($Features.IsPresent)
    {
        "`tEnabled Optional Features:", (Get-WindowsOptionalFeature -Path $InstallMount | Where-Object -Property State -EQ Enabled | Select-Object -Property FeatureName, State | Sort-Object -Property FeatureName) | Out-File -FilePath $PackageLog -Append
        "`tDisabled Optional Features:", (Get-WindowsOptionalFeature -Path $InstallMount | Where-Object -Property State -EQ Disabled | Select-Object -Property FeatureName, State | Sort-Object -Property FeatureName) | Out-File -FilePath $PackageLog -Append
    }
    If ($DynamicParams['InstallDrivers']) { "`tIntegrated Driver Packages (Install):", (Get-WindowsDriver -Path $InstallMount | Select-Object -Property ProviderName, ClassName, BootCritical, Date, Version | Sort-Object -Property ProviderName) | Out-File -FilePath $PackageLog -Append }
    If ($DynamicParams['BootDrivers']) { "`tIntegrated Driver Packages (Boot):", (Get-WindowsDriver -Path $BootMount | Select-Object -Property ProviderName, ClassName, BootCritical, Date, Version | Sort-Object -Property ProviderName) | Out-File -FilePath $PackageLog -Append }
    If ($DynamicParams['RecoveryDrivers']) { "`tIntegrated Driver Packages (Recovery):", (Get-WindowsDriver -Path $RecoveryMount | Select-Object -Property ProviderName, ClassName, BootCritical, Date, Version | Sort-Object -Property ProviderName) | Out-File -FilePath $PackageLog -Append }
}
Catch
{
    Write-Log -Error "Failed to Compile Package Log." -ErrorRecord $Error[0]
}
Finally
{
    Start-Sleep 3
    If (Get-OfflineHives -Test) { Get-OfflineHives -Unload }
}

If ((Repair-WindowsImage -Path $InstallMount -CheckHealth).ImageHealthState -eq 'Healthy')
{
    Write-Log -Info "Post-Optimization Image Health State: [Healthy]"
    @"
This $($InstallWimInfo.Name) installation was optimized with $($ScriptInfo.Name) version $($ScriptInfo.Version) on
$(Get-Date -UFormat "%m/%d/%Y at %r")
"@ | Out-File -FilePath (Join-Path -Path $InstallMount -ChildPath Optimize-Offline.txt) -Encoding Unicode -Force
    Start-Sleep 3
}
Else
{
    Write-Log -Error "The image has been flagged for corruption. Discarding optimizations."
    Stop-Optimize; Break
}

If ($DynamicParams['Boot'])
{
    Try
    {
        Invoke-Cleanup -Boot
        $Host.UI.RawUI.WindowTitle = "Saving and Dismounting $($BootWimInfo.Name)"
        Write-Log -Info "Saving and Dismounting $($BootWimInfo.Name)"
        $DismountBootImage = @{
            Path             = $BootMount
            Save             = $true
            CheckIntegrity   = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Dismount-WindowsImage @DismountBootImage)
    }
    Catch
    {
        Write-Log -Error "Failed to Save and Dismount $($BootWimInfo.Name)" -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($DynamicParams['Recovery'])
{
    Try
    {
        Invoke-Cleanup -Recovery
        $Host.UI.RawUI.WindowTitle = "Saving and Dismounting $($RecoveryWimInfo.Name)"
        Write-Log -Info "Saving and Dismounting $($RecoveryWimInfo.Name)"
        $DismountRecoveryImage = @{
            Path             = $RecoveryMount
            Save             = $true
            CheckIntegrity   = $true
            ScratchDirectory = $ScratchDirectory
            LogPath          = $DISMLog
            ErrorAction      = 'Stop'
        }
        [void](Dismount-WindowsImage @DismountRecoveryImage)
    }
    Catch
    {
        Write-Log -Error "Failed to Save and Dismount $($RecoveryWimInfo.Name)" -ErrorRecord $Error[0]
        Stop-Optimize; Break
    }
}

If ($DynamicParams['Boot'])
{
    Try
    {
        $Host.UI.RawUI.WindowTitle = "Rebuilding and Exporting $($BootWimInfo.Name)"
        Write-Log -Info "Rebuilding and Exporting $($BootWimInfo.Name)"
        Get-WindowsImage -ImagePath $BootWim | ForEach-Object {
            $ExportBootParams = @{
                SourceImagePath      = $BootWim
                SourceIndex          = $_.ImageIndex
                DestinationImagePath = "$($WorkDirectory)\boot.wim"
                CompressionType      = 'Maximum'
                CheckIntegrity       = $true
                ScratchDirectory     = $ScratchDirectory
                LogPath              = $DISMLog
                ErrorAction          = 'Stop'
            }
            [void](Export-WindowsImage @ExportBootParams)
        }
        Remove-Container -Path $BootWim
        Move-Item -Path "$($WorkDirectory)\boot.wim" -Destination $BootWim -Force
    }
    Catch
    {
        Write-Log -Error "Failed to Export $($BootWimInfo.Name)" -ErrorRecord $Error[0]
        Start-Sleep 3
    }
}

If ($DynamicParams['Recovery'])
{
    Try
    {
        $Host.UI.RawUI.WindowTitle = "Rebuilding and Exporting $($RecoveryWimInfo.Name)"
        Write-Log -Info "Rebuilding and Exporting $($RecoveryWimInfo.Name)"
        $ExportRecovery = @{
            SourceImagePath      = $RecoveryWim
            SourceIndex          = 1
            DestinationImagePath = "$($WorkDirectory)\winre.wim"
            CompressionType      = 'Maximum'
            CheckIntegrity       = $true
            ScratchDirectory     = $ScratchDirectory
            LogPath              = $DISMLog
            ErrorAction          = 'Stop'
        }
        [void](Export-WindowsImage @ExportRecovery)
        Remove-Container -Path $WinREPath
        Move-Item -Path "$($WorkDirectory)\winre.wim" -Destination $WinREPath -Force
    }
    Catch
    {
        Write-Log -Error "Failed to Export $($RecoveryWimInfo.Name)" -ErrorRecord $Error[0]
        Start-Sleep 3
    }
}

Try
{
    Invoke-Cleanup -Install
    $Host.UI.RawUI.WindowTitle = "Saving and Dismounting $($InstallWimInfo.Name)"
    Write-Log -Info "Saving and Dismounting $($InstallWimInfo.Name)"
    $DismountWindowsImage = @{
        Path             = $InstallMount
        Save             = $true
        CheckIntegrity   = $true
        ScratchDirectory = $ScratchDirectory
        LogPath          = $DISMLog
        ErrorAction      = 'Stop'
    }
    [void](Dismount-WindowsImage @DismountWindowsImage)
}
Catch
{
    Write-Log -Error "Failed to Save and Dismount $($InstallWimInfo.Name)" -ErrorRecord $Error[0]
    Stop-Optimize; Break
}

Do
{
    $CompressionList = @('Solid', 'Maximum', 'Fast', 'None') | Select-Object -Property @{ Label = 'Compression'; Expression = { ($_) } } | Out-GridView -Title "Select Final Image Compression." -OutputMode Single
    $CompressionType = $CompressionList | Select-Object -ExpandProperty Compression
}
While ($CompressionList.Length -eq 0)

If ($CompressionType -eq 'Solid') { Write-Warning "Solid compression can take quite a while. Please be patient until it completes."; Start-Sleep 5; Clear-Host }

Try
{
    $Host.UI.RawUI.WindowTitle = "Rebuilding and Exporting $($InstallWimInfo.Name) using $($CompressionType) compression."
    Write-Log -Info "Rebuilding and Exporting $($InstallWimInfo.Name) using $($CompressionType) compression."
    If ($CompressionType -eq 'Solid')
    {
        $RunDism = Start-Executable -Executable "$Env:SystemRoot\System32\DISM.EXE" -Arguments @('/Export-Image /SourceImageFile:"{0}" /SourceIndex:{1} /DestinationImageFile:"{2}" /Compress:Recovery /CheckIntegrity' -f $InstallWim, $ImageIndex, "$($ImageDirectory)\install.esd") -PassThru
        If ($RunDism.ExitCode -eq 0) { Remove-Container -Path $InstallWim; $ImageFiles = @('install.esd', 'boot.wim') }
        Else { Write-Log -Error "Failed to export $($InstallWimInfo.Name) using $($CompressionType) compression."; $ImageFiles = @('install.wim', 'boot.wim') }
    }
    Else
    {
        $ExportInstall = @{
            SourceImagePath      = $InstallWim
            SourceIndex          = $ImageIndex
            DestinationImagePath = "$($WorkDirectory)\install.wim"
            CompressionType      = $CompressionType
            CheckIntegrity       = $true
            ScratchDirectory     = $ScratchDirectory
            LogPath              = $DISMLog
            ErrorAction          = 'Stop'
        }
        [void](Export-WindowsImage @ExportInstall)
        Remove-Container -Path $InstallWim
        Move-Item -Path "$($WorkDirectory)\install.wim" -Destination $InstallWim -Force
        $ImageFiles = @('install.wim', 'boot.wim')
    }
}
Catch
{
    Write-Log -Error "Failed to Export $($InstallWimInfo.Name)" -ErrorRecord $Error[0]
    Stop-Optimize; Break
}

If ($ISOMedia)
{
    $Host.UI.RawUI.WindowTitle = "Optimizing the Windows Media File Structure."
    Write-Log -Info "Optimizing the Windows Media File Structure."
    Get-ChildItem -Path $ISOMedia -Filter *.dll | Remove-Container
    @("$ISOMedia\autorun.inf", "$ISOMedia\setup.exe", "$ISOMedia\ca", "$ISOMedia\NanoServer", "$ISOMedia\support", "$ISOMedia\upgrade", "$ISOMedia\sources\dlmanifests", "$ISOMedia\sources\etwproviders",
        "$ISOMedia\sources\inf", "$ISOMedia\sources\hwcompat", "$ISOMedia\sources\migration", "$ISOMedia\sources\replacementmanifests", "$ISOMedia\sources\servicing", "$ISOMedia\sources\servicingstackmisc",
        "$ISOMedia\sources\sxs", "$ISOMedia\sources\uup", "$ISOMedia\sources\vista", "$ISOMedia\sources\xp") | Remove-Container
    @('.adml', '.mui', '.rtf', '.txt') | ForEach-Object { Get-ChildItem -Path "$ISOMedia\sources\$($InstallWimInfo.Language)" -Filter *$($_) -Exclude 'setup.exe.mui' -Recurse | Remove-Container }
    @('.dll', '.gif', '.xsl', '.bmp', '.mof', '.ini', '.cer', '.exe', '.sdb', '.txt', '.nls', '.xml', '.cat', '.inf', '.sys', '.bin', '.ait', '.admx', '.dat', '.ttf', '.cfg', '.xsd', '.rtf', '.xrm-ms') | ForEach-Object { Get-ChildItem -Path "$ISOMedia\sources" -Filter *$($_) -Exclude @('EI.cfg', 'gatherosstate.exe', 'setup.exe', 'lang.ini', 'pid.txt', '*.clg') -Recurse | Remove-Container }
    Get-ChildItem -Path $ImageDirectory -Include $ImageFiles -Recurse | Move-Item -Destination "$($ISOMedia)\sources" -Force
    If ($ISO)
    {
        If ($ISO -eq 'Prompt' -and (!(Test-Path -Path "$ISOMedia\efi\Microsoft\boot\efisys.bin"))) { Write-Log -Error "Missing the required efisys.bin bootfile for ISO creation."; Start-Sleep 3 }
        ElseIf ($ISO -eq 'No-Prompt' -and (!(Test-Path -Path "$ISOMedia\efi\Microsoft\boot\efisys_noprompt.bin"))) { Write-Log -Error "Missing the required efisys_noprompt.bin bootfile for ISO creation."; Start-Sleep 3 }
        Else
        {
            $Host.UI.RawUI.WindowTitle = "Creating a $($ISO) Bootable Windows Installation Media ISO."
            Write-Log -Info "Creating a $($ISO) Bootable Windows Installation Media ISO."
            $NewISO = New-ISOMedia -BootType $ISO
            If ($NewISO.Path) { $DynamicParams.Add('ISO', $true) }
            Else { Write-Log -Error "ISO creation failed." -ErrorRecord $Error[0] }
        }
    }
}

Try
{
    $Host.UI.RawUI.WindowTitle = "Finalizing Optimizations."
    Write-Log -Info "Finalizing Optimizations."
    $SaveDirectory | New-Container
    If ($DynamicParams['ISO']) { Move-Item -Path $($NewISO.Path) -Destination $SaveDirectory }
    Else
    {
        If ($ISOMedia) { Move-Item -Path $ISOMedia -Destination $SaveDirectory }
        Else { Get-ChildItem -Path $ImageDirectory -Include $ImageFiles -Recurse | Move-Item -Destination $SaveDirectory }
    }
}
Finally
{
    $Timer.Stop()
    Start-Sleep 5
    Write-Log -Info "$($ScriptInfo.Name) completed in [$($Timer.Elapsed.Minutes.ToString())] minutes with [$($Error.Count)] errors."; Write-Log -Footer
    If ($Error.Count -gt 0)
    {
        ($Error | ForEach-Object -Process {
                [PSCustomObject] @{
                    Line  = $_.InvocationInfo.ScriptLineNumber
                    Error = $_.Exception.Message
                }
            } | Format-Table -AutoSize -Wrap | Out-String).Trim() | Out-File -FilePath (Join-Path -Path $LogDirectory -ChildPath ErrorRecord.log) -Force
    }
    @("$DISMLog", "$Env:SystemRoot\Logs\DISM\dism.log") | Remove-Container
    $InstallWimInfo | Out-File -FilePath (Join-Path -Path $LogDirectory -ChildPath WimFileInfo.txt) -Encoding UTF8 -Force
    [void](Get-ChildItem -Path $LogDirectory -Filter *.log | Compress-Archive -DestinationPath (Join-Path -Path $SaveDirectory -ChildPath OptimizeLogs.zip) -CompressionLevel Fastest)
    $TempDirectory | Remove-Container
    [void](Clear-WindowsCorruptMountPoint)
    ((Compare-Object -ReferenceObject (Get-Variable).Name -DifferenceObject $DefaultVariables).InputObject).ForEach{ Remove-Variable -Name $_ -ErrorAction SilentlyContinue }
    $Host.UI.RawUI.WindowTitle = "Optimizations Complete."
}
# SIG # Begin signature block
# MIIMPAYJKoZIhvcNAQcCoIIMLTCCDCkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtQ3XOBvmG6VZC/79xg94dgt/
# MRigggjkMIIDZTCCAk2gAwIBAgIQcvzm3AoNiblMifO61mXaqjANBgkqhkiG9w0B
# AQsFADBFMRQwEgYKCZImiZPyLGQBGRYEVEVDSDEVMBMGCgmSJomT8ixkARkWBU9N
# TklDMRYwFAYDVQQDEw1PTU5JQy5URUNILUNBMB4XDTE5MDUxNTEyMDYwN1oXDTI0
# MDUxNTEyMTYwN1owRTEUMBIGCgmSJomT8ixkARkWBFRFQ0gxFTATBgoJkiaJk/Is
# ZAEZFgVPTU5JQzEWMBQGA1UEAxMNT01OSUMuVEVDSC1DQTCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAMivWQ61s2ol9vV7TTAhP5hy2CADYNl0C/yVE7wx
# 4eEeiVfiFT+A78GJ4L1h2IbTM6EUlGAtxlz152VFBrY0Hm/nQ1WmrUrneFAb1kTb
# NLGWCyoH9ImrZ5l7NCd97XTZUYsNtbix3nMqUuPPq+UA23pekolHBCpRoDdya22K
# XEgFhOdWfKWsVSCZYiQZyT/moXO2aCmgILq0qtNvNS24grVXTX+qgr1OeiOIF+0T
# SB1oYqTNvROUJ4D6sv4Ap5hJ5PFYmbQrBnytEBGQwXyumQGoK8l/YUBbScsoSjNH
# +GkJMVox7GZObEGf1aLNMCXh7bjpXFw/RJgvBmypkWPIdOUCAwEAAaNRME8wCwYD
# VR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFGzmcuTlwYRYLA1E
# /XGZHHp2+GqTMBAGCSsGAQQBgjcVAQQDAgEAMA0GCSqGSIb3DQEBCwUAA4IBAQCk
# iQqEJdY3YdQWWM3gBqfgJOaqA4oMTAJCIwj+N3zc4UUChaMOq5kAKRRLMtXOv9fH
# 7L0658kt0+URQIB3GrtkV/h3VYdwACWQLGHvGfZ2paFQTF7vT8KA4fi8pkfRoupg
# 4PZ+drXL1Nq/Nbsr0yaakm2VSlij67grnMOdYBhwtf919qQZdvodJQKL+XipjmT3
# tapbg0FMnugL6vhsB6H8nGWO8szHws2UkiWXSmnECJLYQxZ009do3L0/J4BJvak5
# RUzNcZJIuTnifEIax68UcKHU8bFAaiz5Zns74d0qqZx6ZctYLlPI58mhSn9pohoL
# ozlL4YdE7lQ8EDTiKZTIMIIFdzCCBF+gAwIBAgITGgAAAAgLhnXW+w68VgAAAAAA
# CDANBgkqhkiG9w0BAQsFADBFMRQwEgYKCZImiZPyLGQBGRYEVEVDSDEVMBMGCgmS
# JomT8ixkARkWBU9NTklDMRYwFAYDVQQDEw1PTU5JQy5URUNILUNBMB4XDTE5MDUx
# ODE5MDQ1NloXDTIwMDUxNzE5MDQ1NlowUzEUMBIGCgmSJomT8ixkARkWBFRFQ0gx
# FTATBgoJkiaJk/IsZAEZFgVPTU5JQzEOMAwGA1UEAxMFVXNlcnMxFDASBgNVBAMT
# C0JlblRoZUdyZWF0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvnkk
# jYlPGAeAApx5Qgn0lbHLI2jywWcsMl2Aff0FDH+4IemQQSQWsU+vCuunrpqvCXMB
# 7yHgecxw37BWnbfEpUyYLZAzuDUxJM1/YQclhH7yOb0GvhHaUevDMCPaqFT1/QoS
# 4PzMim9nj1CU7un8QVTnUCSivC88kJnvBA6JciUoRGU5LAjLDhrMa+v+EQjnkErb
# Y0L3bi3D+ROA23D1oS6nuq27zeRHawod1wscT+BYGiyP/7w8u/GQdGZPeNdw0168
# XCEicDUEiB/s4TI4dCr+0B80eI/8jHTYs/LFj+v6QETiQChR5Vk8lsS3On1LI8Fo
# 8Ki+PPgYCdScxiYNfQIDAQABo4ICUDCCAkwwJQYJKwYBBAGCNxQCBBgeFgBDAG8A
# ZABlAFMAaQBnAG4AaQBuAGcwEwYDVR0lBAwwCgYIKwYBBQUHAwMwDgYDVR0PAQH/
# BAQDAgeAMB0GA1UdDgQWBBQQg/QKzp8JFAJtalEPhIrNKV7A2jAfBgNVHSMEGDAW
# gBRs5nLk5cGEWCwNRP1xmRx6dvhqkzCByQYDVR0fBIHBMIG+MIG7oIG4oIG1hoGy
# bGRhcDovLy9DTj1PTU5JQy5URUNILUNBLENOPUFOVUJJUyxDTj1DRFAsQ049UHVi
# bGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlv
# bixEQz1PTU5JQyxEQz1URUNIP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFz
# ZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludDCBvgYIKwYBBQUHAQEE
# gbEwga4wgasGCCsGAQUFBzAChoGebGRhcDovLy9DTj1PTU5JQy5URUNILUNBLENO
# PUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1D
# b25maWd1cmF0aW9uLERDPU9NTklDLERDPVRFQ0g/Y0FDZXJ0aWZpY2F0ZT9iYXNl
# P29iamVjdENsYXNzPWNlcnRpZmljYXRpb25BdXRob3JpdHkwMQYDVR0RBCowKKAm
# BgorBgEEAYI3FAIDoBgMFkJlblRoZUdyZWF0QE9NTklDLlRFQ0gwDQYJKoZIhvcN
# AQELBQADggEBAEyyXCN8L6z4q+gFjbm3B3TvuCAlptX8reIuDg+bY2Bn/WF2KXJm
# +FNZakUKccesxl2XUJo2O7KZBKKjZYMwEBK7NhTOvC50VupJc0p6aXrMrcOnAjAn
# NrjWbKYmc6bG7uCzuEBPlJVmnhdRLgRJKfJDAfXPWkYebV666WnggugL4ROOYtOY
# 3J8j/2cyYE6OD5YTl1ydnYzyNUeZq2IVfxw5BK83lVK5uuneg+4QQaUNWBU5mtIa
# 6t748F1ZEQm3UNk8ImFKWp4dsgAHpPC5wZo/BAMO8PP8BW3+6yvewWnUAGTU4f07
# b1SjZsLcQ6D0eCcFD+7I7MkcSz2ARu6wUOcxggLCMIICvgIBATBcMEUxFDASBgoJ
# kiaJk/IsZAEZFgRURUNIMRUwEwYKCZImiZPyLGQBGRYFT01OSUMxFjAUBgNVBAMT
# DU9NTklDLlRFQ0gtQ0ECExoAAAAIC4Z11vsOvFYAAAAAAAgwCQYFKw4DAhoFAKCC
# ATswGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFMpcJVBfW0D0Bsr2drVKWnx1qqu5
# MIHaBgorBgEEAYI3AgEMMYHLMIHIoIGRgIGOAEEAIABmAHUAbABsAHkAIABhAHUA
# dABvAG0AYQB0AGUAZAAgAFcAaQBuAGQAbwB3AHMAIAAxADAAIABSAFMANAAtAFIA
# UwA2ACAAbwBmAGYAbABpAG4AZQAgAGkAbQBhAGcAZQAgAG8AcAB0AGkAbQBpAHoA
# YQB0AGkAbwBuACAAcwBjAHIAaQBwAHQALqEygDBodHRwczovL2dpdGh1Yi5jb20v
# RHJFbXBpcmljaXNtL09wdGltaXplLU9mZmxpbmUwDQYJKoZIhvcNAQEBBQAEggEA
# FGbnSrKBUkQqFvgOE/JOOI/3h6Ut7SDY1Pu28f//4aYlfxycN8N8t1PW02cO6h+/
# TK1XydrI5HJwuZx4Owbl1F1HyRXAMxm1HmI7qPDEOYcZWt7/xOqqT1y/+0rlBohm
# 80rg6ucXy3qLI7PbDBqi5doOJz5+yKNflHh83m6b/OEDtIievQi2uRXVX3mS1YUz
# lPzE4St5X0ECo3jN6QWDiy1sbhBe7EAat6RbESEKzNcq2Eo1v8xyw/XMVz15tYaS
# llBrtw1SK0CIdzCaJfipQPbcQSeNggHPCQiQNf1v0mE/g9qySbVrMy8Gx1NucYX5
# DmxvbFEYqS94u1nWkBxh9w==
# SIG # End signature block
