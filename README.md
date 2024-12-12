<!-- markdownlint-disable MD033 -->
# Sort-Topological

Sort-Topological

## Syntax

```PowerShell
Sort-Topological
    -EdgeName <String>
    [-IdName <String>]
    [-InputObject <Object>]
    [<CommonParameters>]
```

## Description

Orders vertices such that for every directed edge u-v, vertex u comes before v in the ordering.

This `Sort-Topological`, supports two ways of linking dependencies to other objects:

* **Direct** the property defined by the [-EdgeName parameter](#-edgename-parameter) holds a single or a list of objects which reference
directly into any other object in the list supplied by the [-InputObject parameter](#-inputobject-parameter).

* **Indirect** the property defined by the [-EdgeName parameter](#-edgename-parameter) holds a single or a list of `[ValueType]`s
(such as an integer) or `[String]`s which indirectly refers to any other object in the list supplied by the
[-InputObject parameter](#-inputobject-parameter) where the value of the property defined by the [-IdName parameter](#-idname-parameter) is equal.

## Examples

### Example 1: Topological sort services


```PowerShell
Get-Service | Sort-Topological -Dependency ServicesDependedOn # -IdName Name
```

### Example 2: Indirect dependencies


A list with indirect dependencies is often build during design-time using e.g. the [`ConvertFrom-Json`](https://go.microsoft.com/fwlink/?LinkID=2096606) cmdlet:

```PowerShell
$List = ConvertFrom-Json '
    [
        { "Name": "Function1", "Dependency": ["Function3"] },
        { "Name": "Function2", "Dependency": ["Function4", "Function5"] },
        { "Name": "Function3", "Dependency": [] },
        { "Name": "Function4", "Dependency": ["Function1", "Function3", "Function5"] },
        { "Name": "Function5", "Dependency": ["Function1"] }
    ]'
```

To topological sort the indirect dependency list, the following parameters are required:

* The name of the property that holds the (unique) identification of each object (see: [-IdName parameter](#-idname-parameter))
* The name of the property that holds the dependent vertices (see: [-VertexName parameter](#-vertexname-parameter))

```PowerShell
$List | Sort-Topological -Dependency Dependency -Id Name

Name      Dependency
----      ----------
Function3 {}
Function1 {Function3}
Function5 {Function1}
Function4 {Function1, Function3, Function5}
Function2 {Function4, Function5}
```

### Example 3: Direct dependencies


A list with direct dependencies can only be build during run-time as it requires the objects to exists before they
could be linked:

```PowerShell
$List = 1..5 | Foreach-Object {
    [PSCustomObject]@{ Name = "Function$_"; Dependency = $Null }
}

$List[0].Dependency = @($List[2])
$List[1].Dependency = @($List[3], $List[4])
$List[2].Dependency = @()
$List[3].Dependency = @($List[0], $List[2], $List[4])
$List[4].Dependency = @($List[0])
```

To topological sort the direct dependency list, only the name of the property that holds the dependent vertices
(see: [-VertexName parameter](#-vertexname-parameter)) is required.

```PowerShell
$List | Sort-Topological -Dependency Dependency -Id Name

Name      Dependency
----      ----------
Function3 {}
Function1 {@{Name=Function3; Dependency=System.Object[]}}
Function5 {@{Name=Function1; Dependency=System.Object[]}}
Function4 {@{Name=Function1; Dependency=System.Object[]}, @{Name=Function3; Dependency=System.Object[]}, @{Name=Function5; Dependency=SystΓÇª
Function2 {@{Name=Function4; Dependency=System.Object[]}, @{Name=Function5; Dependency=System.Object[]}}
```

## Parameters

### <a id="-edgename">**`-EdgeName <String>`**</a>

The name of the property that holds the dependent vertices (see: [-VertexName parameter](#-vertexname-parameter)).
The concerned property might either contain any number of directly referenced objects or any number of indirect
objects links where a `[String]` or `[ValueType]` links the dependency to object with the specific object id
(see: [-IdName parameter](#-idname-parameter)).

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.String">String</a></td></tr>
<tr><td>Mandatory:</td><td>True</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-idname">**`-IdName <String>`**</a>

The name of the property that holds the (unique) identification of each object.
This parameter is only required for objects which indirectly references the dependencies.

> [!Tip]
>
> Even the [-VertexName parameter](#-vertexname-parameter) isn't required for direct dependencies, you might still consider to do so.
> This way, error messages refer to the object identification rather than the index of the object.

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.String">String</a></td></tr>
<tr><td>Mandatory:</td><td>False</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-inputobject">**`-InputObject <Object>`**</a>

A list of objects to be topologically sorted.
```

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.Object">Object</a></td></tr>
<tr><td>Mandatory:</td><td>False</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

## Inputs

PSCustomObject[]

## Outputs

PSCustomObject[]

[comment]: <> (Created with Get-MarkdownHelp: Install-Script -Name Get-MarkdownHelp)
