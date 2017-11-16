#@domain_hashtable
def getServerInfo():
    #cd('/serverConfig')
    servers = cmo.getServers()
    #edit()
    #startEdit()
    print '==>AdminServer,Name,Arguments,Notes'
    for server in servers:
        try:
            serverName = server.getName()
            cd('/')
            cd("Servers/" + serverName + "/ServerStart/" + serverName)
            print  '==>' + domain_hashtable['AdminServer'] + ',' + serverName + ',' + str(cmo.getArguments()) + ',' + str(cmo.getNotes())
        except Exception, e:
            print  '==>' + domain_hashtable['AdminServer'] + ',' + serverName + ',' + 'erro'
            pass
    #stopEdit('y')
try:
    connect()
    getServerInfo()
finally:
    disconnect()
    exit(defaultAnswer='y')