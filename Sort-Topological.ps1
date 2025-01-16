<#PSScriptInfo
.Version 0.1.1
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

.INPUTS
PSCustomObject[]

.OUTPUTS
PSCustomObject[]

.EXAMPLE
# Custom list with dependencies

Sorting the following list of objects with dependencies:

    $List =
        [PSCustomObject]@{ Id = 101; Dependency = 103 },
        [PSCustomObject]@{ Id = 102; Dependency = 104, 105 },
        [PSCustomObject]@{ Id = 103; Dependency = $Null },
        [PSCustomObject]@{ Id = 104; Dependency = 105, 103, 101 },
        [PSCustomObject]@{ Id = 105; Dependency = 101 }

    $List | Sort-Topological -Dependency Dependency -Name Id

Results in:

     Id Dependency
     -- ----------
    103
    101 103
    105 101
    104 {105, 103, 101}
    102 {104, 105}

.EXAMPLE
# Class extension dependencies

Consider a list of classes where some of the classes are extended (dependent) on other classes.

    $Script = @'
        Class Class1 : Class3 { }
        Class Class2 : Class4, Class5 { }
        Class Class3 { }
        Class Class4 : Class5, Class3, Class1 { }
        Class Class5 : Class1 { }
    '@

    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Script, [ref]$null, [ref]$null)
    $Classes = $Ast.EndBlock.Statements
    $Sorted = $Classes | Sort-Topological -IdName Name -DependencyName { $_.BaseTypes.TypeName.Name }
    $Sorted.Name

    Class3
    Class1
    Class5
    Class4
    Class2


.EXAMPLE
# Topological sort of services
Order the service list based on the `ServicesDependedOn` property.

    $Services = Get-Service
    $Ordered = $Services | Sort-Topological -Dependency ServicesDependedOn

.PARAMETER InputObject
A list of objects to be topologically sorted.

.PARAMETER EdgeName
The name (or path) of the property that contains the dependency list.
If the EdgeName is a script block, the script block is executed for each vertex to retrieve the dependency list.

> [!IMPORTANT]
> To prevent code injection, the script block should only contain safe paths in the form of
> `$_.<verbatim path>` or `$PSItem.<verbatim path>`, e.g.: `$_.BaseTypes.TypeName.Name`.
> Any other type is converted to a `[String]` type.

There are two ways a dependency list might be setup:

1. By property (id)
2. By object

The Sort-Topological cmdlet automatically recognizes each way.

#### By property (id)
Each dependency in the list is linked to a vertex (object node) by an id or a name.
For instance a class extension which is depended on a base class that is defined by the base class *name*.

#### By object
Each dependency in the list directly refers to an other (vertex) object in the `$InputObject` list.
For instance the [`DependentServices` property][1] of a [`ServiceController` object][2] retrieved from
[Get-Service] cmdlet that contains a (recursive) list of other service *objects* that are directly linked
by their reference.

Such dependencies might only be linked during run time like:

    $ByObject = 101..105 | Foreach-Object {
        [PSCustomObject]@{ Id = $_; Name = "Function$_"; Link = $Null }
    }

    $ByObject[0].Link = @($ByObject[2])
    $ByObject[1].Link = @($ByObject[3], $ByObject[4])
    $ByObject[2].Link = @()
    $ByObject[3].Link = @($ByObject[0], $ByObject[2], $ByObject[4])
    $ByObject[4].Link = @($ByObject[0])

.PARAMETER IdName
The name of the property that contains the property name used to identify the object in the `InputObject` list
The `IdName` parameter is required when the dependencies are linked **by property (id)**.

> [!TIP]
> The `IdName` is not required in case the dependencies are linked **by object**.
> Yet, supplying the `IdName` might help to easier identify an object in a (circular) sort error message.

.LINK
[1]: https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontroller.dependentservices "ServiceController"
[2]: https://learn.microsoft.com/dotnet/api/system.serviceprocess.servicecontroller "DependentServices"
#>

Using Namespace System.Management.Automation
Using Namespace System.Management.Automation.Language
Using Namespace System.Collections
Using Namespace System.Collections.Generic

