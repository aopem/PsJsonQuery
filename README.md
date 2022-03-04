# PowerJson

The PowerJson class can be used when working on a system that does not support jq for windows, but jq support is necessary or helpful.
This class functions similarly to jq for windows, but with a few differences:

- Requires PowerShell 7+ because it uses `ConvertFrom-Json -AsHashtable`.
- PowerJson uses an unordered hashtable, so output JSON from `Save()` is usually **NOT** in the same format as input JSON. This is why output is usually saved
  in a different file.
- Changes made using `SetPath()` can be seen immediately if calling the `Paths()` function, but will not be outputted to a file until
  a `Save()` call is completed.
- Square brackets "[]" are optional in queries involving arrays or array elements.
- Cannot currently perform queries similar to `.json.query.array[].property` to get a list of all "property" values in "array".
  Instead must use something like `$PJson.Query(.json.query.array[]) | ConvertFrom-Json | Select-Object -Property property`.
- Queries output in JSON format, so `ConvertFrom-Json` should be used before doing any object manipulation.

##### Example Usage Cases

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
                "arrayInt": 100
            }
        ]
    }
}
```

Instantiate PowerJson object:

```PowerShell
$PJson = [PowerJson]::new("example.json")
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
$Query = ".root.array[0]"
# or
$Query = ".root.array.0"
$PJson.Query($Query)
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

Obtain paths to all leaf nodes, value of each leaf node in a hashtable:

```PowerShell
$PathsHashtable = $PJson.Paths()
```

**Returns** hashtable in the following key, value format:

```PowerShell
$PathsHashtable[".root.leaf"] = "leafValue"
$PathsHashtable[".root.array.0.arrayLeaf"] = "arrayLeafValue"
$PathsHashtable[".root.array.0.property"] = "value"
$PathsHashtable[".root.array.1.arrayInt"] = 100
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
                "arrayInt": 100
            }
        ]
    }
}
```