﻿<#
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.167
	 Created by:   	BenTheGreat
	 Filename:     	Functions.psm1
	 Last updated:	09/03/2019
	===========================================================================
#>

#region Module Variables
$ProgressPreference = 'SilentlyContinue'
$DynamicParams = [Hashtable]@{ }
$ScriptRootPath = Split-Path -Path $PSScriptRoot -Parent
$ResourcesPath = Join-Path -Path $ScriptRootPath -ChildPath Resources
$AdditionalPath = Join-Path -Path $ScriptRootPath -ChildPath 'Content\Additional'
$DaRTPath = Join-Path -Path $ResourcesPath -ChildPath DaRT
$DedupPath = Join-Path -Path $ResourcesPath -ChildPath Deduplication
$EdgeAppPath = Join-Path -Path $ResourcesPath -ChildPath MicrosoftEdge
$StoreAppPath = Join-Path -Path $ResourcesPath -ChildPath WindowsStore
$Win32CalcPath = Join-Path -Path $ResourcesPath -ChildPath Win32Calc
$ConfigFilePath = Join-Path -Path $AdditionalPath -ChildPath Config.ini
$AppxWhitelistPath = Join-Path -Path $ScriptRootPath -ChildPath 'Content\AppxWhiteList.xml'
$AppAssocPath = Join-Path -Path $ScriptRootPath -ChildPath 'Content\CustomAppAssociations.xml'
$TempDirectory = Join-Path -Path $ScriptRootPath -ChildPath "OptimizeOfflineTemp_$(Get-Random)"
$LogDirectory = Join-Path -Path $TempDirectory -ChildPath LogOffline
$WorkDirectory = Join-Path -Path $TempDirectory -ChildPath WorkOffline
$ScratchDirectory = Join-Path -Path $TempDirectory -ChildPath ScratchOffline
$ImageDirectory = Join-Path -Path $TempDirectory -ChildPath ImageOffline
$InstallMount = Join-Path -Path $TempDirectory -ChildPath InstallMountOffline
$BootMount = Join-Path -Path $TempDirectory -ChildPath BootMountOffline
$RecoveryMount = Join-Path -Path $TempDirectory -ChildPath RecoveryMountOffline
$SaveDirectory = Join-Path -Path $ScriptRootPath -ChildPath Optimize-Offline"_$((Get-Date).ToString('yyyy-MM-ddThh.mm.ss'))"
$ScriptLog = Join-Path -Path $LogDirectory -ChildPath Optimize-Offline.log
$PackageLog = Join-Path -Path $LogDirectory -ChildPath PackageList.log
$DISMLog = Join-Path -Path $LogDirectory -ChildPath DISM.log
#endregion Module Variables

#region Module Functions
Function Import-Config
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param ()

    $ConfigObj = New-Object -TypeName PSObject -Property @{ }
    Get-Content -Path $ConfigFilePath | ForEach-Object {
        If ($_ -match '=')
        {
            $Data = $_.Split('=').Trim()
            If ($Data[1] -eq "True" -or $Data[1] -eq "False") { $Data[1] = [Convert]::ToBoolean($Data[1]) }
            $ConfigObj | Add-Member -MemberType NoteProperty -Name $Data[0] -Value $Data[1]
        }
    }
    $ConfigObj
}

