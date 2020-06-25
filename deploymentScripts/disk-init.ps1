### -----------------------------------------------------------------------------------------------
### <script name=disk-init>
### <summary>
### This script helps initialize all the disks within a VM.
### </summary>
###
### <param name="partitionStyle">Optional parameter defining the partition style.</param>
### -----------------------------------------------------------------------------------------------

#Region Parameters

[CmdletBinding()]
param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Partition style.")]
    [ValidateNotNullorEmpty()]
    [ValidateSet(
        "GPT",
        "MBR")]
    [string] $partitionStyle = "GPT")
#EndRegion

### <summary>
### Initializes all the uninitialized disks.
### </summary>
### <param name="partitionStyle">Partition style.</param>
function Invoke-DiskInitialization([string] $partitionStyle)
{
    $disks = Get-Disk | Where-Object { $_.PartitionStyle -like "raw"}
    $initializedDisks = $disks | Initialize-Disk -PartitionStyle $partitionStyle -PassThru

    foreach($disk in $initializedDisks)
    {
        New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $disk.Number
        $partition = Get-Partition -DiskNumber $disk.Number
        Format-Volume -Confirm:$false -FileSystem NTFS -DriveLetter $partition.DriveLetter
    }
}

Invoke-DiskInitialization -PartitionStyle $partitionStyle