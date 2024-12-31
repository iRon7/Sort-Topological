<!-- MarkdownLint-disable MD033 -->
# Sort-Topological

Sort-Topological

## Syntax

```PowerShell
Sort-Topological
    [-InputObject <Object>]
    -EdgeName <String>
    [-IdName <String>]
    [<CommonParameters>]
```

## Description

Orders vertices such that for every directed edge u-v, vertex u comes before v in the ordering

## Examples

### Example 1: Order services


Order the service list based on the (direct) `ServicesDependedOn` property.

```PowerShell
$Services = Get-Service
$Ordered = $Services | Sort-Topological -Dependency ServicesDependedOn
```

## Parameters

### <a id="-inputobject">**`-InputObject <Object>`**</a>

A list of objects to be topologically sorted.

The name of the property that contains the name (identification) used for the DependencyList

There are two ways a dependency list might be setup:

1. *Indirect by id or name*
Each dependency in the list is linked to a vertex (object node) by an id or a name. For instance a class extension which is depended on a base class that is defined by the base class *name*.

Class example

Such dependencies might be build during run time like:

The Sort-Topological cmdlet automatically recognizes each way and requires the

1. *By reference*
Each dependency in the list is directly linked to a vertex (object node) where the concerned vertex is dependent on. For instance the dependentServices property of a [Service object`] that contains a list of (recursive) service *objects* retrieved from [`Get-Service`](https://go.microsoft.com/fwlink/?LinkID=2096496) cmdlet.
Such dependencies are usually created during run time like:

> !Tip
> The VertexId is not required in case the dependencies are directly linked to vertices (object nodes). Yet, supplying the VertexId might help to easier identify a Circular┬ádependency.

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.Object">Object</a></td></tr>
<tr><td>Mandatory:</td><td>False</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-edgename">**`-EdgeName <String>`**</a>

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.String">String</a></td></tr>
<tr><td>Mandatory:</td><td>True</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-idname">**`-IdName <String>`**</a>

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.String">String</a></td></tr>
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
