. $PSScriptRoot\includes.ps1

import-module pester
import-module csproj -DisableNameChecking

$xml = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
  <package id="Microsoft.Bcl" version="1.1.10" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
  <package id="Microsoft.Bcl.Build" version="1.0.14" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
  <package id="Newtonsoft.Json" version="6.0.8" targetFramework="portable-net45+win+wp80+MonoAndroid10+xamarinios10+MonoTouch10" />
</packages>
'@

#TODO: use https://github.com/pester/Pester/wiki/TestDrive 
Describe "packages config manipulation" {
    Context "When loaded from string" {
        $conf = get-packagesconfig $xml
        It "Should load properly" {
           # $conf | Should Not Be $null # BeNullOrEmpty # why does it throw for a valid object? 
           $conf.xml | Should Not BeNullOrEmpty
        }
        
        It "Should List all packages" {
            $conf.packages | Should not BeNullOrEmpty
            $conf.packages.Count | Should Be 3
        }
        
        $ids =  @("Microsoft.Bcl","Microsoft.Bcl.Build", "Newtonsoft.Json")
        
        $cases = $ids | % { @{ Id = $_ } }
        It "Should Contain <id>" -TestCases $cases {
            param($id)
            $conf.packages | ? { $_.Id -eq $id } | Should Not BeNullOrEmpty
        }
    }
    
    Context "When adding new dependency" {
        $conf = get-packagesconfig $xml    
        $id = "Test.Dependency"
        
        It "should contain added id" {
            add-packagetoconfig $id $conf
            $conf.packages | ? { $_.Id -eq $id } | Should Not BeNullOrEmpty            
        }
    }
    
    Context "When adding existing dependency" {
        $conf = get-packagesconfig $xml    
        $id = "Newtonsoft.Json"
        
        It "Should throw by default" {
             { add-packagetoconfig $id $conf } | Should Throw 
        }
        
        It "Should pass when using -ifnotexists" {
             { add-packagetoconfig $id $conf -ifnotexists } | Should Not Throw
        }
        
        It "should contain added id" {
            add-packagetoconfig $id $conf -ifnotexists
            $conf.packages | ? { $_.Id -eq $id } | Should Not BeNullOrEmpty            
        }
    }
    
    Context "When removing dependency" {
        $conf = get-packagesconfig $xml    
        $id = "Newtonsoft.Json"
  
        It "should not contain removed id" {
            remove-packagefromconfig $id $conf
            $conf.packages | ? { $_.Id -eq $id } | Should BeNullOrEmpty            
        }
    }
    
    Context "When removing non-existing dependency" {
        $conf = get-packagesconfig $xml    
        $id = "Test.Dependency"
         
        It "Should throw by default" {
             { remove-packagefromconfig $id $conf } | Should Throw 
        }
    }
    
}