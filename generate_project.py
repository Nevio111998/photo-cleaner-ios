#!/usr/bin/env python3
"""Generate a dependency-free Xcode project. Deterministic IDs; Python stdlib only."""
import hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(text): return '"' + str(text).replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = []
def obj(key, body):
    objects.append(f'{uid(key)} = {{ {body} }};')
    return uid(key)
def seq(keys): return '(' + ', '.join(uid(k) for k in keys) + ',)'
apps = sorted(p.name for p in (ROOT / 'PhotoCleaner').glob('*.swift'))
tests = sorted(p.name for p in (ROOT / 'PhotoCleanerTests').glob('*.swift'))
for folder, files in [('PhotoCleaner', apps), ('PhotoCleanerTests', tests)]:
    for f in files:
        key = folder + '/' + f
        obj(key, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(f)}; sourceTree = "<group>";')
        obj('build/' + key, f'isa = PBXBuildFile; fileRef = {uid(key)};')
    obj(folder + 'Group', f'isa = PBXGroup; children = {seq([folder+"/"+f for f in files])}; path = {q(folder)}; sourceTree = "<group>";')
obj('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = PhotoCleaner.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PhotoCleanerTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('products', f'isa = PBXGroup; children = {seq(["appProduct", "testProduct"])}; name = Products; sourceTree = "<group>";')
obj('rootGroup', f'isa = PBXGroup; children = {seq(["PhotoCleanerGroup", "PhotoCleanerTestsGroup", "products"])}; sourceTree = "<group>";')
obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app")}; remoteInfo = PhotoCleaner;')
obj('dependency', f'isa = PBXTargetDependency; target = {uid("app")}; targetProxy = {uid("proxy")};')
for target, folder, files, product, typ in [('app','PhotoCleaner',apps,'appProduct','application'), ('test','PhotoCleanerTests',tests,'testProduct','bundle.unit-test')]:
    obj(target+'Sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {seq(["build/"+folder+"/"+f for f in files])}; runOnlyForDeploymentPostprocessing = 0;')
    for phase in ['Frameworks', 'Resources']:
        obj(target+phase, f'isa = PBX{phase}BuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    deps = seq(['dependency']) if target == 'test' else '()'
    obj(target, f'isa = PBXNativeTarget; buildConfigurationList = {uid(target+"Configs")}; buildPhases = {seq([target+"Sources",target+"Frameworks",target+"Resources"])}; buildRules = (); dependencies = {deps}; name = {folder}; productName = {folder}; productReference = {uid(product)}; productType = "com.apple.product-type.{typ}";')
    for mode in ['Debug', 'Release']:
        settings = {'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.neviodipalma.'+folder,
                    'GENERATE_INFOPLIST_FILE':'YES', 'SWIFT_VERSION':'5.0', 'TARGETED_DEVICE_FAMILY':'1',
                    'IPHONEOS_DEPLOYMENT_TARGET':'16.0', 'CODE_SIGN_STYLE':'Automatic',
                    'MARKETING_VERSION':'1.0.0', 'CURRENT_PROJECT_VERSION':'1', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator'}
        if target == 'app':
            settings.update({'INFOPLIST_KEY_NSPhotoLibraryUsageDescription':'Photo Cleaner analysiert deine Fotos lokal und löscht nur nach deiner ausdrücklichen Bestätigung.',
                             'INFOPLIST_KEY_UILaunchScreen_Generation':'YES',
                             'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES',
                             'INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
                             'INFOPLIST_KEY_CFBundleDisplayName':'Photo Cleaner'})
        else:
            settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/PhotoCleaner.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/PhotoCleaner', 'BUNDLE_LOADER':'$(TEST_HOST)'})
        obj(target+mode, 'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(k+' = '+q(v)+';' for k,v in settings.items())+'};')
    obj(target+'Configs', f'isa = XCConfigurationList; buildConfigurations = {seq([target+"Debug",target+"Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
for mode in ['Debug','Release']:
    settings = {'SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O', 'ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO', 'DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'}
    if mode == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    obj('project'+mode, 'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = {'+' '.join(k+' = '+q(v)+';' for k,v in settings.items())+'};')
obj('projectConfigs', f'isa = XCConfigurationList; buildConfigurations = {seq(["projectDebug","projectRelease"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de, en, Base); mainGroup = {uid("rootGroup")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {seq(["app","test"])};')
(ROOT / 'PhotoCleaner.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
def ref(target, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(target)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:PhotoCleaner.xcodeproj"/>'
app = ref('app','PhotoCleaner','PhotoCleaner.app'); test = ref('test','PhotoCleanerTests','PhotoCleanerTests.xctest')
(ROOT / 'PhotoCleaner.xcodeproj/xcshareddata/xcschemes/PhotoCleaner.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated Xcode project and shared scheme.')
