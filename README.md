<!-- markdownlint-disable MD033 -->
# Sort-Topological

Sort-Topological

## Syntax

```PowerShell
Sort-Topological
    -InputObject <Object>
    -EdgeName <Object>
    [-IdName <String>]
    [<CommonParameters>]
```

## Description

Orders vertices such that for every directed edge u-v, vertex u comes before v in the ordering.

## Examples

### Example 1: Custom list with dependencies


Sorting the following list of objects with dependencies:

```PowerShell
$List =
    [PSCustomObject]@{ Id = 101; Dependency = 103 },
    [PSCustomObject]@{ Id = 102; Dependency = 104, 105 },
    [PSCustomObject]@{ Id = 103; Dependency = $Null },
    [PSCustomObject]@{ Id = 104; Dependency = 105, 103, 101 },
    [PSCustomObject]@{ Id = 105; Dependency = 101 }

$List | Sort-Topological -Dependency Dependency -Name Id
```

Results in:

```PowerShell
 Id Dependency
 -- ----------
103
101 103
105 101
104 {105, 103, 101}
102 {104, 105}
```

### Example 2: Class extension dependencies


Consider a list of classes where some of the classes are extended (dependent) on other classes.

```PowerShell
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
```

### Example 3: Topological sort of services

Order the service list based on the `ServicesDependedOn` property.

```PowerShell
$Services = Get-Service
$Ordered = $Services | Sort-Topological -Dependency ServicesDependedOn
```

## Parameters

### <a id="-inputobject">**`-InputObject <Object>`**</a>

A list of objects to be topologically sorted.

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.Object">Object</a></td></tr>
<tr><td>Mandatory:</td><td>True</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-edgename">**`-EdgeName <Object>`**</a>

The name (or path) of the property that contains the dependency list.
If the EdgeName is a script block, the script block is executed for each vertex to retrieve the dependency list.

> [!IMPORTANT]
> To prevent code injection, the script block should only contain safe paths in the form of
> `$_.<verbatim path>` or `$PSItem.<verbatim path>`, e.g.: `$_.BaseTypes.TypeName.Name`.

There are two ways a dependency list might be setup:

1. By property (id)
2. By object

The Sort-Topological cmdlet automatically recognizes each way.

**By property (id)**
Each dependency in the list is linked to a vertex (object node) by an id or a name.
For instance a class extension which is depended on a base class that is defined by the base class *name*.

**By object**
Each dependency in the list directly refers to an other (vertex) object in the `$InputObject` list.
For instance the [`DependentServices` property][1] of a [`ServiceController` object][2] retrieved from
[`Get-Service`](https://go.microsoft.com/fwlink/?LinkID=2096496) cmdlet that contains a (recursive) list of other service *objects* that are directly linked
by their reference.

Such dependencies might only be linked during run time like:

```PowerShell
$ByObject = 101..105 | Foreach-Object {
    [PSCustomObject]@{ Id = $_; Name = "Function$_"; Link = $Null }
}

$ByObject[0].Link = @($ByObject[2])
$ByObject[1].Link = @($ByObject[3], $ByObject[4])
$ByObject[2].Link = @()
$ByObject[3].Link = @($ByObject[0], $ByObject[2], $ByObject[4])
$ByObject[4].Link = @($ByObject[0])
```

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.Object">Object</a></td></tr>
<tr><td>Mandatory:</td><td>True</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-idname">**`-IdName <String>`**</a>

The name of the property that contains the property name used to identify the object in the `InputObject` list
The `IdName` parameter is required when the dependencies are linked **by property (id)**.

> [!TIP]
> The `IdName` is not required in case the dependencies are linked **by object**.
> Yet, supplying the `IdName` might help to easier identify an object in a (circular) sort error message.

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

## Related Links

* 1: [ServiceController][1]
* 2: [DependentServices][2]

[1]: https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontroller.dependentservices "ServiceController"
[2]: https://learn.microsoft.com/dotnet/api/system.serviceprocess.servicecontroller "DependentServices"

[comment]: <> (Created with Get-MarkdownHelp: Install-Script -Name Get-MarkdownHelp)
