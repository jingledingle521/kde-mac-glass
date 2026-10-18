cmake_minimum_required(VERSION 3.20)
project(macglass-style LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(KF6WindowSystem REQUIRED)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)

add_library(macglass MODULE macglassstyle.cpp)
target_link_libraries(macglass Qt6::Widgets KF6::WindowSystem)

# Installed under the prefix's Qt plugin dir: ~/.local/lib64/qt6/plugins/styles
# by default (see install.sh), which QT_PLUGIN_PATH points at.
install(TARGETS macglass DESTINATION lib64/qt6/plugins/styles)
