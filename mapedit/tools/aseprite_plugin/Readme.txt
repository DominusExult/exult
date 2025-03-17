Aseprite shapes plug-In
=======================

This plug-in converts a shp to png and displays all the frames on hitting File -> "Import SHP".
It will also temporarily store the offsets of the shp file as a "Tag name", until you close
the imported file. However you can also save as the asprite file format which will store the
"Tag names".

"Export SHP" will make use of the "Tag name" and save this correctly in the exported SHP.

How to Build and Install
=======================
Run Exult ./configure --enable-aseprite-plugin. The only thing this checks for is the presence of libpng.

Then zip the plug-in exult_shape(.exe), main.lua, package.json and this Readme.txt as "exult_shp.aseprite-extension".
Double clicking it will open Aseprite and install the plug-in.

To be safe, restart Aseprite, and you should see the "Import SHP" and "Export SHP" commands in the File menu.