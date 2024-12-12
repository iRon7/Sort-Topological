#Requires -Modules @{ModuleName="Pester"; ModuleVersion="5.5.0"}

Using Namespace System.Collections

[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'False positive')]
param ()

Set-Alias -Name Sort-Topological -Value .\Sort-Topological.ps1

BeforeAll {

   Set-StrictMode -Version Latest
}

Describe 'Sort-Topological' {

    BeforeEach {

        $DirectId = 101..105 | Foreach-Object {
            [PSCustomObject]@{ Id = $_; Link = $Null }
        }

        $DirectId[0].Link = @($DirectId[2])
        $DirectId[1].Link = @($DirectId[3], $DirectId[4])
        $DirectId[2].Link = @()
        $DirectId[3].Link = @($DirectId[0], $DirectId[2], $DirectId[4])
        $DirectId[4].Link = @($DirectId[0])

        $List = 1..5 | Foreach-Object {
            [PSCustomObject]@{ Name = "Function$_"; Dependency = $Null }
        }

        $List[0].Dependency = @($List[2])
        $List[1].Dependency = @($List[3], $List[4])
        $List[2].Dependency = @()
        $List[3].Dependency = @($List[0], $List[2], $List[4])
        $List[4].Dependency = @($List[0])

        $IndirectId =
            [PSCustomObject]@{ Id = 101; Link = 103 },
            [PSCustomObject]@{ Id = 102; Link = 104, 105 },
            [PSCustomObject]@{ Id = 103; Link = $Null },
            [PSCustomObject]@{ Id = 104; Link = 105, 103, 101 },
            [PSCustomObject]@{ Id = 105; Link = 101 }

        $IndirectName = ConvertFrom-Json '
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

        It 'Indirect' {

            $Sort = $IndirectName | Sort-Topological -Dependency Dependency -Id Name
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }

        It 'Direct' {

            $Sort = $List | Sort-Topological -Dependency Dependency
            $Sort.Name | Should -be 'Function3', 'Function1', 'Function5', 'Function4', 'Function2'
        }
    }

    Context 'Id' {

        It 'Indirect' {

            $Sort = $IndirectId | Sort-Topological -Dependency Link -Id Id
            $Sort.Id | Should -be 103, 101, 105, 104, 102
        }

        It 'Direct' {

            $Sort = $DirectId | Sort-Topological -Dependency Link
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

        It 'ServicesDependedOn' -foreach $services.ServicesDependedOn {
            $List | Should contain $_
            $List.Add($_)
        }

    }

    Context 'Error handling' {

        BeforeEach {

            $Error.Clear()
        }

        It 'Id required' {

            $Command = { $IndirectName | Sort-Topological -Dependency Dependency }
            $Command                         | Should -Throw
            $Error[-1].TargetObject.Name     | Should -be 'Function1'
            $Error[-1]                       | Should -be 'Indirect dependencies require the IdName parameter.'
            $Error[-1].FullyQualifiedErrorId | Should -be 'MissingName,Sort-Topological.ps1'
        }

        It 'Duplicate id' {

            $IndirectName[2] = [PSCustomObject]@{ Name = 'Function1'; Dependency = @() }
            $Command = { $IndirectName | Sort-Topological -Dependency Dependency -Id Name }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be 'Function1'
            $Error[0]                       | Should -be 'Unknown vertex id: "function3".'
            $Error[0].FullyQualifiedErrorId | Should -be 'UnknownVertex,Sort-Topological.ps1'
        }

        It 'Unknown name' {

            $IndirectName[2] = [PSCustomObject]@{ Name = 'Function3'; Dependency = 'Function9' }
            $Command = { $IndirectName | Sort-Topological -Dependency Dependency -Id Name }
            $Command                        | Should -Throw
            $Error[0].TargetObject.Name     | Should -be 'Function3'
            $Error[0]                       | Should -be 'Unknown vertex id: "function9".'
            $Error[0].FullyQualifiedErrorId | Should -be 'UnknownVertex,Sort-Topological.ps1'
        }

        It 'Unknown id' {

            $IndirectId[2] = [PSCustomObject]@{ Id = 103; Link = 109 }
            $Command = { $IndirectId | Sort-Topological -Dependency Link -Id Id }
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
            $Error[0].TargetObject.Id       | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: 103, 101, 104, 103.'
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
            $Error[0].TargetObject.Name     | Should -be 103
            $Error[0]                       | Should -be 'Circular dependency: "103", "101", "104", "103".'
            $Error[0].FullyQualifiedErrorId | Should -be 'CircularDependency,Sort-Topological.ps1'
        }

        It 'Direct circular 1' {

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

        It 'Direct circular 2' {

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


        It 'Direct circular 3' {

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
    }
}