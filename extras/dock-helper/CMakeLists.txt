cmake_minimum_required(VERSION 3.20)
project(macdock-helper LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Quick)
find_package(KF6WindowSystem REQUIRED)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)

# QML module org.brhett.macdock: the dock's window effects (blur behind the
# glass, click-through elsewhere). Installed under ~/.local/lib64/qt6/qml,
# which QML_IMPORT_PATH points at (see install.sh).
qt_add_qml_module(macdockhelper
    URI org.brhett.macdock
    VERSION 1.0
    PLUGIN_TARGET macdockhelper
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME MacDockHelperPlugin
    SOURCES docksurface.h docksurface.cpp plugin.cpp
)
target_link_libraries(macdockhelper PRIVATE Qt6::Quick KF6::WindowSystem)

set(QML_DIR lib64/qt6/qml/org/brhett/macdock)
install(TARGETS macdockhelper DESTINATION ${QML_DIR})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/qmldir DESTINATION ${QML_DIR})
