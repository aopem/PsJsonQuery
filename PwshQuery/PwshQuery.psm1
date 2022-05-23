<#
.DESCRIPTION
    Imports the PwshQuery module
#>

# Source all of the public functions for export
$PublicFunctions = [System.IO.Path]::Combine($PSScriptRoot, "Public", "*.ps1")
foreach ($Function in $PublicFunctions)
{
    . $Function.FullName
}