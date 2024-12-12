<#PSScriptInfo
.Version 0.1.0
.Guid 19631007-48a4-4acc-b0bc-c1a23796eb24
.Author Ronald Bode (iRon)
.Description Orders vertices such that for every directed edge u-v, vertex u comes before v in the ordering.
.CompanyName PowerSnippets.com
.Copyright Ronald Bode (iRon)
.Tags Sort Topological Dependency Vertex Edge
.LicenseUri https://github.com/iRon7/Sort-Topological/LICENSE
.ProjectUri https://github.com/iRon7/Sort-Topological
.IconUri https://raw.githubusercontent.com/iRon7/Sort-Topological/master/Sort-Topological.png
.ExternalModuleDependencies
.RequiredScripts
.ExternalScriptDependencies
.ReleaseNotes
.PrivateData
#>

<#
.SYNOPSIS
Sort-Topological

.DESCRIPTION
Orders vertices such that for every directed edge u-v, vertex u comes before v in the ordering.

This `Sort-Topological`, supports two ways of linking dependencies to other objects:

* **Direct** the property defined by the [-EdgeName parameter] holds a single or a list of objects which reference
   directly into any other object in the list supplied by the [-InputObject parameter].

* **Indirect** the property defined by the [-EdgeName parameter] holds a single or a list of `[ValueType]`s
   (such as an integer) or `[String]`s which indirectly refers to any other object in the list supplied by the
   [-InputObject parameter] where the value of the property defined by the [-IdName parameter] is equal.

.INPUTS
PSCustomObject[]

.OUTPUTS
PSCustomObject[]

.EXAMPLE
# Topological sort services

    Get-Service | Sort-Topological -Dependency ServicesDependedOn # -IdName Name

.EXAMPLE
# Indirect dependencies

A list with indirect dependencies is often build during design-time using e.g. the [ConvertFrom-Json] cmdlet:

    $List = ConvertFrom-Json '
        [
            { "Name": "Function1", "Dependency": ["Function3"] },
            { "Name": "Function2", "Dependency": ["Function4", "Function5"] },
            { "Name": "Function3", "Dependency": [] },
            { "Name": "Function4", "Dependency": ["Function1", "Function3", "Function5"] },
            { "Name": "Function5", "Dependency": ["Function1"] }
        ]'

To topological sort the indirect dependency list, the following parameters are required:

* The name of the property that holds the (unique) identification of each object (see: [-IdName parameter])
* The name of the property that holds the dependent vertices (see: [-VertexName parameter])

    $List | Sort-Topological -Dependency Dependency -Id Name

    Name      Dependency
    ----      ----------
    Function3 {}
    Function1 {Function3}
    Function5 {Function1}
    Function4 {Function1, Function3, Function5}
    Function2 {Function4, Function5}

.EXAMPLE
# Direct dependencies

A list with direct dependencies can only be build during run-time as it requires the objects to exists before they
could be linked:

    $List = 1..5 | Foreach-Object {
        [PSCustomObject]@{ Name = "Function$_"; Dependency = $Null }
    }

    $List[0].Dependency = @($List[2])
    $List[1].Dependency = @($List[3], $List[4])
    $List[2].Dependency = @()
    $List[3].Dependency = @($List[0], $List[2], $List[4])
    $List[4].Dependency = @($List[0])

