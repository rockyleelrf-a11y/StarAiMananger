import os
import uuid

def make_uuid():
    return uuid.uuid4().hex[:24].upper()

project_dir = os.path.abspath("StarButlerCompanion")
xcodeproj_dir = os.path.join(project_dir, "StarButlerCompanion.xcodeproj")
os.makedirs(xcodeproj_dir, exist_ok=True)

# Generate stable UUIDs
ID_PROJECT = "A10000000000000000000001"
ID_MAIN_GROUP = "A10000000000000000000002"
ID_SOURCES_GROUP = "A10000000000000000000003"
ID_PRODUCTS_GROUP = "A10000000000000000000004"
ID_TARGET = "A10000000000000000000005"
ID_SOURCES_BUILD_PHASE = "A10000000000000000000006"
ID_FRAMEWORKS_BUILD_PHASE = "A10000000000000000000007"
ID_RESOURCES_BUILD_PHASE = "A10000000000000000000008"
ID_PRODUCT_FILE = "A10000000000000000000009"
ID_CONFIG_LIST_PROJ = "A10000000000000000000010"
ID_CONFIG_PROJ_DEBUG = "A10000000000000000000011"
ID_CONFIG_PROJ_RELEASE = "A10000000000000000000012"
ID_CONFIG_LIST_TARGET = "A10000000000000000000013"
ID_CONFIG_TARGET_DEBUG = "A10000000000000000000014"
ID_CONFIG_TARGET_RELEASE = "A10000000000000000000015"

sources = [
    ("StarButlerCompanionApp.swift", "StarButlerCompanionApp.swift"),
    ("CompanionAgent.swift", "Models/CompanionAgent.swift"),
    ("CompanionClient.swift", "Services/CompanionClient.swift"),
    ("CompanionAgentCard.swift", "Views/CompanionAgentCard.swift"),
    ("CompanionConnectionSheet.swift", "Views/CompanionConnectionSheet.swift"),
    ("CompanionDashboardView.swift", "Views/CompanionDashboardView.swift")
]

file_refs = []
build_files = []
for i, (name, path) in enumerate(sources):
    f_uuid = f"A100000000000000000001{i:02d}"
    b_uuid = f"A100000000000000000002{i:02d}"
    file_refs.append((f_uuid, name, path))
    build_files.append((b_uuid, f_uuid, name))

file_ref_entries = []
for f_uuid, name, path in file_refs:
    file_ref_entries.append(f'\t\t{f_uuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};')

build_file_entries = []
sources_build_file_refs = []
for b_uuid, f_uuid, name in build_files:
    build_file_entries.append(f'\t\t{b_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_uuid} /* {name} */; }};')
    sources_build_file_refs.append(f'\t\t\t\t{b_uuid} /* {name} in Sources */,')

sources_group_children = []
for f_uuid, name, path in file_refs:
    sources_group_children.append(f'\t\t\t\t{f_uuid} /* {name} */,')

pbxproj_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_file_entries)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t{ID_PRODUCT_FILE} /* StarButler.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = StarButler.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{chr(10).join(file_ref_entries)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{ID_FRAMEWORKS_BUILD_PHASE} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{ID_MAIN_GROUP} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ID_SOURCES_GROUP} /* Sources */,
\t\t\t\t{ID_PRODUCTS_GROUP} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ID_SOURCES_GROUP} /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(sources_group_children)}
\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{ID_PRODUCTS_GROUP} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{ID_PRODUCT_FILE} /* StarButler.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{ID_TARGET} /* StarButlerCompanion */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {ID_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "StarButlerCompanion" */;
\t\t\tbuildPhases = (
\t\t\t\t{ID_SOURCES_BUILD_PHASE} /* Sources */,
\t\t\t\t{ID_FRAMEWORKS_BUILD_PHASE} /* Frameworks */,
\t\t\t\t{ID_RESOURCES_BUILD_PHASE} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = StarButlerCompanion;
\t\t\tproductName = StarButler;
\t\t\tproductReference = {ID_PRODUCT_FILE} /* StarButler.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{ID_PROJECT} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastUpgradeCheck = 1520;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{ID_TARGET} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;
\t\t\t\t\t\tDevelopmentTeam = 27U66JUTXQ;
\t\t\t\t\t\tProvisioningStyle = Automatic;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {ID_CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "StarButlerCompanion" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = zh_CN;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t\tzh-Hans,
\t\t\t);
\t\t\tmainGroup = {ID_MAIN_GROUP};
\t\t\tproductRefGroup = {ID_PRODUCTS_GROUP} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{ID_TARGET} /* StarButlerCompanion */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{ID_RESOURCES_BUILD_PHASE} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{ID_SOURCES_BUILD_PHASE} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(sources_build_file_refs)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{ID_CONFIG_PROJ_DEBUG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ID_CONFIG_PROJ_RELEASE} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = "wholemodule";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{ID_CONFIG_TARGET_DEBUG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = 27U66JUTXQ;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "StarButler";
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = "StarButler 需要访问本地局域网以同步监控 Mac 上的 AI 智能体状态";
\t\t\t\tINFOPLIST_KEY_NSBonjourServices = "_starbutler._tcp";
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.rockylee.StarButlerCompanion";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{ID_CONFIG_TARGET_RELEASE} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = 27U66JUTXQ;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "StarButler";
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_NSLocalNetworkUsageDescription = "StarButler 需要访问本地局域网以同步监控 Mac 上的 AI 智能体状态";
\t\t\t\tINFOPLIST_KEY_NSBonjourServices = "_starbutler._tcp";
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "com.rockylee.StarButlerCompanion";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{ID_CONFIG_LIST_PROJ} /* Build configuration list for PBXProject "StarButlerCompanion" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ID_CONFIG_PROJ_DEBUG} /* Debug */,
\t\t\t\t{ID_CONFIG_PROJ_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{ID_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "StarButlerCompanion" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{ID_CONFIG_TARGET_DEBUG} /* Debug */,
\t\t\t\t{ID_CONFIG_TARGET_RELEASE} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {ID_PROJECT} /* Project object */;
}}
"""

with open(os.path.join(xcodeproj_dir, "project.pbxproj"), "w") as f:
    f.write(pbxproj_content)

print(f"==> Generated {xcodeproj_dir}")