Function Write-Log
{
    [CmdletBinding(DefaultParameterSetName = 'Info')]
    Param
    (
        [Parameter(ParameterSetName = 'Info')]
        [string]$Info,
        [Parameter(ParameterSetName = 'Error')]
        [string]$Error,
        [Parameter(ParameterSetName = 'Error',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(ParameterSetName = 'Header')]
        [switch]$Header,
        [Parameter(ParameterSetName = 'Footer')]
        [switch]$Footer,
        [Parameter(ParameterSetName = 'Failed')]
        [switch]$Failed
    )

    Begin
    {
        $Timestamp = (Get-Date -Format 's')
        $LogMutex = New-Object System.Threading.Mutex($false, "SyncLogMutex")
        [void]$LogMutex.WaitOne()
    }
    Process
    {
        Switch ($PSBoundParameters.Keys)
        {
            'Header'
            {
                @"
***************************************************************************************************

$($ScriptInfo.Name) v$($ScriptInfo.Version) starting on [$(Get-Date -UFormat "%m/%d/%Y at %r")]

***************************************************************************************************
Optimizing image: $($InstallWimInfo.Name)
***************************************************************************************************

"@ | Out-File -FilePath $ScriptLog -Encoding UTF8
            }
            'Footer'
            {
                @"

***************************************************************************************************
Optimizations finalized on [$(Get-Date -UFormat "%m/%d/%Y at %r")]
***************************************************************************************************
"@ | Out-File -FilePath $ScriptLog -Encoding UTF8 -Append
            }
            'Failed'
            {
                @"

***************************************************************************************************
Optimizations failed on [$(Get-Date -UFormat "%m/%d/%Y at %r")]
***************************************************************************************************
"@ | Out-File -FilePath $ScriptLog -Encoding UTF8 -Append
            }
            'Info'
            {
                "$Timestamp [INFO]: $Info" | Out-File -FilePath $ScriptLog -Encoding UTF8 -Append
                Write-Host $Info -ForegroundColor Cyan
            }
            'Error'
            {
                "$Timestamp [ERROR]: $Error" | Out-File -FilePath $ScriptLog -Encoding UTF8 -Append
                Write-Host $Error -ForegroundColor Red
                If ($PSBoundParameters.ContainsKey('ErrorRecord'))
                {
                    $ExceptionMessage = '{0} ({1}: {2}:{3} char:{4})' -f $ErrorRecord.Exception.Message,
                    $ErrorRecord.FullyQualifiedErrorId,
                    $ErrorRecord.InvocationInfo.ScriptName,
                    $ErrorRecord.InvocationInfo.ScriptLineNumber,
                    $ErrorRecord.InvocationInfo.OffsetInLine
                    "$Timestamp [ERROR]: $ExceptionMessage" | Out-File -FilePath $ScriptLog -Encoding UTF8 -Append
                    Write-Host $ExceptionMessage -ForegroundColor Red
                }
            }
        }
    }
    End
    {
        [void]$LogMutex.ReleaseMutex()
    }
}

Function Get-WimFileInfo
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0)]
        [IO.FileInfo]$WimFile,
        [Parameter(Mandatory = $false)]
        [Int]$Index = 1
    )

    $WimImage = (Get-WindowsImage -ImagePath $WimFile.FullName -Index $Index -ErrorAction SilentlyContinue)
    $WimObject = [PSCustomObject]@{
        Name             = $($WimImage.ImageName)
        Description      = $($WimImage.ImageDescription)
        Size             = [Math]::Round($WimImage.ImageSize / 1GB).ToString() + " GB"
        Edition          = $($WimImage.EditionID)
        Version          = $($WimImage.Version)
        Build            = $($WimImage.Build).ToString()
        InstallationType = $($WimImage.InstallationType)
        Language         = $($WimImage.Languages)
    }
    If ($WimImage.Architecture -eq 0) { $WimObject | Add-Member -MemberType NoteProperty -Name Architecture -Value $($WimImage.Architecture -replace '0', 'x86') }
    ElseIf ($WimImage.Architecture -eq 9) { $WimObject | Add-Member -MemberType NoteProperty -Name Architecture -Value $($WimImage.Architecture -replace '9', 'amd64') }
    $WimObject
}

