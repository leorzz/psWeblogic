
if len(sys.argv) > 1:
	password = sys.argv[1]
else:
    password = 'weblogic'
    print '\n==> The password to the weblogic user is weblogic.'
    print '==> You can input a custom password to the \'weblogic\' user in first argument.\n'

#@domain_hashtable
try:
    try:
        if not (domain_hashtable['Name'] and domain_hashtable['AdminServer'] and domain_hashtable['MW_HOME']):
            print '==> PARAMETES FAIL.'
            print '==> domainName: ' + domain_hashtable['Name']
            print '==> AdminServer: ' + domain_hashtable['AdminServer']
            print '==> AdminServer: ' + domain_hashtable['MW_HOME']
            exit()
    except Exception,e:
        print '==> Error on input pipeline parameters.'
        print '==> ' + e
        exit()

    print "==> Creating/setting a New Domain named: " + domain_hashtable['Name']
    print "==> Creating/setting a New AdminServer: " + domain_hashtable['AdminServer']
    print "==> AdminServer Url: http://" + domain_hashtable['AdminServer'] + ":" + domain_hashtable['AdminServer'] + "/console"
    
    #Open an existing domain template
    templatePath = domain_hashtable['MW_HOME'] + '\\wlserver\\common\\templates\\wls\\wls.jar'
    if os.path.isfile(templatePath):
        readTemplate(templatePath)
    else:
        print '\n==> Path ' + templatePath + ' is invalid.\n'
        exit(defaultAnswer='y')

    try:
        cd('/')
        cmo.setProductionModeEnabled(true)
        cmo.setInternalAppsDeployOnDemandEnabled(true)
        cmo.setClusterConstraintsEnabled(false)
        cmo.setExalogicOptimizationsEnabled(false)
        cmo.setAdministrationPortEnabled(false)
        print '==> setProductionModeEnabled(true)'
    except Exception,e:
        print '==> ' + e

    try:
        cd('/Servers/AdminServer')
        cmo.setListenAddress(domain_hashtable['AdminServer'])
        cmo.setListenPortEnabled(true)
        cmo.setListenPort(domain_hashtable['AdminTcpPort'])
        print '==> setListenAddress(' + domain_hashtable['AdminServer'] + ')'
        print '==> setListenPortEnabled(true)'
        print '==> setListenPort(' + str(domain_hashtable['AdminTcpPort']) + ')'
    except Exception,e:
        print '==> ' + e

    try:
        #Define the default user password.
        cd('/Security/base_domain/User/weblogic')
        cmo.setPassword(password)
        print '==> setPassword(password)' 
    except Exception,e:
        print '==> ' + e
        

    try:
        #Save the domain.
        setOption('OverwriteDomain', 'false')
        writeDomain(domain_hashtable['MW_HOME'] + '\\user_projects\\domains\\' + domain_hashtable['Name'])
        closeTemplate()
        print '==> Domain saved at ' + domain_hashtable['MW_HOME'] + '\\user_projects\\domains\\' + domain_hashtable['Name']
    except Exception,e:
        print '==> ' + e
   

finally:
    print '==> finally'
    exit(defaultAnswer='y')