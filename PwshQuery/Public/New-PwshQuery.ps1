Using module "../Private/PwshQuery.ps1"

function New-PwshQuery
{
    <#
    .DESCRIPTION
        Returns a new PwshQuery object.
    .PARAMETER JsonFilePath
        JSON file to construct a new PwshQuery object with.
    .PARAMETER JsonObject
        JSON object to construct PwshQuery object with. This can be obtained from
        a JSON file by using something like:
            $JsonObject = Get-Content "example.json" | ConvertFrom-Json
    .Parameter IgnoreError
        (switch) Set if errors from PwshQuery object returned should be ignored.
        Can also set $Pq.IgnoreError property to $true or $false to edit.
    .Parameter IgnoreOutput
        (switch) Set if output from PwshQuery object returned should be ignored.
        Can also set $Pq.IgnoreOutput property to $true or $false to edit.
    .EXAMPLE
        Using a JSON file:
        $Pq = New-PwshQuery -JsonFilePath "example.json"

        Using a JSON object:
        $JsonObject = Get-Content "example.json" | ConvertFrom-Json
        $Pq = New-PwshQuery -JsonObject $JsonObject

        Other:
        $Pq = New-PwshQuery -JsonFilePath "example.json" -IgnoreError -IgnoreOutput
    #>

    param
    (
        [Parameter(Mandatory=$true, ParameterSetName="File")]
        [string]$JsonFilePath,

        [Parameter(Mandatory=$true, ParameterSetName="Object")]
        [object]$JsonObject,

        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [Parameter(Mandatory=$false, ParameterSetName="Object")]
        [switch]$IgnoreError,

        [Parameter(Mandatory=$false, ParameterSetName="File")]
        [Parameter(Mandatory=$false, ParameterSetName="Object")]
        [switch]$IgnoreOutput
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        "File" { $Pq = [PwshQuery]::new($JsonFilePath) }
        "Object" { $Pq = [PwshQuery]::new($JsonObject) }
        default { throw [System.ArgumentException]::new("Invalid argument") }
    }

    if ($IgnoreError)
    {
        $Pq.IgnoreError = $true
    }

    if ($IgnoreOutput)
    {
        $Pq.IgnoreOutput = $true
    }

    return $Pq
}