Function Start-Executable
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            Position = 0)]
        [IO.FileInfo]$Executable,
        [string[]]$Arguments,
        [switch]$PassThru
    )

    Begin
    {
        $StandardOutFile = "$WorkDirectory\$($Executable.Name)-StandardOutput.txt"
        $StandardErrFile = "$WorkDirectory\$($Executable.Name)-StandardError.txt"
        $ExeParams = @{
            FilePath               = $($Executable.FullName)
            RedirectStandardError  = $StandardErrFile
            RedirectStandardOutput = $StandardOutFile
            Wait                   = $true
            WindowStyle            = 'Hidden'
            PassThru               = $true
        }
        If ($Arguments) { $ExeParams.Add('ArgumentList', $Arguments) }
    }
    Process
    {
        $RunExe = Start-Process @ExeParams
        If ($PassThru.IsPresent)
        {
            $Result = New-Object -TypeName PSObject -Property @{ ExitCode = $RunExe.ExitCode }
            $RunOutput = Get-Content -Path $StandardOutFile -Raw -ErrorAction Ignore
            $RunError = Get-Content -Path $StandardErrFile -Raw -ErrorAction Ignore
            If ($RunExe.ExitCode -ne 0)
            {
                If ($RunOutput) { $Result | Add-Member -MemberType NoteProperty StandardOutput -Value $RunOutput.Trim() }
                If ($RunError) { $Result | Add-Member -MemberType NoteProperty StandardError -Value $RunError.Trim() }
            }
            $Result
        }
    }
    End
    {
        $StandardOutFile, $StandardErrFile | Remove-Container
    }
}


Function Get-OfflineHives
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    Param
    (
        [Parameter(ParameterSetName = 'Load')]
        [switch]$Load,
        [Parameter(ParameterSetName = 'Unload')]
        [switch]$Unload,
        [Parameter(ParameterSetName = 'Test')]
        [switch]$Test
    )

    Switch ($PSBoundParameters.Keys)
    {
        'Load'
        {
            @(('HKLM\WIM_HKLM_SOFTWARE "{0}"' -f "$($InstallMount)\Windows\System32\config\software"),
                ('HKLM\WIM_HKLM_SYSTEM "{0}"' -f "$($InstallMount)\Windows\System32\config\system"),
                ('HKLM\WIM_HKCU "{0}"' -f "$($InstallMount)\Users\Default\NTUSER.DAT"),
                ('HKLM\WIM_HKU_DEFAULT "{0}"' -f "$($InstallMount)\Windows\System32\config\default")) | ForEach-Object { Start-Executable -Executable "$Env:SystemRoot\System32\REG.EXE" -Arguments ("LOAD $($_)") }; Break
        }
        'Unload'
        {
            [System.GC]::Collect()
            @('HKLM\WIM_HKLM_SOFTWARE', 'HKLM\WIM_HKLM_SYSTEM', 'HKLM\WIM_HKCU', 'HKLM\WIM_HKU_DEFAULT') | ForEach-Object { Start-Executable -Executable "$Env:SystemRoot\System32\REG.EXE" -Arguments ('UNLOAD {0}' -f $($_)) }; Break
        }
        'Test'
        {
            @('HKLM:\WIM_HKLM_SOFTWARE', 'HKLM:\WIM_HKLM_SYSTEM', 'HKLM:\WIM_HKCU', 'HKLM:\WIM_HKU_DEFAULT') | ForEach-Object { If (Test-Path -Path $($_)) { $true } }; Break
        }
    }
}

Function New-Container
{
    [CmdletBinding()]
    [OutputType([IO.FileSystemInfo])]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,
        [switch]$PassThru
    )

    Process
    {
        ForEach ($Item In $Path)
        {
            If (!(Test-Path -LiteralPath $Item))
            {
                $Container = New-Item -Path $Item -ItemType Directory -Force
                If ($PassThru.IsPresent) { $Container }
            }
        }
    }
}

Function Remove-Container
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path
    )

    Process
    {
        ForEach ($Item In $Path)
        {
            If (Test-Path -LiteralPath $Item)
            {
                Remove-Item -LiteralPath $Item -Recurse -Force
            }
        }
    }
}

Function Set-KeyProperty
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        $Value,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('DWord', 'String', 'ExpandString', 'QWord', 'Binary')]
        [string]$Type
    )

    Begin
    {
        Switch ($Type)
        {
            'DWord' { [int32]$Value = $Value; Break }
            'String' { [string]$Value = $Value; Break }
            'ExpandString' { [string]$Value = $Value; Break }
            'QWord' { [int64]$Value = $Value; Break }
            'Binary' { [byte[]]$Value = $Value; Break }
        }
    }
    Process
    {
        ForEach ($Item In $Path)
        {
            If (Test-Path -LiteralPath $Item)
            {
                Set-ItemProperty -LiteralPath $Item -Name $Name -Value $Value -Type $Type -Force
            }
            Else
            {
                [void](New-Item -Path $Item -ItemType Directory -Force)
                [void](New-ItemProperty -LiteralPath $Item -Name $Name -Value $Value -PropertyType $Type -Force)
            }
        }
    }
}

