function Copy-BindingRedirects {
    [CmdletBinding()]
    param($from = "app.config", $to = $null)
        $fromXml = [xml](get-content $from)

        if ([System.IO.Directory]::Exists($from)) {
            $webconfig = get-childitems $from -filter "web.config"
            if ($webconfig -ne $null) {
                $from = $webconfig.FullName
            } else {
                $appconfig = get-childitems $from -filter "app.config"
                if ($appconfig -ne $null) {
                    $from = $appconfig.FullName
                }
            }
        }
        if ($to -eq $null) {
            $from_file = [System.io.path]::GetFileNameWithoutExtension($from)
            $from_file_ext = [System.io.path]::GetExtension($from)
            $to_file = "$from_file.orig$from_file_ext"
            $to = join-path (split-path -Parent $from) $to_file 
        }
        $toXml = [xml](get-content $to)

        $src = $fromxml.configuration.runtime.assemblyBinding
        
        $runtime = $toxml.SelectNodes('//configuration/runtime') | select -first 1
        if ($runtime -eq $null) {
            write-verbose "adding 'runtime' node to $to"
            $node = [System.Xml.XmlElement]$toxml.CreateElement("runtime")            
            $null = $toxml.configuration.AppendChild($node) 
            $runtime = $toxml.SelectNodes('//configuration/runtime') | select -first 1
        }
        if ($toxml.configuration.runtime.assemblyBinding -ne $null) {
            write-verbose "removing old assemblyBinding section from $to"
            $null = $toxml.configuration.runtime.RemoveChild($toxml.configuration.runtime.assemblyBinding)
        }

        write-verbose "copying assemblyBinding section from $from to $to"
        
        $node = $toxml.ImportNode($src, $true)
        $null = $runtime.AppendChild($node)

        $toXml.OuterXml | out-string | write-verbose 
    
        write-verbose "saving $to"
        $null = $toXml.Save((get-item $to).FullName)

}

function add-packagetoconfig {
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$packagesconfig,
    [Parameter(Mandatory=$true)][string]$package, 
    [Parameter(Mandatory=$true)][string]$version,
    [switch][bool] $ifnotexists
) 
    $existing = $packagesconfig.packages | ? { $_.Id -eq $package } 
    if ($existing -ne $null) {
        if ($ifnotexists) { return }
        else { 
            throw "Packages.config already contains reference to package $package : $($existing | out-string)" 
        }
    } 

    $node = new-packageNode -document $packagesconfig.xml
    $node.id = $package
    $node.version = $version
    $null = $packagesconfig.xml.DocumentElement.AppendChild($node) 
    
    $packagesconfig.packages = $packagesconfig.xml.packages.package
}

function remove-packagefromconfig {
param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$packagesconfig,
    [Parameter(Mandatory=$true)][string]$package
    ) 
    $existing = $packagesconfig.packages | ? { $_.Id -eq $package } 
    if ($existing -ne $null) {
        $packagesconfig.xml.packages
        $xmlel = ([System.Xml.XmlElement]$packagesconfig.xml.packages)
        $null = $xmlel.RemoveChild($existing)
        $packagesconfig.packages = $packagesconfig.xml.packages.package
    }
    else {
        throw "package $package not found in packages.config"
    }
}

function set-packagesconfig {
    param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$pkgconfig,    
    [Parameter(Mandatory=$true)]$outfile
    )

    if ($pkgconfig.xml -eq $null) {
        throw "please provide a pkgconfig object from get-packagesconfig"
    }
    if (!([system.io.path]::IsPathRooted($outfile))) {
        $outfile = join-path (get-item ".").FullName $outfile
    }
    $pkgconfig.xml.Save($outfile)
}

function get-packagesconfig {
    param(
    [Parameter(Mandatory=$true)]$packagesconfig,
    [switch][bool] $createifnotexists
    )
    if ($packagesconfig.startswith('<?xml')) {
        $xml = [xml]$packagesconfig
    }
    else {
        if ($packagesconfig.EndsWith('.csproj')) {
            $dir = split-path -parent $packagesconfig
            $packagesconfig = "$dir/packages.config"
        }
        if (test-path $packagesconfig) {
            $c = get-content $packagesconfig | Out-String
            $xml = [xml]$c
        } 
        elseif ($createifnotexists) {
            $content = @'
<?xml version="1.0" encoding="utf-8"?>
<packages>
</packages>
'@
            $content | out-file $packagesconfig -encoding utf8
            $xml = [xml]$content
        }
    }
    
    if ($xml.packages -is [string]) {
        # weird, when <packages> are empty, .packages is a string!
    }
    
    $obj = new-object -type pscustomobject -Property @{ packages = $xml.packages.package; xml = $xml } 
    return $obj
}


function new-packageNode([Parameter(Mandatory=$true, ValueFromPipeline=$true)][System.Xml.xmldocument]$document) {

    $package = [System.Xml.XmlElement]$document.CreateElement("package")
    $null = $package.Attributes.Append([System.Xml.XmlAttribute]$document.CreateAttribute("id"))
    $null = $package.Attributes.Append($document.CreateAttribute("targetFramework"))
    $null = $package.Attributes.Append($document.CreateAttribute("version"))

    return $package
}

