Aseprite shapes plug-In
=======================

Aseprite is a popular pixel art editor https://aseprite.org.

This plug-in converts a shp to png and displays all the frames on hitting File -> "Import SHP".
It will also temporarily store the offsets of the shp file as a "Tag name", until you close
the imported file. However you can also save as the asprite file format which will store the
"Tag names".

"Export SHP" will make use of the "Tag name" and save this correctly in the exported SHP.


Issues of the plug-in
=====================
- Currently you can only import a shp file, not open it directly
- On importing a shp you will be prompted for "Frame Properties" on each frame, hit ok or cancel,
  neither matters. The reason is that Aseprite thinks it is an animation, when there are frames.
- We are saving the shp offsets in "Tag Properties" in bright red. On shps with many frames this can be
  very distracting in the view, but if you hover of a tag a square to theright side of the tag will show.
  Click on this and the tag view will collapse somewhat.
- All frames of shp are using the canvas size of the biggest frame, to see the actual dimensions show
  "Layer Edges" (menu -> View -> Show -> Layer Edges)


How to Build and Install
========================

On Linux and macOS use "./configure --enable-aseprite-plugin". The only thing this checks for is the presence
of libpng.
On Windows run "make -f makefile.mingw aseprite-plugin"

Then zip the plug-in (exult_shape(.exe), main.lua, package.json and this Readme.txt) as "exult_shp.aseprite-extension".
Double clicking it will open Aseprite and install the plug-in.

To be safe, restart Aseprite, and you should see the "Import SHP" and "Export SHP" commands in the File menu.