Function Import-RegistryTemplates
{
    [CmdletBinding()]
    Param ()

    Begin
    {
        $RegistryTemplates = Join-Path -Path $AdditionalPath -ChildPath RegistryTemplates
        $RegLog = Join-Path -Path $LogDirectory -ChildPath Registry-Optimizations.log
        Get-ChildItem -Path $RegistryTemplates -Filter *.reg -Recurse | ForEach-Object -Process {
            $REGContent = Get-Content -Path $($_.FullName)
            $REGContent = $REGContent -replace 'HKEY_LOCAL_MACHINE\\SOFTWARE', 'HKEY_LOCAL_MACHINE\WIM_HKLM_SOFTWARE'
            $REGContent = $REGContent -replace 'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet', 'HKEY_LOCAL_MACHINE\WIM_HKLM_SYSTEM\ControlSet001'
            $REGContent = $REGContent -replace 'HKEY_LOCAL_MACHINE\\SYSTEM', 'HKEY_LOCAL_MACHINE\WIM_HKLM_SYSTEM'
            $REGContent = $REGContent -replace 'HKEY_CLASSES_ROOT', 'HKEY_LOCAL_MACHINE\WIM_HKLM_SOFTWARE\Classes'
            $REGContent = $REGContent -replace 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE\WIM_HKCU'
            $REGContent = $REGContent -replace 'HKEY_USERS\\.DEFAULT', 'HKEY_LOCAL_MACHINE\WIM_HKU_DEFAULT'
            $REGContent | Set-Content -Path "$($_.FullName.Replace('.reg', '_Offline.reg'))" -Encoding Unicode -Force
        }
        $Templates = Get-ChildItem -Path $RegistryTemplates -Filter *_Offline.reg -Recurse | Select-Object -Property Name, BaseName, Extension, Directory, FullName
        Get-OfflineHives -Load
    }
    Process
    {
        ForEach ($Template In $Templates)
        {
            Write-Output ('Importing Registry Template: "{0}"' -f $($Template.BaseName.Replace('_Offline', $null))) >> $RegLog
            $RegEdit = Start-Executable -Executable "$Env:SystemRoot\REGEDIT.EXE" -Arguments ('/S "{0}"' -f $Template.FullName) -PassThru
            If ($RegEdit.ExitCode -ne 0) { Write-Log -Error ('Failed to Import Registry Template: "{0}"' -f $($Template.BaseName.Replace('_Offline', $null))) }
            Remove-Container -Path $Template.FullName
        }
    }
    End
    {
        Get-OfflineHives -Unload
    }
}

