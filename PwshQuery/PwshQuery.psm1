<#
.DESCRIPTION
    Imports the PwshQuery module
#>

# Source all of the private functions
$Private = @(Get-ChildItem -Path ([System.IO.Path]::Combine($PSScriptRoot, "Private", "*.ps1")))
foreach ($Import in $Private)
{
    . $Import.FullName
}

# Source all of the public functions
$Public = @(Get-ChildItem -Path ([System.IO.Path]::Combine($PSScriptRoot, "Public", "*.ps1")))
foreach ($Import in $Public)
{
    . $Import.FullName
}