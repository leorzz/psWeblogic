# Leonardo Rizzi
# use example
# java weblogic.WLST setTargetDataSource.py <datasource part> <target>
# java weblogic.WLST setTargetDataSource.py t1ginternet bi-desenv


if len(sys.argv) <  3:
    print("Use two Arguments:\nInvoke-WlstScript -BuiltInScript Set-DatasourceTarget.py -Arguments [datasource wildcard],[target] -AdminServer [Adminserver Name]")
    print("\nExample:\nInvoke-WlstScript -BuiltInScript Set-DatasourceTarget.py -Arguments jdbc01*,target01 -AdminServer admin01.domain.local")
    exit()

if len(sys.argv) == 3:
    dsPattern = str(sys.argv[1])
    target = str(sys.argv[2])

connect()

cmgr = getConfigManager()
user = cmgr.getCurrentEditor()
try:
    if cmgr.isEditor() == true:
        print '>>> Editado por: ' + cmgr.getCurrentEditor()
        cmgr.stopEdit()
        #exit()
except Exception:
    print '===> Error.'
    exit()       

edit()
startEdit()
cd('JDBCSystemResources')
allDS=cmo.getJDBCSystemResources()

from fnmatch import fnmatch, fnmatchcase
my_list = [ds for ds in allDS if fnmatch(ds.getName(), dsPattern)]

print '==>Name,Target,Status'
for tmpDS in my_list:
    dsName=tmpDS.getName()
    cd("/")
    if(target):
        #print 'Setting target ' + target + ' to ' + dsName
        try:
            cd('/Clusters/' + target)
            target1=cmo
            cd("/")
            cd ("/JDBCSystemResources")
            dataSourceBean = getMBean(dsName)
            dataSourceBean.addTarget(target1)
            #dataSourceBean.removeTarget(target1)
            cd ("/JDBCSystemResources/" + dsName)
            dsTargets = cmo.getTargets()
            arrDsTargets = [t.name for t in dsTargets]
            #print '==>' + dsName + ',' + (arrDsTargets) + ',Ok'
            print '==>' + dsName + ',' + ' '.join(arrDsTargets) + ',Ok'
        except Exception, e:
            print '==>' + dsName + ',' + target + ',Fail'
            dumpStack()
    else:
        print '==>' + dsName + ',' + 'none'
        #print('Setting target  --NOTTING--  to ' + dsName)
save()
activate()