Function New-ISOMedia
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Prompt', 'No-Prompt')]
        [string]$BootType
    )

    Begin
    {
        $CompilerParams = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters -Property @{
            CompilerOptions       = '/unsafe'
            WarningLevel          = 4
            TreatWarningsAsErrors = $true
        }
        If (!('ISOWriter' -as [Type]))
        {
            Add-Type -CompilerParameters $CompilerParams -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices.ComTypes;
public class ISOWriter
{
    public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
    {
        int BytesRead = 0;
        byte[] Buffer = new byte[BlockSize];
        int* Pointer = &BytesRead;
        var OpenFile = System.IO.File.OpenWrite(Path);
        var IStream = Stream as System.Runtime.InteropServices.ComTypes.IStream;
        if (OpenFile != null)
        {
            while (TotalBlocks-- > 0)
            {
                IStream.Read(Buffer, BlockSize, (IntPtr)Pointer);
                OpenFile.Write(Buffer, 0, BytesRead);
            }
            OpenFile.Flush();
            OpenFile.Close();
        }
    }
}
'@
        }
        Switch ($BootType)
        {
            'Prompt' { $BootFile = Get-Item -LiteralPath "$ISOMedia\efi\Microsoft\boot\efisys.bin" }
            'No-Prompt' { $BootFile = Get-Item -LiteralPath "$ISOMedia\efi\Microsoft\boot\efisys_noprompt.bin" }
        }
        $FileSystem = @{ UDF = 4 }
        $PlatformId = @{ EFI = 0xEF }
        ($BootStream = New-Object -ComObject ADODB.Stream -Property @{ Type = 1 }).Open()
        $BootStream.LoadFromFile($BootFile.FullName)
        ($BootOptions = New-Object -ComObject IMAPI2FS.BootOptions -Property @{ PlatformId = $PlatformId.EFI }).AssignBootImage($BootStream)
        ($FSImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage -Property @{ FileSystemsToCreate = $FileSystem.UDF; VolumeName = $($InstallWimInfo.Name) }).ChooseImageDefaultsForMediaType(13)
    }
    Process
    {
        ForEach ($Item In Get-ChildItem -Path $ISOMedia -Force)
        {
            If ($Item -isnot [IO.FileInfo] -and $Item -isnot [IO.DirectoryInfo]) { $Item = Get-Item -LiteralPath $Item -Force }
            If ($Item) { $FSImage.Root.AddTree($Item.FullName, $true) }
        }
    }
    End
    {
        $FSImage.BootImageOptions = $BootOptions
        $WriteISO = $FSImage.CreateResultImage()
        $ISOFile = New-Item -Path $WorkDirectory -Name ($($InstallWimInfo.Edition).Replace(' ', '') + "_$($InstallWimInfo.Build).iso") -ItemType File -Force
        [ISOWriter]::Create($ISOFile.FullName, $WriteISO.ImageStream, $WriteISO.BlockSize, $WriteISO.TotalBlocks)
        [PSCustomObject]@{ Path = $ISOFile.FullName }
        While ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($WriteISO) -gt 0) { }
        While ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($BootOptions) -gt 0) { }
        While ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($BootStream) -gt 0) { }
        While ([System.Runtime.Interopservices.Marshal]::ReleaseComObject($FSImage) -gt 0) { }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

Function Grant-Privilege
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [string[]]$Privilege,
        [switch]$Disable
    )

    Begin
    {
        Add-Type @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public class AccessToken
{
    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool LookupPrivilegeValue(string host, string name, ref long luid);
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool AdjustTokenPrivileges(IntPtr token, bool disall, ref TOKEN_PRIVILEGES newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool OpenProcessToken(IntPtr curProcess, int acc, ref IntPtr processToken);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct TOKEN_PRIVILEGES
    {
        public int Count;
        public long Luid;
        public int Attr;
    }
    internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int TOKEN_QUERY = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    public static void AdjustPrivilege(IntPtr curProcess, string privilege, bool enable)
    {
        var processToken = IntPtr.Zero;
        if (!OpenProcessToken(curProcess, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref processToken))
        {
            throw new Win32Exception();
        }
        try
        {
            var privileges = new TOKEN_PRIVILEGES
            {
                Count = 1,
                Luid = 0,
                Attr = enable ? SE_PRIVILEGE_ENABLED : SE_PRIVILEGE_DISABLED,
            };
            if (!LookupPrivilegeValue(
                    null,
                    privilege,
                    ref privileges.Luid) || !AdjustTokenPrivileges(
                    processToken,
                    false,
                    ref privileges,
                    0,
                    IntPtr.Zero,
                    IntPtr.Zero))
            {
                throw new Win32Exception();
            }
        }
        finally
        {
            CloseHandle(processToken);
        }
    }
}
'@
        $CurrentProcess = Get-Process -Id $PID
    }
    Process
    {
        $Privilege | ForEach-Object { [AccessToken]::AdjustPrivilege($CurrentProcess.Handle, $_, !$Disable) }
    }
    End
    {
        $CurrentProcess.Close()
    }
}

