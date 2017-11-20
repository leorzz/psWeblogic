connect()
servers = cmo.getServers()
print '==>Server,Port,SSL'
for server in servers:
    print '==>' + server.name + ',' + str(server.getListenPort()) + ',' + str(server.getSSL().getListenPort())
exit()