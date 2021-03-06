### Script to reactivate and update former user in AD using MS's AD cmdlts ###
### Author: ChrisZ-IT ###
### Version: 2.2 ###
### Created 05.02.2019; Updated: 06.04.2019 ###

#Removes any defined variables from other scripts run before this
    Remove-Variable * -ErrorAction SilentlyContinue

#Imports MS's AD cmdlets
    Import-Module ActiveDirectory

#Imports CSV file
Import-Csv $env:userprofile\Desktop\NewUsers.csv | ForEach-Object {

#Checks to see if the user exists and is disabled.
$Rehire = Get-ADUser -filter {Enabled -eq $false} -SearchBase "OU=Term Accounts,DC=domain1,DC=com" -Server DC1.domain1.com | where Name -eq $_.'Name'
if ($Rehire.Name -ne $_.'Name')
{
   Write-Host "User" $_.'Name' "is NOT disabled or in the Termed OU. User is probably transfering departments"
   "Script Stoped"
   Break
 }
Else
{
Write-Host -BackgroundColor Black -ForegroundColor Green  "Re-Enabling and updating AD Account Info for"$_.Name

$userPrinc = $_."Username" + "@domain1.com"

#Cleans up old AD groups from rehire if this was not done when they were termed.

#Removing User from all groups on domain1 Domain
Write-Host -BackgroundColor Black -ForegroundColor Green  "Removing" $DN.Name "from domain1 Groups"
        $user = Get-ADUser $_."Username" -Server DC1.domain1.com 
        $domain1Groups = Get-ADPrincipalGroupMembership -Identity $DN -Server DC1.domain1.com | Where name -ne 'domain users' 

    ForEach ($g in $domain1Groups){
        Remove-ADPrincipalGroupMembership -Identity $DN.SID -MemberOf $g.SID -Server DC1.domain1.com -Confirm:$false > $null
        Write-Host "     " -NoNewline; Write-Host -BackgroundColor White -ForegroundColor Black  "Removing from" $g.GroupType $g.ClassName -NoNewline ; write-host -BackgroundColor white -ForegroundColor blue $g.Name ""
        

    }

#Removing User from all groups on domain2 Domain
    Write-Host -BackgroundColor Black -ForegroundColor Green  "Removing" $DN.Name "from domain2 Groups"
    Sleep 2
        $user = Get-ADUser $_."Username" -Server DC1.domain1.com 
        $domain2Groups = Get-ADPrincipalGroupMembership -Identity $DN.SID -Server DC1.domain1.com -ResourceContextServer DC1.domain2.com

    Foreach ($g in $domain2Groups){
        Remove-ADGroupMember -Members $user -Identity $g.SamAccountName -Server DC1.domain2.com -Confirm:$false > $null
        Write-Host "     " -NoNewline; Write-Host -BackgroundColor White -ForegroundColor Black  "Removing from" $g.GroupType $g.ClassName -NoNewline ; write-host -BackgroundColor white -ForegroundColor blue $g.Name ""
        
    }


#Re-enables AD Account and Set Info

$Secure_String_Pwd = ConvertTo-SecureString "Enter_Temp_AD_Password_Here" -AsPlainText -Force

Write-Host -BackgroundColor Black -ForegroundColor Green  "Setting AD account info for"$_.Name
 Set-ADUser -Server DC1.domain1.com -Identity $_.'Username' `
    -Description $_.'Title' `
    -EmailAddress $_.'Email' `
    -Title $_.'Title' `
    -Department $_.'Department' `
    -Office $_.'Office' `
    -Company 'Company Name' `
    -Enabled $True `
    -ChangePasswordAtLogon $True `
    -HomePage http://domain1.com/ 
Set-ADUser -Server DC1.domain1.com -Identity $_.'Username' `
    -Manager $_.'Manager' 

#Unlocks AD account
Unlock-ADAccount –Identity $_.'Username'

#Resets Password
Set-ADAccountPassword -Reset -NewPassword $Secure_String_Pwd -Identity $_.'Username'

#Moves user out of Termed user OU
Get-ADUser $_.'Username' | Move-ADObject -TargetPath $_."OU"

Sleep 2

#Adds User to Groups on domain1 Domain
    Write-Host -BackgroundColor Black -ForegroundColor Green  "Adding user to similar user's domain1 groups (An error means similar users's name is wrong or is on domain2 domain)"
        $existinguser = Get-ADUser -Filter "Name -like '$($_.'SimilarUser')'" -Server DC1.domain1.com
        $newuser = Get-ADUser $_."Username" -Server DC1.domain1.com 
        $domain1Groups = Get-ADPrincipalGroupMembership $existinguser -Server DC1.domain1.com | Where name -ne 'domain users' | Where name -NE 'Enterprise Admins'| Where Name -NE 'Domain Admins'| Where name -NE 'Schema Admins'

    ForEach ($g in $domain1Groups){
        Add-ADPrincipalGroupMembership -Identity $newuser -MemberOf $g.SID -Server DC1.domain1.com -Confirm:$false > $null
        Write-Host "     " -NoNewline; Write-Host -BackgroundColor White -ForegroundColor Black  "Adding" $newuser.Name "to" $g.GroupType $g.ClassName -NoNewline ; write-host -BackgroundColor white -ForegroundColor blue $g.Name ""
        

    }

#Adds User to groups on domain2 Domain
    Write-Host -BackgroundColor Black -ForegroundColor Green  "Adding user to similar users's domain2 groups (An error means no domain2 groups)"
        $existinguser = Get-ADUser -Filter "Name -Like '$($_.'SimilarUser')'" -Server DC1.domain1.com
        $newuser = Get-ADUser -Identity $_."Username" -Server DC1.domain1.com
        $domain2Groups =  Get-ADPrincipalGroupMembership $existinguser -Server DC1.domain1.com -ResourceContextServer DC1.domain2.com | Where name -NE 'domain users' | Where name -NE 'Enterprise Admins'| Where Name -NE 'Domain Admins'| Where name -ne 'Schema Admins'

    Foreach ($g in $domain2Groups){
        Add-ADGroupMember -Identity $g  -Members $newuser -Server DC1.domain2.com
        Write-Host "     " -NoNewline; Write-Host -BackgroundColor White -ForegroundColor Black  "Adding" $newuser.Name "to" $g.GroupType $g.ClassName -NoNewline ; write-host -b white -f blue $g.Name ""
        
    }
#Sends Email to helpdesk To update ticket
    Write-Host -BackgroundColor Black -ForegroundColor Green  "Updating New Hire Ticket. Ticket# "+ $_.'Request ID'
    
    $From = 'admin@domain1.com'
    $To = 'helpme@domain1.com'
    $Subject = ("ServiceDesk - Comment added to Request ID "+$_.'Request ID')
    $Body = $_.'HD Info'
    $SMTPServer = 'smtp.domain1.com'

Send-MailMessage -To $To -From $From -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer

#Logs Rehire user to network logfile
    Write-Host -BackgroundColor Black -ForegroundColor Green  "Logging re-enableing of Rehire"
    Get-ADUser $_."Username" -Server DC1.domain1.com -Properties *|
    Select-Object -property @{N='Date Created';E={$_.whenCreated}}, @{N='Name';E={$_.Name}}, @{N='Username';E={$_.Samaccountname}}, @{N='Domain';E={"domain1"}}|
    Export-Csv -path '\\fileserver\Share\AD Logs\NewUser.csv' -NoTypeInformation -Append
    

#Lets admin know script is done running for selected user
    Write-host -BackgroundColor Black -ForegroundColor Green "AD account for"$_.Name "has been re-enabled"

#Clears defined varibals getting script ready to be run again
Remove-Variable * -ErrorAction SilentlyContinue
}
}
