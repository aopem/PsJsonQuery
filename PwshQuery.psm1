class PwshQuery
{
    <#
    .DESCRIPTION
        Mimic jq functionality natively with PowerShell for instances when jq cannot be used.
        Supports basic jq queries in the same format as a normal jq query (ex: ".field1.field2.field3").
        When querying for array elements, square brackets are required. Queries should use
        ".array.query[0]" format.
    .EXAMPLE
        # executing queries on an example.json
        $Pq = [PwshQuery]::new("example.json")
        $Array = $Pq.Query(".root.array[1]")
        $LeafNode = $Pq.Query(".root.leafNode")

        # get hashtable of leaf node paths (hashtable keys) and their values (hashtable values)
        $PathsHashtable = $Pq.Paths()

        # set a path and then save change to an output file called "example.modified.json"
        # the path being set must already exist in example.json for success
        $Pq.SetPath(".my.path.here", "newValue")
        $Pq.Save("example.modified.json")
    .NOTES
        JSON is output in a different order than the input, which is why save typically
        uses a different output file from the same input file.

        Errors from functions can be ignored by setting $Pq.IgnoreError = $true.
        Error/warning message output can be ignored by setting $Pq.IgnoreOutput = $true.
    #>

    [bool] $IgnoreError = $false
    [bool] $IgnoreOutput = $false
    [hashtable] hidden $JsonObject = $null
    [hashtable] hidden $PathsHashtable = $null

    PwshQuery([string]$JsonFilePath)
    {
        if (-not (Test-Path $JsonFilePath))
        {
            throw "Error: $JsonFilePath is not a valid file path"
        }

        $this.JsonObject = Get-Content $JsonFilePath | ConvertFrom-Json
    }

    PwshQuery([object]$JsonObject)
    {
        if ($null -eq $JsonObject)
        {
            throw "Error: JSON object passed is null"
        }

        $this.JsonObject = $JsonObject
    }

    [string] Query([string]$QueryPath)
    {
        <#
        .DESCRIPTION
            Returns JSON result of a query. Queries should be in the same format as a
            typical jq query, ex: ".field1.field2.field3". When accessing an array element
            directly, use [$index], such as in the example. Additionally, arrays can be filtered
            using a property in a query like ".root.array[].property" or ".root.array.property"
            - this is the only case when square brackets ([]) are optional.
        .PARAMETER QueryPath
            Path to query in same format as a typical jq query (".field1.field2.field3")
        .EXAMPLE
            $ArrayJSON = $Pq.Query(".root.array[0]")
        #>

        $PropertyPath = $this.ParseQueryPath($QueryPath)

        $Value = ""
        try
        {
            $Value = Invoke-Expression "`$this.JsonObject$PropertyPath"
        }
        catch
        {
            $ErrorMessage = "Cannot query $QueryPath when it does not already exist in the provided JSON"

            if (-not $this.IgnoreOutput)
            {
                Write-Verbose -Verbose $ErrorMessage
            }

            if (-not $this.IgnoreError)
            {
                throw $ErrorMessage
            }
        }
        return $Value | ConvertTo-Json -Depth 99
    }

    [void] SetPath([string]$QueryPath, $Value)
    {
        <#
        .DESCRIPTION
            Sets the value of $QueryPath to $Value. The Query path should be in same
            format as described for Query(). To see changes, must call Save() function to
            write output to a file, otherwise they will only be present in $this.JsonObject.
        .PARAMETER QueryPath
            Path to query in same format as a typical jq query format (".field1.field2.field3")
        .PARAMETER Value
            Value to set $QueryPath to
        .EXAMPLE
            $Pq.SetPath(".root.array[0].faultDomains", 0)
            $Pq.Save("example.modified.json")
        #>

        # add quotes if string
        if ($Value -is [string])
        {
            $Value = '"' + $Value + '"'
        }
        $PropertyPath = $this.ParseQueryPath($QueryPath)

        try
        {
            Invoke-Expression "`$this.JsonObject$PropertyPath = $Value"
        }
        catch
        {
            $ErrorMessage = "Cannot set $QueryPath when it does not already exist in the provided JSON"

            if (-not $this.IgnoreOutput)
            {
                Write-Verbose -Verbose $ErrorMessage
            }

            if (-not $this.IgnoreError)
            {
                throw $ErrorMessage
            }
        }
    }

    [hashtable] Paths()
    {
        <#
        .DESCRIPTION
            Returns a hashtable containing paths to leaf nodes as keys and the value at that leaf
            node as the value for that corresponding key. For example, using the following JSON:
            {
                "root": {
                    "leafnode0": "myValue",
                    "leafnode1": 0
                }
            }
            this hashtable would contain the following key/value pairs:
            $this.PathsHashtable[".root.leafnode0"] = "myValue"
            $this.PathsHashtable["".root.leafnode1"] = 0
        .EXAMPLE
            # add 1 to all integer values in hashtable
            $PathsHashtable = $Pq.Paths()
            foreach ($Path in $PathsHashtable.Keys)
            {
                if ($PathsHashtable[$Path] -is [int])
                {
                    $PathsHashtable[$Path]++
                }
            }
        #>

        $this.PathsHashtable = @{}
        $this.PathsHelper($this.JsonObject, "")
        return $this.PathsHashtable
    }

    [Collections.Generic.List[string]] GetPathsToValue($Value)
    {
        <#
        .DESCRIPTION
            Returns a list of all paths to the given value. The value provided must be a leaf
            node of the JSON. Paths to keys will throw an error or give an incorrect result.
        .PARAMETER Value
            Value to obtain the paths to
        .EXAMPLE
            $Paths = $Jq.GetPathsToValue("myValue")
        #>

        # fill out $this.PathsHashtable
        $this.Paths()

        $MatchedPaths = [Collections.Generic.List[string]]::new()
        foreach ($Item in $this.PathsHashtable.GetEnumerator())
        {
            if (($null -eq $Item.Value) -or ($null -eq $Value))
            {
                if ($Item.Value -eq $Value)
                {
                    $MatchedPaths.Add($Item.Name)
                }
                continue
            }

            # value is a match if $Item.Value is equal AND of the same type
            if (($Item.Value.GetType().Name -eq $Value.GetType().Name) -and ($Item.Value -eq $Value))
            {
                $MatchedPaths.Add($Item.Name)
            }
        }

        if ($MatchedPaths.Count -eq 0)
        {
            $ErrorMessage = "Could not find a path to value: $Value in the provided JSON"

            if (-not $this.IgnoreOutput)
            {
                Write-Verbose -Verbose $ErrorMessage
            }

            if (-not $this.IgnoreError)
            {
                throw $ErrorMessage
            }
        }

        return $MatchedPaths
    }

    [void] Save([string]$OutputFilePath)
    {
        <#
        .DESCRIPTION
            Saves the contents of $this.JsonObject to a $OutputFilePath
        .PARAMETER OutputFilePath
            Path to output $this.JsonObject as JSON to
        .EXAMPLE
            $Pq.SetPath(".root.array[0].property", 0)
            $Pq.Save("example.modified.json")
        .NOTES
            $this.JsonObject is unordered so the output will contain all the same inputs/any updates
            that have been made using SetPath() or manually, but will be formatted differently. So, while
            the output file will look different, the contained information is not.
        #>

        $this.JsonObject | ConvertTo-Json -Depth 99 | Out-File -FilePath $OutputFilePath -Encoding "ASCII"
    }

    [void] hidden PathsHelper($JsonObject, [string]$Path)
    {
        <#
        .DESCRIPTION
            Performs a recursive depth-first search of $JsonObject to obtain all leaf nodes and their paths.
            Essentially looks at each NoteProperty in the $JsonObject passed to the function. If the object
            does not contain any note properties, then it is a leaf and is added to $this.PathsHashtable
            in the format described in Paths(). [System.Object[]] is a special case, because these arrays
            must be processed using their indices instead of properties and may potentially contain more
            objects with note properties. Their elements are all inspected recursively for note properties
            until leaf nodes are reached.

            The Path to each key is constructed with each function call by adding the key every time in
            "Path.Key" format and appending the index ("$Path[$index]") when necessary.
        .PARAMETER JsonObject
            JSON object that is being traversed to find paths to leaf nodes, leaf node values
        .PARAMETER Path
            Path that is appended to with each call of this function. Starts as ""
        #>

        # in case an object has a null value, which would fail
        # the operation to obtain the $NoteProperties
        if ($null -eq $JsonObject)
        {
            $this.PathsHashtable[$Path] = $JsonObject
            return
        }

        $NoteProperties = $JsonObject | Get-Member -MemberType NoteProperty | Select-Object -Property Name

        # if no note properties, add to hashtable and return since this is a leaf node
        if ($null -eq $NoteProperties)
        {
            $this.PathsHashtable[$Path] = $JsonObject
            return
        }

        foreach ($Property in $NoteProperties)
        {
            $Name = $Property.Name
            $Value = $JsonObject.$Name

            # inspect recursively
            # if array, process path using proper indexing
            if ($Value -is [System.Object[]])
            {
                for ($i = 0; $i -lt $Value.Length; $i++)
                {
                    $this.PathsHelper($Value[$i], "$Path.$Name[$i]")
                }
            }
            else
            {
                $this.PathsHelper($Value, "$Path.$Name")
            }
        }
    }

    [string] hidden ParseQueryPath([string]$QueryPath)
    {
        <#
        .DESCRIPTION
            Remove any instances of [], and otherwise use $QueryPath to directly to access
            hashtable elements.
        .PARAMETER QueryPath
            Path to parse for key values
        #>

        if (-not $QueryPath.StartsWith("."))
        {
            throw "Query `"$QueryPath`" must start with a `".`""
        }
        elseif ($QueryPath -eq ".")
        {
            return ""
        }
        else
        {
            return $QueryPath.Replace("[]", "")
        }
    }
}