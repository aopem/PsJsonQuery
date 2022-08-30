# PsJsonQuery

![pester-unit-tests](https://github.com/aopem/PsJsonQuery/actions/workflows/pester-unit-tests.yml/badge.svg)

PsJsonQuery is a PowerShell native JSON query class that can be used to simplify working with JSON in PowerShell. The `ConvertFrom-Json` cmdlet makes some operations difficult by returning JSON as an object type. As a result, PsJsonQuery was created to help in situations where simply using the JSON object returned by `ConvertFrom-Json` can be difficult. Additionally, this class is especially useful when working in an environment where jq is inaccessible, but PowerShell is not. PsJsonQuery functions similarly to jq, but with a few differences:

- Queries follow the same basic format as [jq filters](https://stedolan.github.io/jq/manual/#Basicfilters).
- PsJsonQuery typically has 2 space tabs instead of 4. This is why output is usually saved in a different file from the input file.
- Any changes made using PsJsonQuery can be seen immediately if calling a PsJsonQuery method, but will not be outputted to a file until a `Save()` call is completed.
- Square brackets "[]" are optional in a query returning an array (i.e. `.json.query.array[].property` can also be `.json.query.array.property`).
- Queries output in JSON format, so `ConvertFrom-Json` should be used before doing any object manipulation after a query.

## Setup

```PowerShell
Install-Module PsJsonQuery
Import-Module PsJsonQuery
$Pq = New-PsJsonQuery -JsonFilePath "example.json"
```

## Run Tests with Pester

To test with Pester, from the repository root run:

```PowerShell
Invoke-Pester
```

## Example Usage Cases

Using sample JSON for `example.json`:

```json
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
```

Instantiate PsJsonQuery object:

```PowerShell
$Pq = [PsJsonQuery]::new("example.json")
# or
$Object = Get-Content "example.json" | ConvertFrom-Json
$Pq = [PsJsonQuery]::new($Object)
```

Instantiate PsJsonQuery object with `New-PsJsonQuery`:

```PowerShell
$Pq = New-PsJsonQuery -JsonFilePath "example.json"
# or
$Object = Get-Content "example.json" | ConvertFrom-Json
$Pq = New-PsJsonQuery -JsonFileObject $Object
```

Obtain a specific setting:

```PowerShell
$Pq.Query(".root.leaf")
```

**Returns**:

```json
"leafValue"
```

Obtain a JSON object:

```PowerShell
$Query = ".root.array"
# or
$Query = ".root.array[]"
$Pq.Query($Query)
```

**Returns**:

```json
{
    [
        {
            "arrayLeaf": "arrayLeafValue",
            "property": "value"
        },
        {
            "arrayInt": 100
        }
    ]
}
```

Obtain an array element:

```PowerShell
$Pq.Query(".root.array[0]")
```

**Returns**:

```json
{
    "arrayLeaf": "arrayLeafValue",
    "property": "value"
}
```

Obtain an array element by property value (as an object):

```PowerShell
$Query = ".root.array"
# or
$Query = ".root.array[]"
$Element = $Pq.Query($Query) | ConvertFrom-Json | Where-Object -Property property -EQ "value"
```

**Returns**:

```PowerShell
$ArrayLeaf = $Element.arrayLeaf
$Property = $Element.property
```

Obtain an array element by property value (as JSON):

```PowerShell
$Query = ".root.array"
# or
$Query = ".root.array[]"
$property = $Pq.Query($Query) | ConvertFrom-Json | Where-Object -Property property -EQ "value" | ConvertTo-Json -Depth 99
```

**Returns**:

```json
{
    "arrayLeaf": "arrayLeafValue",
    "property": "value"
}
```

Filter array elements by property:

```PowerShell
$Query = ".root.array.property"
# or
$Query = ".root.array[].property"
$Property = $Pq.Query($Query)
```

**Returns**:

```json
[
    "value",
    "anotherValue"
]
```

Obtain paths to all leaf nodes, value of each leaf node in a hashtable:

```PowerShell
$PathsHashtable = $Pq.Paths()
```

**Returns** hashtable in the following key, value format:

```PowerShell
$PathsHashtable[".root.leaf"] = "leafValue"
$PathsHashtable[".root.array[0].arrayLeaf"] = "arrayLeafValue"
$PathsHashtable[".root.array[0].property"] = "value"
$PathsHashtable[".root.array[1].arrayInt"] = 100
$PathsHashtable[".root.array[1].property"] = "anotherValue"
```

Change the value of a path, then get updated JSON:

```PowerShell
$Pq.SetPath(".root.leaf", 999)
$Pq.Save("file.modified.json")
```

**Returns**:

```json
{
    "root": {
        "leaf": 999,
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
```

Obtain all paths to a value:

```PowerShell
$Paths = $Pq.GetPathsToValue("arrayLeafValue")
```

**Returns**:

```PowerShell
$Paths[0] = ".root.array[0].arrayLeaf"
```
