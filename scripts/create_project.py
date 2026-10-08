from pathlib import Path
import plistlib, json, re
root=Path(__file__).resolve().parents[1]
project=root/'Infometrie.xcodeproj';project.mkdir(exist_ok=True)
# Signing team and build number set in Xcode after the first generation; kept here so a rerun matches the committed project.
TEAM='Q37972BSB3';APP_BUILD='9'
# Stable IDs make the project reproducible without a generator dependency.
ids={k:f'{i:024X}' for i,k in enumerate(['project','main','products','appgroup','testgroup','app','test','appproduct','testproduct','appsources','appresources','appframeworks','testsources','testresources','testframeworks','projectconfig','appconfig','testconfig','projectdebug','projectrelease','appdebug','apprelease','testdebug','testrelease','exception','dependency','proxy'],1)}
def ref(k):return ids[k]
class Ref(str):
 """An object ID that Xcode follows with its target's comment."""
def R(k):return Ref(ids[k])
objects={};comments={}
def obj(k,comment,isa,**fields):objects[ids[k]]={'isa':isa,**fields};comments[ids[k]]=comment
# Xcode writes these object types on a single line.
INLINE={'PBXBuildFile','PBXFileReference','PBXFileSystemSynchronizedRootGroup'}
def q(s):return s if re.fullmatch(r'[A-Za-z0-9_./]+',s) else '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def fmt(v,level=0,inline=False):
 """Serialize a value exactly as Xcode writes project.pbxproj: isa first, sorted keys, quoted strings, tab indentation."""
 if isinstance(v,Ref):return f'{v} /* {comments[v]} */' if comments[v] else str(v)
 if isinstance(v,str):return q(v)
 pad='\t'*level
 if isinstance(v,list):
  if inline:return '('+''.join(fmt(x,inline=True)+', ' for x in v)+')'
  return '(\n'+''.join(f'{pad}\t{fmt(x,level+1)},\n' for x in v)+pad+')'
 keys=sorted(v,key=lambda k:(k!='isa',k))
 if inline:return '{'+''.join(f'{q(k)} = {fmt(v[k],inline=True)}; ' for k in keys)+'}'
 return '{\n'+''.join(f'{pad}\t{q(k)} = {fmt(v[k],level+1)};\n' for k in keys)+pad+'}'
obj('project','Project object','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2700','TargetAttributes':{ref('app'):{'CreatedOnToolsVersion':'27.0'},ref('test'):{'CreatedOnToolsVersion':'27.0','TestTargetID':ref('app')}}},buildConfigurationList=R('projectconfig'),compatibilityVersion='Xcode 16.0',developmentRegion='fr',hasScannedForEncodings='0',knownRegions=['fr','en','Base'],mainGroup=R('main'),productRefGroup=R('products'),projectDirPath='',projectRoot='',targets=[R('app'),R('test')])
obj('main',None,'PBXGroup',children=[R('appgroup'),R('testgroup'),R('products')],sourceTree='<group>')
obj('products','Products','PBXGroup',children=[R('appproduct'),R('testproduct')],name='Products',sourceTree='<group>')
obj('appgroup','Infometrie','PBXFileSystemSynchronizedRootGroup',exceptions=[R('exception')],explicitFileTypes={f'Fixtures/fixture-audio-{i:02}.ts':'video.mpeg' for i in range(7)},explicitFolders=[],path='Infometrie',sourceTree='<group>')
obj('testgroup','InfometrieUITests','PBXFileSystemSynchronizedRootGroup',explicitFileTypes={},explicitFolders=[],path='InfometrieUITests',sourceTree='<group>')
obj('exception','PBXFileSystemSynchronizedBuildFileExceptionSet','PBXFileSystemSynchronizedBuildFileExceptionSet',membershipExceptions=['Resources/Info.plist'],target=R('app'))
for target,name,group,product,kind in [('app','Infometrie','appgroup','appproduct','application'),('test','InfometrieUITests','testgroup','testproduct','bundle.ui-testing')]:
 file=f'{name}.{"app" if target=="app" else "xctest"}'
 obj(product,file,'PBXFileReference',explicitFileType='wrapper.application' if target=='app' else 'wrapper.cfbundle',includeInIndex='0',path=file,sourceTree='BUILT_PRODUCTS_DIR')
 for suffix,isa in [('sources','PBXSourcesBuildPhase'),('resources','PBXResourcesBuildPhase'),('frameworks','PBXFrameworksBuildPhase')]:obj(target+suffix,suffix.capitalize(),isa,buildActionMask='2147483647',files=[],runOnlyForDeploymentPostprocessing='0')
 obj(target,name,'PBXNativeTarget',buildConfigurationList=R(target+'config'),buildPhases=[R(target+'sources'),R(target+'frameworks'),R(target+'resources')],buildRules=[],dependencies=[R('dependency')] if target=='test' else [],fileSystemSynchronizedGroups=[R(group)],name=name,productName=name,productReference=R(product),productType=f'com.apple.product-type.{kind}')
