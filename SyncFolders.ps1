<#
.SYNOPSIS
    Syncronizes folders content in source and destination locations.
.DESCRIPTION
    Syncronizes folders content in source and destination locations.
    If the file from source has been deleted, that file alse will be deleted from destination.
    The script performs an incremental copy. If the files and folders in the destination location already exist,
    the script checks the last write time in source and if the file is updated that file trasfers to destination location.
.PARAMETER sourcePath
    Path to the local folder or the network share that will be copied.
.PARAMETER destinationPath
    Path to the local folder or the network share where the source content will be copied.
.PARAMETER excluded_files
    File names that will be excluded from copying.
.EXAMPLE
    PS C:\Scripts\> .\SyncFolders.ps1 -sourcePath D:\src -destinationPath \\destination_location\share -excluded_files "excluded_file1.txt", "excluded_file2.txt"
    This example copies files and folders from the D:\src location to the \\destination_location\share.
.NOTES
    Author: Manuk Manukyan
    Date:   Dec 21, 2018
#>

[CmdletBinding()]
Param(
   #Source directory
   [Parameter(Mandatory=$true,Position=0, HelpMessage="Source directory local or network. Example: `"C:\Source`" or `"\\networklocation\share1`"")]
   [string]$sourcePath,

   #Destination directory
   [Parameter(Mandatory=$true,Position=1, HelpMessage="Destination directory local or network. Example: `"C:\Destination`" or `"\\networklocation\share1`"")]
   [string]$destinationPath,

   #Excluded files
   [parameter(Mandatory=$true, position=1, HelpMessage="Files that must be excluded from copying. Example: `"excludedfile1.txt`", `"excludedfile2.txt`"")]
   [String[]]$excluded_files
)

$root_srcContent = Get-ChildItem -Path $sourcePath -Recurse

#Function removes all files from the destination folder if they have been deleted from the source.
Function PurgeDir($srcDir, $dstDir) {
    $srcDirContent = Get-ChildItem -Path $srcDir
    $dstDirContent = Get-ChildItem -Path $dstDir

    if($null -eq $srcDirContent) { #Empty destination folder if source is empty
        $dstDirContent | ForEach-Object { $_.Delete() }
        continue
    }

    #Getting differences between folders
    $FileDiffs = Compare-Object -ReferenceObject $srcDirContent -DifferenceObject $dstDirContent

    $FileDiffs | ForEach-Object {
        if($_.SideIndicator -eq "=>") { #remove file if it is only in destination folder
            Remove-Item -Path $_.InputObject.FullName
        }
    }
}

foreach($item in $root_srcContent) {
    if($excluded_files.Contains($item.Name)) { continue } #Exclude files with names given in excluded_files array

    if (!($item -is [System.IO.DirectoryInfo])) {

        [System.IO.FileInfo]$dstItem = $item.FullName.Replace($sourcePath, $destinationPath)

        if( $dstItem.Exists ) {
            if($item.LastWriteTime -gt $dstItem.LastWriteTime) { #checking existing files LastWriteTime attribute
                try {
                    Copy-Item $item.FullName -Destination $dstItem
                    Write-Output $item "is transfered to $($dstItem.Directory.FullName)"
                }
                catch { Write-Output $_.Exception.Message }
            }
        }
        else { #Copying not existing files
            try {
                Copy-Item $item.FullName -Destination $dstItem -Recurse -Force -Container
                Write-Output $item "is transfered to $($dstItem.Directory.FullName)"
            }
            catch { Write-Output $_.Exception.Message }
        }
    }
    else { #Creating non existing Directories
        [System.IO.DirectoryInfo]$dstItem = $item.FullName.Replace($sourcePath, $destinationPath)
        if(!$dstItem.Exists)
        { $dstItem.Create() }
    }
}

#Purging root destination directory
PurgeDir $sourcePath $destinationPath

#Purging root destination directory subfolders
$srcDirs = Get-ChildItem -Path $sourcePath -Recurse | Where-Object { $_.PSIsContainer }

foreach($srcDir in $srcDirs) {
    [System.IO.DirectoryInfo]$dstDir = $srcDir.FullName.Replace($sourcePath, $destinationPath)
    PurgeDir $srcDir.FullName $dstDir.FullName
}