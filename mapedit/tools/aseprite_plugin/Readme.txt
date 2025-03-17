Aseprite shapes plug-In
=======================

This plug-in converts a shp to png and displays all the frames. This means we are loosing the 
offsets we have, same as when you export to png in Exult Studio.


How to Build and Install
=======================
Run Exult ./configure --enable-aseprite-plugin. The only thing this checks for is the presence of libpng.

Then zip the plug-in exult_shape(.exe), main.lua, package.json and this Readme.txt as "exult_shp.aseprite-extension".
Double clicking it will open Aseprite and install the plug-in.

To be safe, restart Aseprite, and you should see the "Import SHP" and "Export SHP" commands in the File menu.