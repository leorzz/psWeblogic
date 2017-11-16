from java.io import FileInputStream
from weblogic.management.security.authentication import UserReaderMBean
from weblogic.management.security.authentication import GroupReaderMBean
from weblogic.management.security.authentication import MemberGroupListerMBean
from sys import exit

userNameWildcard='*'
maximumToReturn=0
showAllAuthenticatorUserList=false


if len(sys.argv) > 1:
	userNameWildcard = sys.argv[1]
else:
	print "==> You need specify a argument (wildcard name) to userName."
	print "==> Use: Get-WLDomain -AdminServer fqdn_adminserver | Invoke-WlstScript -BuildinScript Get-UserMemberOf.py -Arguments user01* | fl"QQ
	exit()

connect()
realmName=cmo.getSecurityConfiguration().getDefaultRealm()
#realmName=cmo.getSecurityConfiguration().getDefaultRealm().lookupAuthenticationProvider("ActiveDirectoryAuthenticator_DPOATJ1")
authProvider = realmName.getAuthenticationProviders()
 
for i in authProvider:
	if isinstance(i,UserReaderMBean):
		userName = i
		userReader1 = i
		authName= i.getName()
		try:
			userList = i.listUsers(str(userNameWildcard),int(maximumToReturn))
		except:
			print 'Erro on ' + authName
			print "Unexpected error:", sys.exc_info()[0]
			continue
		print '======================================================================'
		print 'Below are the List of USERS which are in the: "'+authName+'"'
		print '======================================================================'
		num=1
		while userName.haveCurrent(userList):
			cursor1=i.listMemberGroups(userName.getCurrentName(userList))
			print userName.getCurrentName(userList)
			while userReader1.haveCurrent(cursor1):
				print ' --- '+userReader1.getCurrentName(cursor1)
				userReader1.advance(cursor1)
				#userReader1.close(cursor1)
			userName.advance(userList)
		num=num+1
		print '======================================================================'
		userName.close(userList)
