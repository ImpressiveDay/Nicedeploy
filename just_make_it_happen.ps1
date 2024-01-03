# I believe in an easy life, to make other easy life, for happy-good life.
# We can all win
# '{0:d2}' -f 2 --- this is nice trick for leading zero on single digits as needed for looping part files..
# Usage: Just add CID argument

### Accept the CID as a string argument ex. "1313141414-ac"
$deployCID = $args[0]

### This is a dependency function to merge split files
function Join-File
{
  <#
      .SYNOPSIS
      Joins the parts created by Split-File and re-creates the original file
 
      .DESCRIPTION
      Use Split-File first to split a file into multiple part files with extension .part
      To join (recreate) the original file, specify the original file name (less the part number and the extension .part)
 
      .EXAMPLE
      Join-File -Path "C:\test.zip"
      Looks for the file c:\testzip.00.part and starts creating c:\test.zip from it. Once c:\test.zip.00.part is processed, it looks for more parts until
      no more parts are found.
 
      .EXAMPLE
      Join-File -Path "C:\test.zip" -DeletePartFiles
      Looks for the file c:\testzip.00.part and starts creating c:\test.zip from it. Once c:\test.zip.00.part is processed, it looks for more parts until
      no more parts are found.
      Once the original file c:\test.zip is recreated, all c:\test.zip.XXX.part files are deleted.
  #>


    
    param
    (
        # specify the path name of the original file (less incrementing number and less extension .part)
        [Parameter(Mandatory,HelpMessage='Path of original file')]
        [String]
        $Path,

        # when specified, delete part files after file has been created
        [Switch]
        $DeletePartFiles
    )

    try
    {
        # get the file parts
        $files = Get-ChildItem -Path "$Path.*.part" | 
        # sort by part
        Sort-Object -Property {
            # get the part number which is the "extension" of the
            # file name without extension
            $baseName = [IO.Path]::GetFileNameWithoutExtension($_.Name)
            $part = [IO.Path]::GetExtension($baseName)
            if ($part -ne $null -and $part -ne '')
            {
                $part = $part.Substring(1)
            }
            [int]$part
        }
        # append part content to file
        $writer = [IO.File]::OpenWrite($Path)
        $files |
        ForEach-Object {
            Write-Verbose -Message "processing $_..."
            $bytes = [IO.File]::ReadAllBytes($_)
            $writer.Write($bytes, 0, $bytes.Length)
        }
        $writer.Close()

        if ($DeletePartFiles)
        {
            Write-Verbose -Message "Deleting part files..."
            $files | Remove-Item
        }
    }
    catch
    {
        throw "Unable to join part files: $_"
    }
}

### This is the actual part which is downloading our files into a temporary directory
Set-Location $env:appdata
New-Item -Name "Nicedeploy" -ItemType "directory"
Set-Location .\Nicedeploy\
$ProgressPreference = 'SilentlyContinue' # Do not print display of progress for downloading, this significantly slows things down otherwise
0..13 | % {
$fileNum = '{0:d2}' -f ([int]$_)
write "File part $fileNum is downloading."
Invoke-WebRequest "https://raw.githubusercontent.com/ImpressiveDay/Nicedeploy/main/sensor.zip.$fileNum.part" -OutFile "sensor.zip.$fileNum.part"
write "File part $fileNum has finished downloading."
}

### Now simply merging parts together so we can extract installer.
write "Joining files together."
Join-File -Path "$env:appdata\Nicedeploy\sensor.zip"
Expand-Archive .\sensor.zip
Set-Location .\sensor\

### Now actually install the stuff
$Command = "$env:appdata\Nicedeploy\sensor\sensor.exe"
$Parms = "/install /quiet /norestart ProvNoWait=1 CID=$deployCID"
$Parms = $Parms.Split(" ")
& "$Command" $Parms
