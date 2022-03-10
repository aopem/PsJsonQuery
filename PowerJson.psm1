class PowerJson
{
    <#
    .DESCRIPTION
        Mimic jq functionality natively with PowerShell for instances when jq cannot be used.
        Supports basic jq queries in the same format as a normal jq query (ex: ".field1.field2.field3").
        When querying for array elements, square brackets are required. Queries should use
        ".array.query[0]" format.
    .EXAMPLE
        # executing queries on an example.json
        $PJson = [PowerJson]::new("example.json")
        $Array = $PJson.Query(".root.array[1]")
        $LeafNode = $PJson.Query(".root.leafNode")

        # get hashtable of leaf node paths (hashtable keys) and their values (hashtable values)
        $PathsHashtable = $PJson.Paths()

        # set a path and then save change to an output file called "example.modified.json"
        # the path being set must already exist in example.json for success
        $PJson.SetPath(".my.path.here", "newValue")
        $PJson.Save("example.modified.json")
    .NOTES
        JSON is output in a different order than the input, which is why save typically
        uses a different output file from the same input file.

        Warnings from functions can be surpressed by setting $PJson.SupressWarning = $true.
    #>

    [bool] $SuppressWarning = $false
    [string] hidden $JsonFilePath = [string]::Empty
    [hashtable] hidden $JsonHashtable = $null
    [hashtable] hidden $PathsHashtable = $null

    PowerJson([string]$JsonFilePath)
    {
        if ($global:PSVersionTable.PSVersion.Major -lt 7)
        {
            throw "Error: PowerJson only works with PowerShell 7 and above"
            # ConvertFrom-Json -AsHashtable switch argument is reason this is not
            # compatible with versions < 7. This can be bypassed if a method is
            # implemented in PowerShell 5, etc. to emulate -AsHashtable argument's
            # functionality
        }
        $this.JsonFilePath = $JsonFilePath
        $this.JsonHashtable = Get-Content $JsonFilePath | ConvertFrom-Json -AsHashtable
    }

    [string] Query([string]$QueryPath)
    {
        <#
        .DESCRIPTION
            Returns JSON result of a query. Queries should be in the same format as a
            typical jq query, ex: ".field1.field2.field3". When accessing an array element
            directly, use [$index], such as in the example. Additionally, arrays can be filtered
            using a property in a query like ".cloudType.AzureCloud.Prod.environments[].environment"
            or ".cloudType.AzureCloud.Prod.environments.environment" - this is the only
            case when square brackets ([]) are optional.
        .PARAMETER QueryPath
            Path to query in same format as a typical jq query format (".field1.field2.field3")
        .EXAMPLE
            $EnvironmentJSON = $PJson.Query(".root.array[0]")
        #>

        $PropertyPath = $this.ParseQueryPath($QueryPath)

        $Value = ""
        try
        {
            $Value = Invoke-Expression "`$this.JsonHashtable$PropertyPath"
        }
        catch
        {
            if (-not $this.SuppressWarning)
            {
                Write-Verbose -Verbose "Cannot query $QueryPath when it does not already exist in `"$($this.JsonFilePath)`""
            }
        }
        return $Value | ConvertTo-Json -Depth 99
    }

    [bool] SetPath([string]$QueryPath, $Value)
    {
        <#
        .DESCRIPTION
            Sets the value of $QueryPath to $Value. The Query path should be in same
            format as described for Query(). To see changes, must call Save() function to
            write output to a file, otherwise they will only be present in $this.JsonHashtable.
        .PARAMETER QueryPath
            Path to query in same format as a typical jq query format (".field1.field2.field3")
        .PARAMETER Value
            Value to set $QueryPath to
        .EXAMPLE
            $Success = $PJson.SetPath(".root.array[0].faultDomains", 0)
            if ($Success)
            {
                $PJson.Save("example.modified.json")
            }
        #>

        # add quotes if string
        if ($Value -is [string])
        {
            $Value = '"' + $Value + '"'
        }
        $PropertyPath = $this.ParseQueryPath($QueryPath)

        try
        {
            Invoke-Expression "`$this.JsonHashtable$PropertyPath = $Value"
        }
        catch
        {
            if (-not $this.SuppressWarning)
            {
                Write-Verbose -Verbose "Cannot set $QueryPath when it does not already exist in `"$($this.JsonFilePath)`""
            }
            return $false
        }
        return $true
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
            $PathsHashtable = $PJson.Paths()
            foreach ($Path in $PathsHashtable.Keys)
            {
                if ($PathsHashtable[$Path] -is [int])
                {
                    $PathsHashtable[$Path]++
                }
            }
        #>

        $this.PathsHashtable = @{}
        $this.PathsHelper($this.JsonHashtable, "")
        return $this.PathsHashtable
    }

    [void] Save([string]$OutputFilePath)
    {
        <#
        .DESCRIPTION
            Saves the contents of $this.JsonHashtable to a $OutputFilePath
        .PARAMETER OutputFilePath
            Path to output $this.JsonHashtable as JSON to
        .EXAMPLE
            $Success = $PJson.SetPath(".root.array[0].property", 0)
            if ($Success)
            {
                $PJson.Save("example.modified.json")
            }
        .NOTES
            $this.JsonHashtable is unordered so the output will contain all the same inputs/any updates
            that have been made using SetPath() or manually, but will be formatted differently. So, while
            the output file will look different, the contained information is not.
        #>

        $this.JsonHashtable | ConvertTo-Json -Depth 99 | Out-File -FilePath $OutputFilePath -Encoding "ASCII"
    }

    [void] hidden PathsHelper([hashtable]$JsonHashtable, [string]$Path)
    {
        <#
        .DESCRIPTION
            Performs a recursive depth-first search of $JsonHashtable to obtain all leaf nodes and their paths.
            Essentially looks at each Key in the $JsonHashtable passed to the function. If the key is not
            a hashtable or is an empty hashtable, then it is added to $this.PathsHashtable in the format
            described in Paths(). Arrays are a special case, because they must be processed using their
            indices instead of keys and may potentially contain more hashtables. Their elements are
            treated the same way as previously described, unless they contain a hashtable. In which case
            they are traversed to continue the DFS until leaf nodes are reached.

            The Path to each key is constructed with each function call by adding the key every time in
            Path + ".Key" format and appending the index ($Path + "[$index]") when necessary.
        .PARAMETER JsonHashtable
            Hashtable that is being traversed to find paths to leaf nodes, leaf node values
        .PARAMETER Path
            Path that is appended to with each call of this function. Starts as ""
        #>

        foreach ($Key in $JsonHashtable.Keys)
        {
            $Value = $JsonHashtable[$Key]
            $NextPath = $Path + "." + $Key

            # will generally add to $PathsHashtable if $Value is not a hashtable type
            # or if $Value is an empty hashtable
            if ($Value -isnot [hashtable] -or ($Value -is [hashtable] -and $Value.Count -eq 0))
            {
                # special case if the $Value is an array:
                # need to make sure that no array elements are hashtables that continue the JSON tree
                # and need to build path with array index instead of key name
                if ($Value -is [array] -and $this.ArrayContainsType($Value, [hashtable]))
                {
                    for ($i = 0; $i -lt $Value.Length; $i++)
                    {
                        $IndexedPath = $NextPath + "[$i]"
                        if ($Value[$i] -is [hashtable])
                        {
                            $NextHashtable = $Value[$i]
                            $this.PathsHelper($NextHashtable, $IndexedPath)
                        }
                        else
                        {
                            $this.PathsHashtable[$IndexedPath] = $Value
                        }
                    }
                }
                else
                {
                    $this.PathsHashtable[$NextPath] = $Value
                }
            }
            else
            {
                $NextHashtable = $Value
                $this.PathsHelper($NextHashtable, $NextPath)
            }
        }
    }

    [bool] hidden ArrayContainsType([array]$Array, [type]$Type)
    {
        <#
        .DESCRIPTION
            Checks if $Array contains $Type.
        .PARAMETER Array
            array to search for $Type
        .PARAMETER Type
            type to find in $Array
        #>

        foreach ($Item in $Array)
        {
            if ($Item -is $Type)
            {
                return $true
            }
        }
        return $false
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