How to Build and Install
Build the converter:
cd /Users/Dominus/Code/snapshots/exult/mapedit/tools/exult-shp/plugin
mkdir build
cd build
cmake ..
make

Create the Aseprite extension directory:
mkdir -p ~/.config/aseprite/extensions/exult-shp/plugin

Copy the files:
cp build/bin/exult_shp_converter ~/.config/aseprite/extensions/exult-shp/plugin/
cp ../extension/package.json ../extension/main.lua ~/.config/aseprite/extensions/exult-shp/

Restart Aseprite, and you should see the "Import SHP" and "Export SHP" commands in the File menu.