<#
.DESCRIPTION
    Description
.EXAMPLE
    FunctionName example usage here
#>
BeforeAll {
    $SampleJsonFilePath = [System.IO.Path]::Combine($PSScriptRoot, "sample.json")
    $SampleJsonText = @"
{
    "root": {
        "leaf": "leafValue",
        "array": [
            {
                "arrayLeaf": "arrayLeafValue",
                "property": "value"
            },
            {
                "arrayInt": 100,
                "property": "anotherValue"
            }
        ]
    }
}
"@

    # Create a sample JSON file
    New-Item -Path $SampleJsonFilePath -ItemType "File" -Value $SampleJsonText -Force
    $SampleJsonObject = Get-Content $SampleJsonFilePath | ConvertFrom-Json

    # Import module
    Import-Module ([System.IO.Path]::Combine($PSScriptRoot, "..", "PsJsonQuery.psd1"))
}

# AfterAll {
#     Remove-Item -Path $SampleJsonFilePath -Force
# }

Describe "New-PsJsonQuery" {
    It "Can create a PsJsonQuery object from JSON file with default settings" {
        $Pq = New-PsJsonQuery -JsonFilePath $SampleJsonFilePath

        $Pq | Should -Not -BeNullOrEmpty
        $Pq | Should -BeOfType PsJsonQuery
        $Pq.IgnoreError | Should -BeFalse
        $Pq.IgnoreOutput | Should -BeFalse
    }

    It "Can create a PsJsonQuery object from a JSON object with default settings" {
        $Pq = New-PsJsonQuery -JsonObject $SampleJsonObject

        $Pq | Should -Not -BeNullOrEmpty
        $Pq | Should -BeOfType PsJsonQuery
        $Pq.IgnoreError | Should -BeFalse
        $Pq.IgnoreOutput | Should -BeFalse
    }

    It "Can create a PsJsonQuery object with IgnoreError set to true" {
        $Pq = New-PsJsonQuery -JsonFilePath $SampleJsonFilePath -IgnoreError

        $Pq.IgnoreError | Should -BeTrue
        $Pq.IgnoreOutput | Should -BeFalse
    }

    It "Can create a PsJsonQuery object with IgnoreOutput set to true" {
        $Pq = New-PsJsonQuery -JsonFilePath $SampleJsonFilePath -IgnoreOutput

        $Pq.IgnoreError | Should -BeFalse
        $Pq.IgnoreOutput | Should -BeTrue
    }

    It "Can create a PsJsonQuery object with IgnoreError and IgnoreOutput set to true" {
        $Pq = New-PsJsonQuery -JsonFilePath $SampleJsonFilePath -IgnoreError -IgnoreOutput

        $Pq.IgnoreError | Should -BeTrue
        $Pq.IgnoreOutput | Should -BeTrue
    }
}

Describe "PsJsonQuery" {
    BeforeAll {
        $Pq = New-PsJsonQuery -JsonFilePath $SampleJsonFilePath
    }

    It "Can query a specific setting" {
        $Query = ".root.leaf"
        $ActualValue = Invoke-Expression "`$SampleJsonObject$Query" | ConvertTo-Json

        $Pq.Query($Query) | Should -Be $ActualValue
    }

    It "Can query a JSON object" {
        $Query = ".root.array"
        $ActualValue = Invoke-Expression "`$SampleJsonObject$Query" | ConvertTo-Json

        $Pq.Query($Query) | Should -Be $ActualValue

        $Query = ".root.array[]"
        $Pq.Query($Query) | Should -Be $ActualValue
    }

    It "Can query an array element" {
        $Query = ".root.array[0]"
        $ActualValue = Invoke-Expression "`$SampleJsonObject$Query" | ConvertTo-Json

        $Pq.Query($Query) | Should -Be $ActualValue
    }

    It "Can query an array element properties" {
        $Query = ".root.array.property"
        $ActualValue = Invoke-Expression "`$SampleJsonObject$Query" | ConvertTo-Json

        $Pq.Query($Query) | Should -Be $ActualValue

        $Query = ".root.array[].property"
        $Pq.Query($Query) | Should -Be $ActualValue
    }

    It "Throws on an invalid query" {
        $Query = ".invalid.query"

        $Caught = $false
        try
        {
            $output = $Pq.Query($Query)
            Write-Host "out: $output"
        }
        catch
        {
            $Caught = $true
        }

        $Caught | Should -BeTrue
    }

    It "Can obtain the paths to all leaf nodes" {
        $PathsHashtable = $Pq.Paths()

        $PathsHashtable[".root.leaf"] | Should -Be "leafValue"
        $PathsHashtable[".root.array[0].arrayLeaf"] | Should -Be "arrayLeafValue"
        $PathsHashtable[".root.array[0].property"] | Should -Be "value"
        $PathsHashtable[".root.array[1].arrayInt"] | Should -Be 100
        $PathsHashtable[".root.array[1].property"] | Should -Be "anotherValue"
    }

    It "Can obtain all paths to a single value" {
        $Value = "arrayLeafValue"
        $Paths = $Pq.GetPathsToValue($Value)

        $Paths.Count | Should -Be 1
        $Paths[0] | Should -Be ".root.array[0].arrayLeaf"
    }
}