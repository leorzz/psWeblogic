#@domain_hashtable
def getServerInfo():
    domainConfig()
    serverNames = cmo.getServers()
    domainRuntime()
    print '==>AdminServer,Name,JavaVersion'
    for name in serverNames:
        try:
            serverName = name.getName()
            cd('/ServerLifeCycleRuntimes/' + serverName)
            state = cmo.getState()
            if state == "SHUTDOWN":
                print  '==>' + domain_hashtable['AdminServer'] + ',' + serverName + ',' + 'SHUTDOWN'
            else:                
                cd("/ServerRuntimes/" + serverName + "/JVMRuntime/" + serverName)
                print  '==>' + domain_hashtable['AdminServer'] + ',' + serverName + ',' + cmo.getJavaVersion()
        except Exception, e:
            print  '==>' + domain_hashtable['AdminServer'] + ',' + serverName + ',' + e
            pass

try:
    connect()
    getServerInfo()
finally:
    disconnect()
    exit(defaultAnswer='y')