obj('proxy','PBXContainerItemProxy','PBXContainerItemProxy',containerPortal=R('project'),proxyType='1',remoteGlobalIDString=ref('app'),remoteInfo='Infometrie')
obj('dependency','PBXTargetDependency','PBXTargetDependency',target=R('app'),targetProxy=R('proxy'))
for prefix,owner in [('project','PBXProject "Infometrie"'),('app','PBXNativeTarget "Infometrie"'),('test','PBXNativeTarget "InfometrieUITests"')]:
 obj(prefix+'config',f'Build configuration list for {owner}','XCConfigurationList',buildConfigurations=[R(prefix+'debug'),R(prefix+'release')],defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
 for mode in ['debug','release']:
  common={'IPHONEOS_DEPLOYMENT_TARGET':'26.0','SDKROOT':'iphoneos','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
  if prefix=='project':
   settings=common|{'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='debug' else 'dwarf-with-dsym','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)' if mode=='debug' else '$(inherited)'}
  else:
   settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'fr.yacast.infometrie.ios'+('.uitests' if prefix=='test' else ''),'TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.4.0','GENERATE_INFOPLIST_FILE':'YES' if prefix=='test' else 'NO','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','SWIFT_EMIT_LOC_STRINGS':'YES'}
   if prefix=='app':
    settings|={'INFOPLIST_FILE':'Infometrie/Resources/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks'],'CURRENT_PROJECT_VERSION':APP_BUILD,'DEVELOPMENT_TEAM':TEAM}
    # The UI-test media only serves the Debug test server; a release ships without it.
    if mode=='release':settings['EXCLUDED_SOURCE_FILE_NAMES']='fixture-audio-*.ts'
   else:settings|={'TEST_TARGET_NAME':'Infometrie','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks','@loader_path/Frameworks']}
  obj(prefix+mode,mode.capitalize(),'XCBuildConfiguration',buildSettings=settings,name=mode.capitalize())
def line(k):
 o=objects[k]
 return f'\t\t{fmt(Ref(k))} = {fmt(o,inline=True) if o["isa"] in INLINE else fmt(o,2)};\n'
sections=''.join(f'\n/* Begin {isa} section */\n'+''.join(line(k) for k in sorted(objects) if objects[k]['isa']==isa)+f'/* End {isa} section */\n' for isa in sorted({o['isa'] for o in objects.values()}))
project.joinpath('project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 71;\n\tobjects = {\n'+sections+f'\t}};\n\trootObject = {fmt(R("project"))};\n}}\n')
scheme=project/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
def buildref(k,name,file):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(k)}" BuildableName="{file}" BlueprintName="{name}" ReferencedContainer="container:Infometrie.xcodeproj"/>'
scheme.joinpath('Infometrie.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref('app','Infometrie','Infometrie.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildref('test','InfometrieUITests','InfometrieUITests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('app','Infometrie','Infometrie.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('app','Infometrie','Infometrie.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
info={'CFBundleDevelopmentRegion':'fr','CFBundleDisplayName':'InfoMétrie','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UILaunchScreen':{},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'NSAppTransportSecurity':{'NSAllowsLocalNetworking':True},'ITSAppUsesNonExemptEncryption':False}
(root/'Infometrie/Resources/Info.plist').write_bytes(plistlib.dumps(info))
assets=root/'Infometrie/Resources/Assets.xcassets';assets.mkdir(exist_ok=True)
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
# The app icon is the Icon Composer document Resources/AppIcon.icon, written by scripts/make_app_icon.swift.
accent=assets/'AccentColor.colorset';accent.mkdir(exist_ok=True)
def srgb(red,green,blue):return {'color-space':'srgb','components':{'red':red,'green':green,'blue':blue,'alpha':'1.0'}}
(accent/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':srgb('0x12','0x11','0x10')},{'idiom':'universal','color':srgb('0xF5','0xF3','0xF0'),'appearances':[{'appearance':'luminosity','value':'dark'}]}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
print('Projet Xcode et ressources créés.')
