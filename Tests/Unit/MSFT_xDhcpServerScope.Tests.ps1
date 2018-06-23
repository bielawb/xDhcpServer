$Global:DSCModuleName      = 'xDhcpServer'
$Global:DSCResourceName    = 'MSFT_xDhcpServerScope'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else
{
    & git @('-C',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit 
#endregion

# Begin Testing
try
{
    #region Pester Tests

    # The InModuleScope command allows you to perform white-box unit testing on the internal
    # (non-exported) code of a Script Module.
    InModuleScope $Global:DSCResourceName {

        #region Pester Test Initialization
        # TODO: Optional Load Mock for use in Pester tests here...
        #endregion

        $testScopeName = 'Test Scope';
        $testScopeID = '192.168.1.0';
        $testIPStartRange = '192.168.1.10';
        $testIPEndRange = '192.168.1.99';
        $testSubnetMask = '255.255.255.0';
        $testState = 'Active';
        $testLeaseDuration = New-TimeSpan -Days 8;
        $testDescription = 'Scope description'
        
        $testParams = @{
            ScopeId = $testScopeID
            Name = $testScopeName;
            IPStartRange = $testIPStartRange;
            IPEndRange = $testIPEndRange;
            SubnetMask = $testSubnetMask;
        }
                
        $fakeDhcpServerv4Scope = [PSCustomObject] @{
            ScopeID = $testScopeID;
            Name = $testScopeName;
            StartRange = $testIPStartRange;
            EndRange = $testIPEndRange;
            Description = $testDescription
            SubnetMask = $testSubnetMask;
            LeaseDuration = $testLeaseDuration;
            State = $testState;
            AddressFamily = 'IPv4';
        }

        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {

            Mock Assert-Module -ParameterFilter { $ModuleName -eq 'DHCPServer' } { }

            It 'Calls "Assert-Module" to ensure "DHCPServer" module is available' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                
                $result = Get-TargetResource @testParams;
                
                Assert-MockCalled Assert-Module -ParameterFilter { $ModuleName -eq 'DHCPServer' } -Scope It;
            }

            It 'Throws an exception with information about incorrect <Parameter> (<Value>)' {
                param (
                    [String]$Parameter,
                    [String]$Value,
                    [String]$ErrorPattern
                )
                $brokenTestParams = $testParams.Clone()
                $brokenTestParams[$Parameter] = $Value
                try {
                    Get-TargetResource @brokenTestParams
                } catch {
                    $exception = $_.Exception
                }
                $exception.Message | Should BeLike $ErrorPattern
            } -TestCases @(
                @{
                    Parameter = 'ScopeId'
                    Value = '192.168.1.42'
                    ErrorPattern = 'Value of byte 4 in ScopeId (42) is not valid.*'
                }
                @{
                    Parameter = 'IPStartRange'
                    Value = '192.168.0.1'
                    ErrorPattern = 'Value of byte 3 in IPStartRange (0) is not valid.*'
                }
                @{
                    Parameter = 'IPEndRange'
                    Value = '192.167.1.100'
                    ErrorPattern = 'Value of byte 2 in IPEndRange (167) is not valid.*'
                }
                @{
                    Parameter = 'IPEndRange'
                    Value = '192.168.1.2'
                    ErrorPattern = 'Value * are not valid. Start should be lower than end.'
                }
            )
            
            It 'Returns a "System.Collections.Hashtable" object type' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                $result = Get-TargetResource @testParams;
                
                $result -is [System.Collections.Hashtable] | Should Be $true;
            }
        }
        #endregion Function Get-TargetResource

        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            
            Mock Assert-Module -ParameterFilter { $ModuleName -eq 'DHCPServer' } { }

            It 'Returns a "System.Boolean" object type' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                
                $result = Test-TargetResource @testParams;
                
                $result -is [System.Boolean] | Should Be $true;
            }
            
            It 'Passes when all parameters are correct' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                
                $result = Test-TargetResource @testParams;
                
                $result | Should Be $true;
            }

            It 'Passes when optional <Parameter> parameter is correct' {
                param (
                    $Parameter,
                    $Value
                )
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope }
                $optionalParameters = @{
                    $Parameter = $Value
                }
                $result = Test-TargetResource @testParams @optionalParameters
                $result | Should Be $true
            } -TestCases @(
                @{
                    Parameter = 'Description'
                    Value = $testDescription
                }
                @{
                    Parameter = 'LeaseDuration'
                    Value = $testLeaseDuration.ToString()
                }
                @{
                    Parameter = 'State'
                    Value = $testState
                }
            )
            
            It 'Passes when "Ensure" = "Absent" and scope does not exist' {
                Mock Get-DhcpServerv4Scope { }
                
                $result = Test-TargetResource @testParams -Ensure 'Absent';
                
                $result | Should Be $true;
            }
            
            It 'Fails when <parameter> parameter is incorrect' {
                param (
                    $Parameter,
                    $Value
                )
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                $testNameParams = $testParams.Clone()
                $testNameParams[$Parameter] = $Value
                $result = Test-TargetResource @testNameParams
                $result | Should Be $false
            } -TestCases @(
                @{
                    Parameter = 'Name'
                    Value = 'IncorrectName'
                }
                @{
                    Parameter = 'IPStartRange'
                    Value = '192.168.1.1'
                }
                @{
                    Parameter = 'IPEndRange'
                    Value = '192.168.1.254'
                }
                @{
                    Parameter = 'SubnetMask'
                    Value = '255.255.255.128'
                }
                @{
                    Parameter = 'Description'
                    Value = 'Wrong description'
                }
                @{
                    Parameter = 'LeaseDuration'
                    Value = '08:00:00'
                }
                @{
                    Parameter = 'State'
                    Value = 'Inactive'
                }
                @{
                    Parameter = 'Ensure'
                    Value = 'Absent'
                }
            )
        }
        #endregion

        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
            
            Mock Assert-Module -ParameterFilter { $ModuleName -eq 'DHCPServer' } { }
            
            It 'Calls "Add-DhcpServerv4Scope" when "Ensure" = "Present" and scope does not exist' {
                Mock Get-DhcpServerv4Scope { }
                Mock Add-DhcpServerv4Scope { }
                
                Set-TargetResource @testParams;
                
                Assert-MockCalled Add-DhcpServerv4Scope -Scope It;
            }
            
            It 'Calls "Remove-DhcpServerv4Scope" when "Ensure" = "Absent" and scope does exist' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                Mock Remove-DhcpServerv4Scope { }
                
                Set-TargetResource @testParams -Ensure 'Absent';
                
                Assert-MockCalled Remove-DhcpServerv4Scope -Scope It;
            }
            
            It 'Calls "Set-DhcpServerv4Scope" when "Ensure" = "Present" and scope does exist' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                Mock Set-DhcpServerv4Scope { }
                
                Set-TargetResource @testParams -LeaseDuration '08:00:00';
                
                Assert-MockCalled Set-DhcpServerv4Scope -Scope It;
            }
            
            It 'Calls "Remove-DhcpServerv4Scope" when "Ensure" = "Present", scope does exist but "SubnetMask" is incorrect' {
                Mock Get-DhcpServerv4Scope { return $fakeDhcpServerv4Scope; }
                Mock Remove-DhcpServerv4Scope { }
                Mock Set-DhcpServerv4Scope { }
                $testSubnetMaskParams = $testParams.Clone();
                $testSubnetMaskParams['SubnetMask'] = '255.255.255.128';
                
                Set-TargetResource @testSubnetMaskParams;
                
                Assert-MockCalled Remove-DhcpServerv4Scope -Scope It;
            }
            
        }
        #endregion

        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Validate-ResourceProperties" {
            # TODO: Complete Tests...
        }
        #endregion

    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion

    # TODO: Other Optional Cleanup Code Goes Here...
}