[Diagnostics.CodeAnalysis.SuppressMessage('PSUseApprovedVerbs', '', Scope = 'function', Target = '' )]
[CmdletBinding()]Param(
    [Parameter(ValueFromPipeline = $True, Mandatory = $True)]$InputObject,
    [Parameter(Position = 0, Mandatory = $True)][Alias('DependencyName')]$EdgeName,
    [Parameter(Position = 1)][Alias('NameId')][String]$IdName
)

function PSError($Exception, $Id = 'TopologicalSortError', $Target = $Vertex, $Category = 'InvalidArgument') {
    $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($Exception, $Id, $Category, $Target))
}

if ($EdgeName -is [ScriptBlock]) { # Prevent code injection
    $Ast = [System.Management.Automation.Language.Parser]::ParseInput($EdgeName, [ref]$null, [ref]$null)
    $Expression = $Ast.EndBlock.Statements.PipelineElements.Expression
    While ($Expression -is [MemberExpressionAst] -and $Expression.Member -is [StringConstantExpressionAst]) {
        $Expression = $Expression.Expression
    }
    if ($Expression -isnot [VariableExpressionAst] -or $Expression.VariablePath.UserPath -notin '_', 'PSItem') {
        PSError "The { $Expression } expression should contain safe path." 'InvalidIdExpression' $Expression
    }
}
elseif ($Null -ne $IdName -and $IdName -isnot [String]) { $IdName = "$IdName" }

Function FormatId ($Vertex) {
    if ($Vertex -is [ValueType] -or $Vertex -is [String]) { $Value = $Vertex }
    elseif (@($_.PSObject.Properties.Name).Contains($IdName)) { $Value = $_.PSObject.Properties[$IdName].Value }
    else { return "[$(@($List).IndexOf($Vertex))]" }
    if ($Value -is [String]) { """$Value""" } else { $Value }
}

$ById = $Null
$Sorted = [List[Object]]::new()
if ($Input) { $List = $Input } else { $List = $InputObject }
if ($List -isnot [iEnumerable]) { return $List }
$EdgeCount = 0
while ($Sorted.get_Count() -lt $List.get_Count()) {
    $Stack = [Stack]::new()
    $Enumerator = $List.GetEnumerator()
    while ($Enumerator.MoveNext()) {
        $Vertex = $Enumerator.Current
        if($Sorted.Contains($Vertex)) { continue }
        $Edges = [List[Object]]::new()
        if ($EdgeName -is [ScriptBlock]) { $Edges = $Vertex.foreach($EdgeName) }
        else { $Edges = $Vertex.PSObject.Properties[$EdgeName].Value }
        if ($Edges -isnot [iList]) { $Edges = @($Edges) }
        if ($Null -eq $ById -and $Edges.Count -gt 0) {
            if ($Edges[0] -is [ValueType] -or $Edges[0] -is [String]) {
                if (-not $IdName) { PSError 'Dependencies by id require the IdName parameter.' 'MissingIdName' }
                $ById = @{}
                foreach ($Item in $List) { $ById[$Item.PSObject.Properties[$IdName].Value] = $Item }
            } else { $ById = $False }
        }
        if ($ById) {
            $Ids = $Edges; $Edges = [List[Object]]::new()
            foreach ($Id in $Ids) {
                if ($Null -eq $Id) { } elseif ($ById.contains($Id)) { $Edges.Add($ById[$Id]) }
                else{ PSError "Unknown vertex id: $(FormatId $Id)." 'UnknownVertex' }
            }
        }
        if ($Stack.Count -gt 0 -or $Edges.Count -eq $EdgeCount) {
            $ExistsAt = if ($Stack.Count -gt 0) { @($Stack.Current).IndexOf($Vertex) + 1 }
            $Stack.Push($Enumerator)
            if ($ExistsAt -gt 0) {
                $Cycle = (@($Stack)[0..$ExistsAt].Current).foreach{ FormatId $_ } -Join ', '
                PSError "Circular dependency: $Cycle." 'CircularDependency'
            }
            $Enumerator = $Edges.GetEnumerator()
        }
    }
    if ($Stack.Count -gt 0) {
        $Enumerator = $Stack.Pop()
        $Vertex = $Enumerator.Current
        if ($Vertex -is [ValueType] -or $Vertex -is [String]) { $Vertex = $ById[$Vertex] }
        if (-not $Sorted.Contains($Vertex)) { $Sorted.Add($Vertex) }
    }
    else { $EdgeCount++ }
}
$Sorted