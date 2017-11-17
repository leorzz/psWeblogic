# psWeblogic

This powershell module is a Wrapper around KeePassLib

## Installation
If you have a version that is less than 3, then you need to update your PowerShell. To update to version 3 or more, you must download the Windows Management Framework 3: http://www.microsoft.com/en-us/download/details.aspx?id=34595 or 5 https://www.microsoft.com/en-us/download/details.aspx?id=50395, then choose either the x86 or the x64 files depending on your system. For x64.

#### Inspect
PS> Save-Module -Name psWeblogic -Path <path>

#### Install
PS> Install-Module -Name psWeblogic

#### Update
PS> Update-Module -Name psWeblogic

Repo: 
[https://www.powershellgallery.com/packages/psWeblogic](https://www.powershellgallery.com/packages/psWeblogic target="_blank")


### or ...

Allow PowerShell to import or use scripts including modules by running the following command:

    set-executionpolicy remotesigned

Install PsGet by executing the following commands:(Skip this if you get WMF 5)

    (new-object Net.WebClient).DownloadString("http://psget.net/GetPsGet.ps1") | iex
    import-module PsGet

### CMDLETs


| Name | Synopsis |
| ------ | ------ |
| Get-WLCacheIndex | Show current cache index. |
| Get-WLChangeManager | Get information about Managing Configuration Changes |
| Get-WLCluster | Get cluster object from a domain. |
| Get-WLCredential | Get weblogic credential stored at default or alternative path. |
| Get-WLDatasource | Get datasource object from a domain. |
| Get-WLDeployment | Get deployment object from a domain. |
| Get-WLDomain | Get domain object. |
| Get-WLjob | Get job object from a domain. |
| Get-WLServer | Get server object from a domain. |
| Get-WLTarget | Get target object from a domain. |
| Invoke-WlstScript | Run python scripts |
| New-WLCredential | Create new credential to AdminServer and store into user profile. |
| New-WLDatasource | Create a new Datasource. |
| New-WLDeployment | Deploy new application or library. |
| New-WLDomain | Create a new weblogic domain into inventory. |
| Remove-WLCredential | Remove weblogic credential stored at default or alternative path. |
| Remove-WLDatasource | Removes an existing datasource. |
| Remove-WLDeployment | Removes an existing deployment. |
| Remove-WLDomain | Removes an existing weblogic domain from inventory. |
| Repair-WLCacheIndex | Rebuild the index cache to current powershell session. |
| Restart-WLServer | Changes the life cycle of the server object to shutdown and then to running. |
| Start-WLServer | Changes the lifecycle of the server object to running. |
| Stop-WLServer | Changes the lifecycle of the server object to shutdown. |

Full documentation at [https://leorzz.github.io/psWeblogic/](https://leorzz.github.io/psWeblogic/).


### Todos
 - Improve features
 - Write MORE Tests

License
----

MIT


**Free Software, Hell Yeah!**

[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)