To topological sort the direct dependency list, only the name of the property that holds the dependent vertices
(see: [-VertexName parameter]) is required.

    $List | Sort-Topological -Dependency Dependency -Id Name

    Name      Dependency
    ----      ----------
    Function3 {}
    Function1 {@{Name=Function3; Dependency=System.Object[]}}
    Function5 {@{Name=Function1; Dependency=System.Object[]}}
    Function4 {@{Name=Function1; Dependency=System.Object[]}, @{Name=Function3; Dependency=System.Object[]}, @{Name=Function5; Dependency=Syst…
    Function2 {@{Name=Function4; Dependency=System.Object[]}, @{Name=Function5; Dependency=System.Object[]}}

.PARAMETER InputObject
A list of objects to be topologically sorted.

.PARAMETER EdgeName
The name of the property that holds the dependent vertices (see: [-VertexName parameter]).
The concerned property might either contain any number of directly referenced objects or any number of indirect
objects links where a `[String]` or `[ValueType]` links the dependency to object with the specific object id
(see: [-IdName parameter]).

.PARAMETER IdName
The name of the property that holds the (unique) identification of each object.
This parameter is only required for objects which indirectly references the dependencies.

> [!Tip]
>
> Even the [-VertexName parameter] isn't required for direct dependencies, you might still consider to do so.
> This way, error messages refer to the object identification rather than the index of the object.
#>

Using Namespace System.Management.Automation
Using Namespace System.Collections
Using Namespace System.Collections.Generic

[Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '', Scope = 'function', Target = '' )]
[CmdletBinding(HelpURI = 'https://github.com/iRon7/Sort-Topological/blob/main/README.md')]Param(
    [Parameter(Mandatory = $True)][Alias('DependencyName')][String]$EdgeName,
    [Alias('NameId')][String]$IdName,
    [Parameter(ValueFromPipeline = $True)]$InputObject
)

function PSError($Exception, $Id = 'TopologicalSortError', $Category = 'InvalidArgument', $Target = $Vertex) {
    $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($Exception, $Id, $Category, $Target))
}

$GetId = {
    if ($_ -is [ValueType] -or $_ -is [String]) { $Value = $_ }
    elseif (@($_.PSObject.Properties.Name).Contains($IdName)) { $Value = $_.PSObject.Properties[$IdName].Value }
    else { return "[$(@($Input).IndexOf($_))]" }
    if ($Value -is [String]) { """$Value""" } else { $Value }
}

$Lookup = @{}

$Sorted = [List[Object]]::new()
if ($Input -isnot [iEnumerable]) { return $Input }
$EdgeCount = 0
while ($Sorted.get_Count() -lt $Input.get_Count()) {
    $Stack = [Stack]::new()
    $Enumerator = $Input.GetEnumerator()
    while ($Enumerator.MoveNext()) {
        $Current = $Enumerator.Current
        if ($Current -isnot [ValueType] -and $Current -isnot [String]) { $Vertex = $Current }
        else {
            if (-not $IdName) { PSError 'Indirect dependencies require the IdName parameter.' 'MissingName' }
            if ($Lookup.Count -eq 0) { $Input.foreach{
                if ($Lookup.Contains($IdName)) { PSError 'Duplicate id: $(@($_).foreach($GetId))' 'DuplicateId' }
                $Lookup[$_.PSObject.Properties[$IdName].Value] = $_
            } }
            if ($Lookup.contains($Current)) { $Vertex = $Lookup[$Current] }
            else{ PSError "Unknown vertex id: $(@($Current).foreach($GetId))." 'UnknownVertex' }
        }
        if($Sorted.Contains($Vertex)) { continue }
        $Edges = $Vertex.PSObject.Properties[$EdgeName].Value
        if ($Null -eq $Edges) { $Edges = @() } # No Edges
        elseif ($Edges -isnot [iList]) { $Edges = @($Edges) }
        if ($Stack.Count -gt 0 -or $Edges.Count -eq $EdgeCount) {
            $ExistsAt = if ($Stack.Count -gt 0) { @($Stack.Current).IndexOf($Current) + 1 }
            $Stack.Push($Enumerator)
            if ($ExistsAt -gt 0) {
                $Cycle = @(@($Stack)[0..$ExistsAt].Current).foreach($GetId) -Join ', '
                PSError "Circular dependency: $Cycle." 'CircularDependency'
            }
            $Enumerator = $Edges.GetEnumerator()
        }
    }
    if ($Stack.Count -gt 0) {
        $Enumerator = $Stack.Pop()
        $Vertex = $Enumerator.Current
        if ($Vertex -is [ValueType] -or $Vertex -is [String]) { $Vertex = $Lookup[$Vertex] }
        if (-not $Sorted.Contains($Vertex)) { $Sorted.Add($Vertex) }
    }
    else { $EdgeCount++ }
}
$Sorted