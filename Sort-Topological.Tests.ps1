#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.5.0"}

Using Namespace System.Collections

[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'False positive')]
param ()

Set-Alias -Name Sort-Topological -Value .\Sort-Topological.ps1

BeforeAll {

   Set-StrictMode -Version Latest
}

Describe 'Sort-Topological' {

    BeforeAll {

        $ByObject = 101..105 | Foreach-Object {
            [PSCustomObject]@{ Id = $_; Name = "Function$_"; Link = $Null }
        }

        $ByObject[0].Link = @($ByObject[2])
        $ByObject[1].Link = @($ByObject[3], $ByObject[4])
        $ByObject[2].Link = @()
        $ByObject[3].Link = @($ByObject[0], $ByObject[2], $ByObject[4])
        $ByObject[4].Link = @($ByObject[0])

        $IntegerId =
            [PSCustomObject]@{ Id = 101; Link = 103 },
            [PSCustomObject]@{ Id = 102; Link = 104, 105 },
            [PSCustomObject]@{ Id = 103; Link = $Null },
            [PSCustomObject]@{ Id = 104; Link = 105, 103, 101 },
            [PSCustomObject]@{ Id = 105; Link = 101 }

        $StringId = ConvertFrom-Json '
        [
            { "Name": "Function1", "Dependency": ["Function3"] },
            { "Name": "Function2", "Dependency": ["Function4", "Function5"] },
            { "Name": "Function3", "Dependency": [] },
            { "Name": "Function4", "Dependency": ["Function1", "Function3", "Function5"] },
            { "Name": "Function5", "Dependency": ["Function1"] }
        ]'
    }

    Context 'Existence Check' {

        It 'Help' {
            .\Sort-Topological.ps1 -? | Out-String -Stream | Should -Contain SYNOPSIS
        }
    }

    Context 'Name' {

        It 'By property (using parameter)' {

            $Sort = Sort-Topological -InputObject $StringId -Dependency Dependency -Id Name
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }

        It 'By property (using pipeline)' {

            $Sort = $StringId | Sort-Topological -Dependency Dependency -Id Name
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }

        It 'By object (using parameter)' {

            $Sort = Sort-Topological -Input $ByObject -Dependency Link
            $Sort.Name | Should -be 'Function103', 'Function101', 'Function105', 'Function104', 'Function102'
        }

        It 'By object (using pipeline)' {

            $Sort = $ByObject | Sort-Topological -Dependency Link
            $Sort.Name | Should -be 'Function103', 'Function101', 'Function105', 'Function104', 'Function102'
        }
    }

    Context 'Id' {

        It 'By property' {

            $Sort = $IntegerId | Sort-Topological -Dependency Link -Id Id
            $Sort.Id | Should -be 103, 101, 105, 104, 102
        }

        It 'By object' {

            $Sort = $ByObject | Sort-Topological -Dependency Link
            $Sort.Id | Should -be 103, 101, 105, 104, 102
        }
    }

    Context 'Unroll pitfalls' {

        It '$Null' {

            $List = ConvertFrom-Json '
                [
                    { "Name": "Function1", "Dependency": ["Function3"] },
                    { "Name": "Function2", "Dependency": ["Function4", "Function5"] },
                    { "Name": "Function3", "Dependency": null },
                    { "Name": "Function4", "Dependency": ["Function1", "Function3", "Function5"] },
                    { "Name": "Function5", "Dependency": ["Function1"] }
                ]'

            $Sort = $List | Sort-Topological -Dependency Dependency -Id Name
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }

        It '(String) scalars' {

            $List = ConvertFrom-Json '
                [
                    { "Name": "Function1", "Dependency": "Function3" },
                    { "Name": "Function2", "Dependency": ["Function4", "Function5"] },
                    { "Name": "Function3", "Dependency": [] },
                    { "Name": "Function4", "Dependency": ["Function1", "Function3", "Function5"] },
                    { "Name": "Function5", "Dependency": "Function1" }
                ]'

            $Sort = $List | Sort-Topological -Dependency Dependency -Id Name
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }

        It '0 and Empty string' {

            $List =
                [PSCustomObject]@{ Name =  1; Link = '', 0 },
                [PSCustomObject]@{ Name =  0; Link = '' },
                [PSCustomObject]@{ Name = ''; Link = $Null }

            $Sort = $List | Sort-Topological -Dependency Link -Id Name
            $Sort.Name | Should -be '', 0, 1
        }
    }

    Context 'Services' -Skip:($PSVersionTable.PSEdition -ne 'Desktop') {

        beforeAll {
            $Services = Get-Service
            $Ordered = $Services | Sort-Topological -Dependency ServicesDependedOn

            $List = [List[Object]]::new()
        }

        # It 'ServicesDependedOn' -foreach $service.ServicesDependedOn {
        #     $List | Should contain $_
        #     $List.Add($_)
        # }

    }

    Context 'Use cases' {

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

        $Sorted.Name | Should -be 'Class3', 'Class1', 'Class5', 'Class4', 'Class2'
    }

    Context 'Error handling' {

        BeforeEach {

            $Error.Clear()
        }

        It 'Id required' {

            $Command = { $StringId | Sort-Topological -Dependency Dependency }
            $Command                         | Should -Throw
            $Error[-1].TargetObject.Name     | Should -be 'Function1'
            $Error[-1]                       | Should -be 'Dependencies by id require the IdName parameter.'
            $Error[-1].FullyQualifiedErrorId | Should -be 'MissingIdName,Sort-Topological.ps1'
        }

        It 'Not exists name' {

            $StringId[2].Dependency = 'Function9'
            $Command = { $StringId | Sort-Topological -Dependency Dependency -Id Name }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be 'Function3'
            $Error[0]                       | Should -be 'Unknown vertex id: "function9".'
            $Error[0].FullyQualifiedErrorId | Should -be 'UnknownVertex,Sort-Topological.ps1'
        }

        It 'Not exists id' {

            $IntegerId[2].Link = 109
            $Command = { $IntegerId | Sort-Topological -Dependency Link -Id Id }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Unknown vertex id: 109.'
            $Error[0].FullyQualifiedErrorId | Should -be 'UnknownVertex,Sort-Topological.ps1'
        }

        It 'Integer circular 1' {

            $List =
                [PSCustomObject]@{ Id = 101; Link = 103 },
                [PSCustomObject]@{ Id = 102; Link = 104, 105 },
                [PSCustomObject]@{ Id = 103; Link = 103 }, # Circular 103
                [PSCustomObject]@{ Id = 104; Link = 105, 103, 101 },
                [PSCustomObject]@{ Id = 105; Link = 101 }

            $Command = { $List | Sort-Topological -Id Id -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: 103, 103.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'Integer circular 2' {

            $List =
                [PSCustomObject]@{ Id = 101; Link = 103 },
                [PSCustomObject]@{ Id = 102; Link = 104, 105 },
                [PSCustomObject]@{ Id = 103; Link = 104 }, # Circular 103, 104
                [PSCustomObject]@{ Id = 104; Link = 103 },
                [PSCustomObject]@{ Id = 105; Link = 101 }

            $Command = { $List | Sort-Topological -Id Id -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: 103, 104, 103.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'Integer circular 3' {

            $List =
                [PSCustomObject]@{ Id = 101; Link = 103 }, # Circular 101, 103, 104
                [PSCustomObject]@{ Id = 102; Link = 104, 105 },
                [PSCustomObject]@{ Id = 103; Link = 104 },
                [PSCustomObject]@{ Id = 104; Link = 105, 101 },
                [PSCustomObject]@{ Id = 105; Link = $Null }

            $Command = { $List | Sort-Topological -Id Id -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 101
            $Error[0]                       | Should -be 'Circular dependency: 101, 104, 103, 101.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'String circular 1' {

            $List =
                [PSCustomObject]@{ Name = '101'; Link = '103' },
                [PSCustomObject]@{ Name = '102'; Link = '104', '105' },
                [PSCustomObject]@{ Name = '103'; Link = '103' }, # Circular '103'
                [PSCustomObject]@{ Name = '104'; Link = '105', '103', '101' },
                [PSCustomObject]@{ Name = '105'; Link = '101' }

            $Command = { $List | Sort-Topological -Id Name -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be '103'
            $Error[0]                       | Should -be 'Circular dependency: "103", "103".'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'String circular 2' {

            $List =
                [PSCustomObject]@{ Name = '101'; Link = '103' },
                [PSCustomObject]@{ Name = '102'; Link = '104', '105' },
                [PSCustomObject]@{ Name = '103'; Link = '104' }, # Circular '103', '104'
                [PSCustomObject]@{ Name = '104'; Link = '103' },
                [PSCustomObject]@{ Name = '105'; Link = '101' }

            $Command = { $List | Sort-Topological -Id Name -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: "103", "104", "103".'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'String circular 3' {

            $List =
                [PSCustomObject]@{ Name = '101'; Link = '103' }, # Circular '101', '103', '104'
                [PSCustomObject]@{ Name = '102'; Link = '104', '105' },
                [PSCustomObject]@{ Name = '103'; Link = '104' },
                [PSCustomObject]@{ Name = '104'; Link = '105', '101' },
                [PSCustomObject]@{ Name = '105'; Link = $Null }

            $Command = { $List | Sort-Topological -Id Name -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be 101
            $Error[0]                       | Should -be 'Circular dependency: "101", "104", "103", "101".'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'By object circular 1' {

            $List = 101..105 | Foreach-Object {
                [PSCustomObject]@{ Id = $_; Link = $Null }
            }

            $List[0].Link = $List[2]
            $List[1].Link = @($List[3], $List[4])
            $List[2].Link = $List[2] # Circular
            $List[3].Link = @($List[0], $List[2], $List[4])
            $List[4].Link = $List[0]

            $Command = { $List | Sort-Topological -Dependency Link -IdName Id }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: 103, 103.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'

            $Command = { $List | Sort-Topological -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: [2], [2].'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'By object circular 2' {

            $List = 101..105 | Foreach-Object {
                [PSCustomObject]@{ Id = $_; Link = $Null }
            }

            $List[0].Link = $List[2]
            $List[1].Link = @($List[3], $List[4])
            $List[2].Link = $List[3] # Circular 2, 3
            $List[3].Link = @($List[2], $List[4])
            $List[4].Link = $List[0]

            $Command = { $List | Sort-Topological -Dependency Link -IdName Id }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: 103, 104, 103.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'

            $Command = { $List | Sort-Topological -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: [2], [3], [2].'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }


        It 'By object circular 3' {

            $List = 101..105 | Foreach-Object {
                [PSCustomObject]@{ Id = $_; Link = $Null }
            }

            $List[0].Link = $List[2] # Circular 0, 2, 3
            $List[1].Link = @($List[3], $List[4])
            $List[2].Link = $List[3]
            $List[3].Link = @($List[0], $List[4])
            $List[4].Link = $List[0]

            $Command = { $List | Sort-Topological -Dependency Link -IdName Id }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 101
            $Error[0]                       | Should -be 'Circular dependency: 101, 104, 103, 101.'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'

            $Command = { $List | Sort-Topological -Dependency Link }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Id       | Should -be 101
            $Error[0]                       | Should -be 'Circular dependency: [0], [3], [2], [0].'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        it 'expression should contain safe path' {
            $Script = @'
                Class Class1 : Class3 { }
                Class Class2 : Class4, Class5 { }
                Class Class3 { }
                Class Class4 : Class5, Class3, Class1 { }
                Class Class5 : Class1 { }
'@

            $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Script, [ref]$null, [ref]$null)
            $Classes = $Ast.EndBlock.Statements
            $Command = { $Classes | Sort-Topological -IdName Name -DependencyName { $_.BaseTypes.TypeName.$Name } }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Member   | Should -be '$Name'
            $Error[0]                       | Should -be 'The { $_.BaseTypes.TypeName.$Name } expression should contain safe path.'
            $Error[0].FullyQualifiedErrorId | Should -be 'InvalidIdExpression,Sort-Topological.ps1'
        }
    }
}