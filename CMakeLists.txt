cmake_minimum_required(VERSION 3.21)

project(HungrySnake
    VERSION 0.1.0
    DESCRIPTION "A smooth, jungle-themed take on the classic Snake"
    HOMEPAGE_URL "https://ktechpit.com"
    LANGUAGES CXX)

# ── Single source of truth for the reverse-DNS app id ─────────────────────────
set(SN_APP_ID   "com.ktechpit.hungrysnake")
set(SN_APP_NAME "Hungry Snake")

# ── Project-wide build settings ───────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
        Debug Release RelWithDebInfo MinSizeRel)
endif()

# ── Qt ── (pure Qt Quick app: no Widgets) ─────────────────────────────────────
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core Gui Qml Quick QuickControls2 Svg Multimedia)

qt_standard_project_setup(REQUIRES 6.5)

# Auto-generate qmldir entries for QML files kept in subdirectories.
qt_policy(SET QTP0004 NEW)

# ── Configured build metadata header (app id / name / version) ────────────────
configure_file(src/AppInfo.h.in ${CMAKE_BINARY_DIR}/generated/AppInfo.h @ONLY)

# ── Executable ────────────────────────────────────────────────────────────────
qt_add_executable(hungrysnake
    src/main.cpp
)

# QML files physically live under src/qml/. Alias each into the module root so
# compiled resource paths stay clean (e.g. Main.qml, components/IconButton.qml).
set(SN_QML_FILES
    Main.qml
    Theme.qml
    Board.qml
    Cosmetics.qml
    Achievements.qml
    components/Icon.qml
    components/IconButton.qml
    components/PillButton.qml
    components/StatCard.qml
    components/ToggleRow.qml
    components/CoinBalance.qml
    components/ProgressBar.qml
    components/Badge.qml
    components/SegmentedControl.qml
    components/ScreenHeader.qml
    components/StoreCard.qml
    components/Toast.qml
    components/AppleArt.qml
    components/SnakeArt.qml
    components/BoardArt.qml
    components/BonusFoodArt.qml
)
set(SN_QML_PATHS "")
foreach(qml IN LISTS SN_QML_FILES)
    set(path "src/qml/${qml}")
    set_source_files_properties(${path} PROPERTIES QT_RESOURCE_ALIAS ${qml})
    list(APPEND SN_QML_PATHS ${path})
endforeach()

# Theme.qml is a `pragma Singleton`; mark it explicitly (setting QT_RESOURCE_ALIAS
# above suppresses auto-detection).
set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# ── QML module (compiles QML, registers C++ QML_ELEMENT types under the URI) ──
qt_add_qml_module(hungrysnake
    URI HungrySnake
    VERSION 1.0
    QML_FILES ${SN_QML_PATHS}
    SOURCES
        src/core/SnakeGame.h  src/core/SnakeGame.cpp
        src/core/Profile.h    src/core/Profile.cpp
)

# ── Bundled assets: app icon + sound effects + decorative foliage ─────────────
file(GLOB_RECURSE SN_SOUND_FILES CONFIGURE_DEPENDS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/sounds/*.wav)

file(GLOB SN_DECOR_FILES CONFIGURE_DEPENDS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/decor/*.svg)

file(GLOB SN_FONT_FILES CONFIGURE_DEPENDS
     RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} assets/fonts/*.ttf)

qt_add_resources(hungrysnake "appdata"
    PREFIX "/"
    BASE ${CMAKE_CURRENT_SOURCE_DIR}
    FILES
        assets/icons/${SN_APP_ID}.svg
        ${SN_SOUND_FILES}
        ${SN_DECOR_FILES}
        ${SN_FONT_FILES}
)

target_include_directories(hungrysnake PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/core
    ${CMAKE_BINARY_DIR}/generated
)

target_link_libraries(hungrysnake PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
    Qt6::Multimedia
)

target_compile_definitions(hungrysnake PRIVATE
    $<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>:QT_NO_DEBUG_OUTPUT>
    $<$<CONFIG:Debug>:SN_DEBUG>
)

# ── Install (desktop integration) ─────────────────────────────────────────────
include(GNUInstallDirs)

install(TARGETS hungrysnake RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES packaging/${SN_APP_ID}.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)

# AppStream metainfo — snapcraft's parse-info pulls the summary/description/
# licence straight out of this at build time (see snap/snapcraft.yaml).
install(FILES packaging/${SN_APP_ID}.metainfo.xml
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/metainfo)

install(FILES assets/icons/${SN_APP_ID}.svg
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)

# The bundled typefaces are SIL Open Font License — the licence must ship with them.
install(FILES assets/fonts/Fredoka-OFL.txt assets/fonts/TitanOne-OFL.txt
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/doc/${SN_APP_ID}/fonts)
