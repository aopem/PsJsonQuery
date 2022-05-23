<#
.DESCRIPTION
    Imports the PwshQuery module
#>

# Source all of the public functions for export
$PublicFunctions = Get-ChildItem -Path ([System.IO.Path]::Combine($PSScriptRoot, "Public", "*.ps1"))
foreach ($Function in $PublicFunctions)
{
    . $Function.FullName
}