Function Grant-FileOwnership
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]$Path
    )

    Begin
    {
        'SeTakeOwnershipPrivilege', 'SeBackupPrivilege', 'SeRestorePrivilege' | Grant-Privilege
        $Admin = ((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')).Translate([System.Security.Principal.NTAccount]))
        $Rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $Inheritance = [System.Security.AccessControl.InheritanceFlags]::None
        $Propagation = [System.Security.AccessControl.PropagationFlags]::None
        $Type = [System.Security.AccessControl.AccessControlType]::Allow
    }
    Process
    {
        ForEach ($Item In $Path)
        {
            $ACL = Get-Acl -Path $Item
            $ACL.SetOwner($Admin)
            $ACL.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($Admin, $Rights, $Inheritance, $Propagation, $Type)))
            $ACL | Set-Acl -Path $Item
        }
    }
    End
    {
        'SeTakeOwnershipPrivilege', 'SeBackupPrivilege', 'SeRestorePrivilege' | Grant-Privilege -Disable
    }
}

Function Grant-FolderOwnership
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]$Path
    )

    Process
    {
        ForEach ($Item In $Path)
        {
            Grant-FileOwnership -Path $Item
            ForEach ($Object In Get-ChildItem $Item -Recurse -Force)
            {
                If (Test-Path $Object.FullName -PathType Container)
                {
                    Grant-FolderOwnership -Path $($Object.FullName)
                }
                Else
                {
                    Grant-FileOwnership -Path $($Object.FullName)
                }
            }
        }
    }
}

Function Dismount-Images
{
    [CmdletBinding()]
    Param ()

    If (Get-OfflineHives -Test) { Get-OfflineHives -Unload }
    $QueryHives = Invoke-Expression -Command ('REG QUERY HKLM | FINDSTR Optimize-Offline')
    If ($QueryHives) { $QueryHives | ForEach-Object { Start-Executable -Executable "$Env:SystemRoot\System32\REG.EXE" -Arguments ('UNLOAD {0}' -f $($_)) } }
    $MountPath = @()
    If ((Get-WindowsImage -Mounted).ImagePath -match "winre.wim") { $MountPath += (Get-WindowsImage -Mounted).MountPath | Where-Object { $_ -like "*Recovery*" } }
    If ((Get-WindowsImage -Mounted).ImagePath -match "install.wim") { $MountPath += (Get-WindowsImage -Mounted).MountPath | Where-Object { $_ -like "*Install*" } }
    If ((Get-WindowsImage -Mounted).ImagePath -match "boot.wim") { $MountPath += (Get-WindowsImage -Mounted).MountPath | Where-Object { $_ -like "*Boot*" } }
    $MountPath.ForEach{ [void](Dismount-WindowsImage -Path $_ -Discard) }
    [void](Clear-WindowsCorruptMountPoint)
}

