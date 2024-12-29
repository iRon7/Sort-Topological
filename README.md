<!-- MarkdownLint-disable MD033 -->
# Set-LineNumbers

Sort-Topological

## Syntax

```PowerShell
Set-LineNumbers
    [-Script <String>]
    [-Remove]
    [<CommonParameters>]
```

## Description

Set-LineNumbers adds, update or remove line numbers to a powershell script
without affecting the functionality of the code.
This might come in handy when you want to analyze a script or share it with others.

## Examples

### Example 1: Adding line numbers


Given a script that might look like:

```PowerShell
$Script = @'
function CountChar([String]$Text, [Char]$Char) {
    $Text.ToCharArray() | Where-Object { $_ -eq $Char } | Measure-Object | Select-Object -ExpandProperty Count
}

$Text = @"
Finished files are the result of years
of scientific study combined with the
experience of many years.
"@
CountChar -Text $Text -Char 'f'
'@
```

The following command will add line numbers to the script:

```PowerShell
$Numbered = $Script | Set-LineNumbers
$Numbered

<# 01 #> function CountChar([String]$Text, [Char]$Char) {
<# 02 #>     $Text.ToCharArray() | Where-Object { $_ -eq $Char } | Measure-Object | Select-Object -ExpandProperty Count
<# 03 #> }
<# 04 #>
<# 05 #> $Text = @"
Finished files are the result of years
of scientific study combined with the
experience of many years.
"@
<# 10 #> CountChar -Text $Text -Char 'f'
```

> [!Note]
> Line numbers `06` till `09` are suppressed as line `05` is a multiline here-string.

### Example 2: updated line numbers


In case you have changed a script with line numbers and would like to renumber the script,
you might simply call the invoke the `Set-LineNumbers` cmdlet again.
The example below adds the comment "# Count the F's" to the script and renumbers it:

```PowerShell
"# Count the F's", $Numbered | Set-LineNumbers
```

### Example 3: Removing line numbers


In case you copy or download a script with line numbers and would like to remove them:

```PowerShell
$Numbered | Set-LineNumbers -Remove
```

## Parameters

### <a id="-script">**`-Script <String>`**</a>

A string that contains the script to add, update or remove line numbers.

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.String">String</a></td></tr>
<tr><td>Mandatory:</td><td>False</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

### <a id="-remove">**`-Remove`**</a>

If set, the line numbers will be removed from the script.

<table>
<tr><td>Type:</td><td><a href="https://docs.microsoft.com/en-us/dotnet/api/System.Management.Automation.SwitchParameter">SwitchParameter</a></td></tr>
<tr><td>Mandatory:</td><td>False</td></tr>
<tr><td>Position:</td><td>Named</td></tr>
<tr><td>Default value:</td><td></td></tr>
<tr><td>Accept pipeline input:</td><td>False</td></tr>
<tr><td>Accept wildcard characters:</td><td>False</td></tr>
</table>

## Inputs

String

## Outputs

String

[comment]: <> (Created with Get-MarkdownHelp: Install-Script -Name Get-MarkdownHelp)
