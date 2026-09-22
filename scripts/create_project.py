from pathlib import Path
import plistlib, json, wave, math, struct
root=Path(__file__).resolve().parents[1]
project=root/'Infometrie.xcodeproj';project.mkdir(exist_ok=True)
# Stable IDs make the project reproducible without a generator dependency.
ids={k:f'{i:024X}' for i,k in enumerate(['project','main','products','appgroup','testgroup','app','test','appproduct','testproduct','appsources','appresources','appframeworks','testsources','testresources','testframeworks','projectconfig','appconfig','testconfig','projectdebug','projectrelease','appdebug','apprelease','testdebug','testrelease','exception','dependency','proxy'],1)}
def ref(k):return ids[k]
objects=[]
def obj(k,body):objects.append(f'{ref(k)} = {{ {body} }};')
def config(k,settings):obj(k,'isa = XCBuildConfiguration; buildSettings = { '+ ' '.join(f'{key} = {value};' for key,value in settings.items())+' }; name = '+('Debug' if 'debug' in k else 'Release')+';')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {{ {ref("app")} = {{ CreatedOnToolsVersion = 27.0; }}; {ref("test")} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {ref("app")}; }}; }}; }}; buildConfigurationList = {ref("projectconfig")}; compatibilityVersion = "Xcode 16.0"; developmentRegion = fr; knownRegions = (fr, en, Base); mainGroup = {ref("main")}; productRefGroup = {ref("products")}; projectDirPath = ""; projectRoot = ""; targets = ({ref("app")}, {ref("test")});')
obj('main',f'isa = PBXGroup; children = ({ref("appgroup")}, {ref("testgroup")}, {ref("products")}); sourceTree = "<group>";')
obj('products',f'isa = PBXGroup; children = ({ref("appproduct")}, {ref("testproduct")}); name = Products; sourceTree = "<group>";')
segment_types=' '.join(f'\"Resources/demo-segment-{i:02}.ts\" = \"video.mpeg\";' for i in range(7))
obj('appgroup',f'isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {{{segment_types}}}; exceptions = ({ref("exception")}); path = Infometrie; sourceTree = "<group>";')
obj('testgroup','isa = PBXFileSystemSynchronizedRootGroup; path = InfometrieUITests; sourceTree = "<group>";')
obj('exception',f'isa = PBXFileSystemSynchronizedBuildFileExceptionSet; membershipExceptions = (Resources/Info.plist); target = {ref("app")};')
for target,name,group,product in [('app','Infometrie','appgroup','appproduct'),('test','InfometrieUITests','testgroup','testproduct')]:
 obj(product,f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if target=="app" else "wrapper.cfbundle"}; includeInIndex = 0; path = {name}.{ "app" if target=="app" else "xctest"}; sourceTree = BUILT_PRODUCTS_DIR;')
 for suffix,isa in [('sources','PBXSourcesBuildPhase'),('resources','PBXResourcesBuildPhase'),('frameworks','PBXFrameworksBuildPhase')]:obj(target+suffix,f'isa = {isa}; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
 obj(target,f'isa = PBXNativeTarget; buildConfigurationList = {ref(target+"config")}; buildPhases = ({ref(target+"sources")}, {ref(target+"frameworks")}, {ref(target+"resources")}); buildRules = (); dependencies = ({ref("dependency") if target=="test" else ""}); fileSystemSynchronizedGroups = ({ref(group)}); name = {name}; productName = {name}; productReference = {ref(product)}; productType = "com.apple.product-type.{"application" if target=="app" else "bundle.ui-testing"}";')
obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {ref("project")}; proxyType = 1; remoteGlobalIDString = {ref("app")}; remoteInfo = Infometrie;')
obj('dependency',f'isa = PBXTargetDependency; target = {ref("app")}; targetProxy = {ref("proxy")};')
for prefix in ['project','app','test']:
 obj(prefix+'config',f'isa = XCConfigurationList; buildConfigurations = ({ref(prefix+"debug")}, {ref(prefix+"release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
 for mode in ['debug','release']:
  common={'IPHONEOS_DEPLOYMENT_TARGET':'26.0','SDKROOT':'iphoneos','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
  if prefix=='project':
   settings=common|{'SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if mode=='debug' else '"-O"','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='debug' else '"dwarf-with-dsym"','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'"DEBUG $(inherited)"' if mode=='debug' else '"$(inherited)"'}
  else:
   name='Infometrie' if prefix=='app' else 'InfometrieUITests'
   settings={'PRODUCT_NAME':'"$(TARGET_NAME)"','PRODUCT_BUNDLE_IDENTIFIER':'fr.yacast.infometrie.ios'+('.uitests' if prefix=='test' else ''),'TARGETED_DEVICE_FAMILY':'"1,2"','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.4.0','GENERATE_INFOPLIST_FILE':'YES' if prefix=='test' else 'NO','SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"','SUPPORTS_MACCATALYST':'NO','SWIFT_EMIT_LOC_STRINGS':'YES'}
   if prefix=='app':settings|={'INFOPLIST_FILE':'Infometrie/Resources/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','LD_RUNPATH_SEARCH_PATHS':'"$(inherited) @executable_path/Frameworks"'}
   else:settings|={'TEST_TARGET_NAME':'Infometrie','LD_RUNPATH_SEARCH_PATHS':'"$(inherited) @executable_path/Frameworks @loader_path/Frameworks"'}
  config(prefix+mode,settings)
project.joinpath('project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 77; objects = {\n'+ '\n'.join(objects)+f'\n}}; rootObject = {ref("project")}; }}\n')
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
icon=assets/'AppIcon.appiconset';icon.mkdir(exist_ok=True)
(icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
accent=assets/'AccentColor.colorset';accent.mkdir(exist_ok=True)
(accent/'Contents.json').write_text(json.dumps({'colors':[{'idiom':'universal','color':{'color-space':'srgb','components':{'red':'0.19','green':'0.28','blue':'0.87','alpha':'1.0'}}}],'info':{'author':'xcode','version':1}}))
with wave.open(str(root/'Infometrie/Resources/demo.wav'),'wb') as w:
 w.setnchannels(1);w.setsampwidth(2);w.setframerate(22050)
 notes=[261.63,329.63,392,523.25,392,329.63]
 data=bytearray()
 for i in range(22050*18):
  t=i/22050;phase=t%1.5;frequency=notes[int(t/1.5)%len(notes)]
  envelope=min(1,phase/0.04)*math.exp(-phase*2.4)*min(1,(18-t)/0.3)
  value=int(3200*envelope*(math.sin(2*math.pi*frequency*t)+0.22*math.sin(4*math.pi*frequency*t)))
  data.extend(struct.pack('<h',value))
 w.writeframes(data)
print('Projet Xcode et ressources créés.')