Function Invoke-Cleanup
{
    [CmdletBinding(DefaultParameterSetName = 'None')]
    Param
    (
        [Parameter(ParameterSetName = 'Install')]
        [switch]$Install,
        [Parameter(ParameterSetName = 'Boot')]
        [switch]$Boot,
        [Parameter(ParameterSetName = 'Recovery')]
        [switch]$Recovery
    )

    $MountPath = Switch ($PSBoundParameters.Keys)
    {
        'Install' { $InstallMount }
        'Boot' { $BootMount }
        'Recovery' { $RecoveryMount }
    }
    If (Test-Path -Path "$MountPath\Windows\WinSxS\Temp\PendingDeletes\*")
    {
        Grant-FileOwnership -Path "$MountPath\Windows\WinSxS\Temp\PendingDeletes\*"
        Remove-Container -Path "$MountPath\Windows\WinSxS\Temp\PendingDeletes\*"
    }
    If (Test-Path -Path "$MountPath\Windows\WinSxS\Temp\TransformerRollbackData\*")
    {
        Grant-FolderOwnership -Path "$MountPath\Windows\WinSxS\Temp\TransformerRollbackData\*"
        Remove-Container -Path "$MountPath\Windows\WinSxS\Temp\TransformerRollbackData\*"
    }
    If (Test-Path -Path "$MountPath\Windows\WinSxS\ManifestCache\*.bin")
    {
        Grant-FileOwnership -Path "$MountPath\Windows\WinSxS\ManifestCache\*.bin"
        Remove-Container -Path "$MountPath\Windows\WinSxS\ManifestCache\*.bin"
    }
    @("$MountPath\Windows\INF\*.log", "$MountPath\Windows\CbsTemp\*", "$MountPath\PerfLogs", ("$MountPath\" + '$Recycle.Bin')) | Remove-Container
}

Function Stop-Optimize
{
    [CmdletBinding()]
    Param ()

    $Host.UI.RawUI.WindowTitle = "Dismounting and discarding the image."
    Write-Log -Info "Dismounting and discarding the image."; Write-Log -Failed
    Dismount-Images
    @("$DISMLog", "$Env:SystemRoot\Logs\DISM\dism.log") | Remove-Container
    $SaveDirectory | New-Container
    If ($Error.Count -gt 0)
    {
        ($Error | ForEach-Object -Process {
                [PSCustomObject] @{
                    Line  = $_.InvocationInfo.ScriptLineNumber
                    Error = $_.Exception.Message
                }
            } | Format-Table -AutoSize -Wrap | Out-String).Trim() | Out-File -FilePath (Join-Path -Path $SaveDirectory -ChildPath ErrorRecord.log) -Force
    }
    Get-ChildItem -Path $LogDirectory -Filter *.log | Move-Item -Destination $SaveDirectory -Force
    Remove-Container -Path $TempDirectory
    ((Compare-Object -ReferenceObject (Get-Variable).Name -DifferenceObject $DefaultVariables).InputObject).ForEach{ Remove-Variable -Name $_ -ErrorAction SilentlyContinue }
    Return
}
#endregion Module Functions

$ExportModuleParams = @{
    Function = 'Import-Config', 'Write-Log', 'Get-WimFileInfo', 'Start-Executable', 'Get-OfflineHives', 'New-Container', 'Remove-Container', 'Set-KeyProperty', 'Import-RegistryTemplates', 'New-ISOMedia', 'Grant-FileOwnership', 'Grant-FolderOwnership', 'Dismount-Images', 'Invoke-Cleanup', 'Stop-Optimize'
    Variable = '*'
}
Export-ModuleMember @ExportModuleParams
# SIG # Begin signature block
# MIILtAYJKoZIhvcNAQcCoIILpTCCC6ECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUD9amFlWcskvA1JBxvkAl5OSm
# dzmgggjkMIIDZTCCAk2gAwIBAgIQcvzm3AoNiblMifO61mXaqjANBgkqhkiG9w0B
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
# b1SjZsLcQ6D0eCcFD+7I7MkcSz2ARu6wUOcxggI6MIICNgIBATBcMEUxFDASBgoJ
# kiaJk/IsZAEZFgRURUNIMRUwEwYKCZImiZPyLGQBGRYFT01OSUMxFjAUBgNVBAMT
# DU9NTklDLlRFQ0gtQ0ECExoAAAAIC4Z11vsOvFYAAAAAAAgwCQYFKw4DAhoFAKCB
# tDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYK
# KwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUhMvf4qhTgCjBJ+3gfboWrj6VxkMw
# VAYKKwYBBAGCNwIBDDFGMESgQoBAAE8AcAB0AGkAbQBpAHoAZQAtAE8AZgBmAGwA
# aQBuAGUAIABGAHUAbgBjAHQAaQBvAG4AIABNAG8AZAB1AGwAZTANBgkqhkiG9w0B
# AQEFAASCAQA9n+CaYono1YLuqtMcARXKbzJLR1YUN8fZNHiRnj0BdmquESJkXRlx
# yyARmUpmsDcXYXZX8uqVUGblNWuDj/uPheFP0dWAJenlO8pOBPLghYSIfRBl+gv2
# iYmtG8sdGo2tSSRo41Ro+6nDoAtmTIkwMAoKAOKI0zhFd2b4nSXb6ahFfiV+615D
# AaPRSx6do/58jne/LLcRiaYTwK02b47R9M6gh9FgN0v7g3uRVEU/g8L6hVgNtpPy
# Skx9OUoXfKvmWQD39wgXBcsW3Nepl4STZBocWoMJNxRtAqtcZY5QMdwkjLVjlMUt
# xL47QCKY5gKTAxEsAS+t13cFK3jU/9Uq
# SIG # End signature block
