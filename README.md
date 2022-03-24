# PowerJson

The PowerJson class can be used when working on a system that does not support jq for windows, but jq support is necessary or helpful.
This class functions similarly to jq for windows, but with a few differences:

- PowerJson typically has 2 space tabs instead of 4. This is why output is usually saved in a different file from the input file.
- Changes made using `SetPath()` can be seen immediately if calling a PowerJson function, but will not be outputted to a file until
  a `Save()` call is completed.
- Square brackets "[]" are optional in a query returning an array (i.e. `.json.query.array[].property`) can also be `.json.query.array.property`.
- Queries output in JSON format, so `ConvertFrom-Json` should be used before doing any object manipulation after a query.

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

Instantiate PowerJson object:

```PowerShell
$PJson = [PowerJson]::new("example.json")
# or
$Object = Get-Content "example.json" | ConvertFrom-Json
$PJson = [PowerJson]::new($Object)
```

Obtain a specific setting:

```PowerShell
$PJson.Query(".root.leaf")
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
$PJson.Query($Query)
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
$PJson.Query(".root.array[0]")
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
$Element = $PJson.Query($Query) | ConvertFrom-Json | Where-Object -Property property -EQ "value"
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
$property = $PJson.Query($Query) | ConvertFrom-Json | Where-Object -Property property -EQ "value" | ConvertTo-Json -Depth 99
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
$Property = $Jq.Query($Query)
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
$PathsHashtable = $PJson.Paths()
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
$PJson.SetPath(".root.leaf", 999)
$PJson.Save("file.modified.json")
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
$Paths = $Jq.GetPathsToValue("arrayLeafValue")
```

**Returns**:

```PowerShell
$Paths[0] = ".root.array[0].arrayLeaf"
```
