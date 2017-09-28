<#SDS 2017-09-12 - Changed from ps1 to psm1.#>

function Convert-FileEncoding {

[CmdletBinding(
SupportsShouldProcess   =$true <#Enables -Confirm and -Whatif, for which you will want: If ($PSCmdlet.ShouldProcess("Message")) { BlockofCode } #>
)]

[OutputType('System.IO.FileSystemInfo')]
PARAM( 
[Parameter(
 Mandatory                         = $true
,ValueFromPipelineByPropertyName   = $true    <#Map parameters from inbound objects by property name#>
)][ValidateNotNullorEmpty()][ValidateScript({
              IF (Test-Path -PathType leaf -Path $_ ) 
                  {$True}
              ELSE {
                  Throw "$_ is not a file."
              } 
          })][Alias('Path')][String]$FullName
,[AvailableEncodings]$Encoding='UTF8'
,[Switch]$PassThru
) 
<#
.SYNOPSIS
Converts files to the given encoding.
.DESCRIPTION
SDS Modifications 2017-09-12 - I've removed the -Include parameter, enabled 
CmdletBinding with should process, allowed pipeline input to the file targeting
parameter (now FullName, not Path), and made the final summary verbose output, not 
normal output. This collectively makes the function more pipeline friendly 
and prevents unintended recursive re-encoding of your files.
.EXAMPLE
Get-ChildItem .\scripts -Include *.js -Recurse | Convert-FileEncoding -Encoding UTF8
.LINK https://gist.github.com/jpoehls/2406504
.LINK http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html
#>
BEGIN {}<#END Begin#>
PROCESS {
#region Echo parameters (https://stackoverflow.com/questions/21559724/getting-all-named-parameters-from-powershell-including-empty-and-set-ones)
Write-Verbose "Echoing parameters:"
$ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
foreach ($key in $ParameterList.keys)
{
    $var = Get-Variable -Name $key -ErrorAction SilentlyContinue;
    if($var)
    {
        Write-Verbose "$($var.name): $($var.value)"
    }
}
Write-Verbose "Parameters done."
#endregion Echo parameters

  $count = 0
  $list = Get-ChildItem -Path $FullName -File | select FullName, @{n='Encoding';e={$(Get-FileEncoding $_.FullName).Encoding}} | where {$_.Encoding -ne $Encoding}
  If ($PSCmdlet.ShouldProcess("Set encoding to $Encoding for: $($list | Select-Object -ExpandProperty FullName)")) {
    $list | ForEach-Object { 
        (Get-Content $_.FullName) | Out-File $_.FullName -Encoding $Encoding
        IF($PassThru.IsPresent) {Get-ChildItem $_.FullName}
        $count++
      }
  }<#End ShouldProcess#>
}<#End Process#>
END {
  Write-Verbose "$count file(s) converted to $Encoding."
}<#END END#>
}



function Get-FileEncoding {
<#
.SYNOPSIS
Gets file encoding.
.DESCRIPTION
The Get-FileEncoding function determines encoding by looking at Byte Order Mark (BOM).
Based on port of C# code from http://www.west-wind.com/Weblog/posts/197245.aspx
SDS Updates 2017-09-12
Simplified output by created objects with Fullname and Encoding attributes. Updated Example
to reflect this. Also reconfigured input parameter to pair well with Get-ChildItem.
.EXAMPLE
Get-ChildItem  *.ps1 | Get-FileEncoding | where {$_.Encoding -ne 'ASCII'}
This command gets ps1 files in current directory where encoding is not ASCII
.EXAMPLE
Get-ChildItem  *.ps1 | Get-FileEncoding | | where {$_.Encoding -ne 'ASCII'} | foreach {(get-content $_.FullName) | set-content $_.FullName -Encoding ASCII}
Same as previous example but fixes encoding using set-content
.LINK https://gist.github.com/jpoehls/2406504
.LINK http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html
 
# Modified by F.RICHARD August 2010
# add comment + more BOM
# http://unicode.org/faq/utf_bom.html
# http://en.wikipedia.org/wiki/Byte_order_mark
#
# Do this next line before or add function in Profile.ps1
# Import-Module .\Get-FileEncoding.ps1
#>
  [CmdletBinding()] 
  Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)][Alias('Path')]
    [string]$FullName
  )
PROCESS{
  [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $FullName
  Write-Verbose "First 4 bytes of $FullName : $($byte[0]) $($byte[1]) $($byte[2]) $($byte[3])"

  # EF BB BF (UTF8)
  if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
  { New-Object PSCustomObject -Property @{Encoding = 'UTF8';FullName = $FullName } }

  # FE FF  (UTF-16 Big-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
  { New-Object PSCustomObject -Property @{Encoding = 'Unicode UTF-16 Big-Endian';FullName = $FullName } }

  # FF FE  (UTF-16 Little-Endian)
  elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
  { New-Object PSCustomObject -Property @{Encoding = 'Unicode UTF-16 Little-Endian';FullName = $FullName } }

  # 00 00 FE FF (UTF32 Big-Endian)
  elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
  { New-Object PSCustomObject -Property @{Encoding = 'UTF32 Big-Endian';FullName = $FullName } }

  # FE FF 00 00 (UTF32 Little-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
  { New-Object PSCustomObject -Property @{Encoding = 'UTF32 Little-Endian';FullName = $FullName } }

  # 2B 2F 76 (38 | 38 | 2B | 2F)
  elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
  { New-Object PSCustomObject -Property @{Encoding = 'UTF7';FullName = $FullName } }

  # F7 64 4C (UTF-1)
  elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
  { New-Object PSCustomObject -Property @{Encoding = 'UTF-1';FullName = $FullName } }

  # DD 73 66 73 (UTF-EBCDIC)
  elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
  { New-Object PSCustomObject -Property @{Encoding = 'UTF-EBCDIC';FullName = $FullName } }

  # 0E FE FF (SCSU)
  elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
  { New-Object PSCustomObject -Property @{Encoding = 'SCSU';FullName = $FullName } }

  # FB EE 28  (BOCU-1)
  elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
  { New-Object PSCustomObject -Property @{Encoding = 'BOCU-1';FullName = $FullName } }

  # 84 31 95 33 (GB-18030)
  elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
  { New-Object PSCustomObject -Property @{Encoding = 'GB-18030';FullName = $FullName } }

  else
  { New-Object PSCustomObject -Property @{Encoding = 'ASCII';FullName = $FullName } }
}<#End Process#>
}


ENUM AvailableEncodings {
    Unknown            = 0
    String             = 1
    Unicode            = 2
    BigEndianUnicode   = 3
    UTF8               = 4
    UTF7               = 5
    UTF32              = 6
    ASCII              = 7
    Default            = 8
    OEM                = 9

}<#End Enum#>


Export-ModuleMember -Function "Convert-FileEncoding"
Export-ModuleMember -Function "Get-FileEncoding"