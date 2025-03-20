-- Exult SHP Format Extension for Aseprite

local pluginName = "exult-shp"
local pluginDir = app.fs.joinPath(app.fs.userConfigPath, "extensions", pluginName)
local converterPath = app.fs.joinPath(pluginDir, "exult_shp")

-- Debug system with toggle
local debugEnabled = false  -- toggle debug messages

local function debug(message)
  if debugEnabled then
    print("[Exult SHP] " .. message)
  end
end

local function logError(message)
  -- Always print errors regardless of debug setting
  print("[Exult SHP ERROR] " .. message)
end

-- Global utility function for quoting paths with spaces
function quoteIfNeeded(path)
  if path:find(" ") then
    return '"' .. path .. '"'
  else
    return path
  end
end

-- Helper to run commands with hidden output
function executeHidden(cmd)
  -- Check operating system and add appropriate redirection
  local redirectCmd
  if app.fs.pathSeparator == "\\" then
    -- Windows
    redirectCmd = cmd .. " > NUL 2>&1"
  else
    -- Unix-like (macOS, Linux)
    redirectCmd = cmd .. " > /dev/null 2>&1"
  end
  
  debug("Executing: " .. cmd)
  return os.execute(redirectCmd)
end

debug("Plugin initializing...")
debug("System Information:")
debug("OS: " .. (app.fs.pathSeparator == "/" and "Unix-like" or "Windows"))
debug("Temp path: " .. app.fs.tempPath)
debug("User config path: " .. app.fs.userConfigPath)

debug("Converter expected at: " .. converterPath)

-- Check if converterPath exists with OS-specific extension
if not app.fs.isFile(converterPath) then
  debug("Converter not found, checking for extensions...")
  if app.fs.isFile(converterPath..".exe") then
    converterPath = converterPath..".exe"
    debug("Found Windows converter: " .. converterPath)
  elseif app.fs.isFile(converterPath..".bin") then
    converterPath = converterPath..".bin"
    debug("Found binary converter: " .. converterPath)
  end
end

-- Verify converter exists at startup
local converterExists = app.fs.isFile(converterPath)
debug("Converter exists: " .. tostring(converterExists))

-- Make the converter executable once at startup if needed
if converterExists and app.fs.pathSeparator == "/" then
  local chmodCmd = "chmod +x " .. quoteIfNeeded(converterPath)
  debug("Executing chmod at plugin initialization: " .. chmodCmd)
  executeHidden(chmodCmd)
end

-- Error display helper
function showError(message)
  logError(message)
  app.alert{
    title="Exult SHP Error",
    text=message
  }
end

-- Don't detect Animation sequences when opening files
function disableAnimationDetection()
  -- Store the original preference value if it exists
  if app.preferences and app.preferences.open_file and app.preferences.open_file.open_sequence ~= nil then
    _G._originalSeqPref = app.preferences.open_file.open_sequence
    -- Set to 2 which means "skip the prompt without loading as animation"
    app.preferences.open_file.open_sequence = 2
  end
end

function restoreAnimationDetection()
  -- Restore the original preference if we saved it
  if app.preferences and app.preferences.open_file and _G._originalSeqPref ~= nil then
    app.preferences.open_file.open_sequence = _G._originalSeqPref
  end
end

-- File format registration function
function registerSHPFormat()
  if not converterExists then
    showError("SHP converter tool not found at:\n" .. converterPath .. 
              "\nSHP files cannot be opened until this is fixed.")
    return false
  end
  return true
end

function importSHP(filename)
  -- Handle direct file opening (when user opens .shp file)
  if filename then
    debug("Opening file directly: " .. filename)
    
    -- Create temp directory for files
    local tempDir = app.fs.joinPath(app.fs.tempPath, "exult-shp-" .. os.time())
    app.fs.makeDirectory(tempDir)
    
    -- Prepare output file path
    local outputBasePath = app.fs.joinPath(tempDir, "output")
    
    -- Use default palette and separate frames
    return processImport(filename, "", outputBasePath, true)
  end

  -- Normal dialog flow for manual import
  local dlg = Dialog("Import SHP File")
  dlg:file{
    id="shpFile",
    label="SHP File:",
    title="Select SHP File",
    open=true,
    filetypes={"shp"},
    focus=true
  }
  dlg:file{
    id="paletteFile",
    label="Palette File (optional):",
    open=true
  }
  
  -- Store dialog result in outer scope
  local dialogResult = false
  local importSettings = {}
  
  dlg:button{
    id="import",
    text="Import",
    onclick=function()
      dialogResult = true
      importSettings.shpFile = dlg.data.shpFile
      importSettings.paletteFile = dlg.data.paletteFile
      dlg:close()
    end
  }
  
  dlg:button{
    id="cancel",
    text="Cancel",
    onclick=function()
      dialogResult = false
      dlg:close()
    end
  }
  
  -- Show dialog
  dlg:show()
  
  -- Handle result
  if not dialogResult then return end
  
  if not importSettings.shpFile or importSettings.shpFile == "" then
    showError("Please select an SHP file to import")
    return
  end

  -- Create temp directory for files
  local tempDir = app.fs.joinPath(app.fs.tempPath, "exult-shp-" .. os.time())
  app.fs.makeDirectory(tempDir)
  
  -- Prepare output file path
  local outputBasePath = app.fs.joinPath(tempDir, "output")
  
  return processImport(importSettings.shpFile, 
                      importSettings.paletteFile or "", 
                      outputBasePath, 
                      true)
end

function processImport(shpFile, paletteFile, outputBasePath, createSeparateFrames)
  if not converterExists then
    showError("SHP converter not found at: " .. converterPath)
    return false
  end

  debug("Importing SHP: " .. shpFile)
  debug("Palette: " .. (paletteFile ~= "" and paletteFile or "default"))
  debug("Output: " .. outputBasePath)

  -- Check if file exists
  if not app.fs.isFile(shpFile) then
    showError("SHP file not found: " .. shpFile)
    return false
  end

  -- Extract base filename from the SHP file (without path and extension)
  local shpBaseName = shpFile:match("([^/\\]+)%.[^.]*$") or "output"
  shpBaseName = shpBaseName:gsub("%.shp$", "")
  debug("Extracted SHP base name: " .. shpBaseName)
  
  -- Extract output directory from outputBasePath
  local outputDir = outputBasePath:match("(.*[/\\])") or ""
  
  -- Combine to get the actual path where files will be created
  local actualOutputBase = outputDir .. shpBaseName
  debug("Expected output base: " .. actualOutputBase)
  
  -- Create command - always use separate frames mode
  local cmd = quoteIfNeeded(converterPath) .. " import " .. quoteIfNeeded(shpFile) .. " " .. quoteIfNeeded(outputBasePath)

  -- Only add palette if it's not empty
  if paletteFile and paletteFile ~= "" then
    cmd = cmd .. " " .. quoteIfNeeded(paletteFile)
  end

  -- Always use separate frames
  cmd = cmd .. " separate"
  
  debug("Executing: " .. cmd)
  
  -- Execute command
  local success = executeHidden(cmd)
  debug("Command execution " .. (success and "succeeded" or "failed"))

  -- Check for output files - using the actual base path with SHP filename
  local firstFrame = actualOutputBase .. "_0.png"
  
  debug("Looking for first frame at: " .. firstFrame)
  debug("File exists: " .. tostring(app.fs.isFile(firstFrame)))
  
  if not app.fs.isFile(firstFrame) then
    debug("ERROR: Failed to convert SHP file")
    return false
  end

  -- Continue with loading the frames
  debug("Loading output files into Aseprite")
  
  -- First scan for all frames to find max dimensions for canvas
  local maxWidth, maxHeight = 0, 0
  local frameIndex = 0
  
  while true do
    local framePath = actualOutputBase .. "_" .. frameIndex .. ".png"
    if not app.fs.isFile(framePath) then break end
    
    local image = Image{fromFile=framePath}
    maxWidth = math.max(maxWidth, image.width)
    maxHeight = math.max(maxHeight, image.height)
    frameIndex = frameIndex + 1
  end
  
  debug("Maximum dimensions across all frames: " .. maxWidth .. "x" .. maxHeight)
  
  -- Now load first frame
  local firstFrame = actualOutputBase .. "_0.png"
  local firstMeta = actualOutputBase .. "_0.meta"
  
  if not app.fs.isFile(firstFrame) then
    showError("First frame not found: " .. firstFrame)
    return false
  end
  
  -- Open the first image as a sprite
  debug("Opening first frame: " .. firstFrame)
  
  -- Disable animation detection before opening file
  disableAnimationDetection()
  
  -- Open the file normally
  local sprite = app.open(firstFrame)
  
  -- Restore original settings
  restoreAnimationDetection()
  
  if not sprite then
    showError("Failed to open first frame")
    return false
  end
  
   -- Immediately rename the file to the SHP filename to avoid save prompts later
   sprite.filename = shpFile

  -- Resize canvas to maximum dimensions if needed
  if maxWidth > sprite.width or maxHeight > sprite.height then
    debug("Resizing canvas to " .. maxWidth .. "x" .. maxHeight)
    app.command.CanvasSize {
      ui=false,
      width=maxWidth,
      height=maxHeight,
      left=0,
      top=0,
      right=maxWidth-sprite.width, 
      bottom=maxHeight-sprite.height
    }
  end
  
  -- Set pivot from metadata for first frame
  if app.fs.isFile(firstMeta) then
    local meta = io.open(firstMeta, "r")
    if meta then
      local offsetX, offsetY = 0, 0
      for line in meta:lines() do
        local key, value = line:match("(.+)=(.+)")
        if key == "offset_x" then offsetX = tonumber(value) end
        if key == "offset_y" then offsetY = tonumber(value) end
      end
      meta:close()
      
      -- Store offset in cel's user data for the first frame
      local firstFrameCel = sprite.layers[1]:cel(1)
      if firstFrameCel then
        firstFrameCel.data = string.format("offset:%d,%d", offsetX or 0, offsetY or 0)
        debug("Stored offset data in first frame cel user data: " .. firstFrameCel.data)
      end
    end
  end
  
  -- Now add additional frames
  local frameIndex = 1
  while true do
    local framePath = actualOutputBase .. "_" .. frameIndex .. ".png"
    local metaPath = actualOutputBase .. "_" .. frameIndex .. ".meta"
    
    if not app.fs.isFile(framePath) then
      debug("No more frames at index " .. frameIndex)
      break
    end
    
    debug("Adding frame " .. frameIndex)
    
    -- Load the image
    local frameImage = Image{fromFile=framePath}
    
    -- Create a new frame (user will need to handle the prompt)
    local newFrame = sprite:newFrame()
    
    -- Continue with the rest of the process
    app.command.GotoFrame{frame=frameIndex+1}
    
    -- Create new cel with this image
    local layer = sprite.layers[1]
    local cel = sprite:newCel(layer, frameIndex+1, frameImage, Point(0,0))
    
    -- Load and set pivot from metadata
    local offsetX, offsetY = 0, 0  -- Define these at frame loop level, not inside the if block
    
    if app.fs.isFile(metaPath) then
      local meta = io.open(metaPath, "r")
      if meta then
        for line in meta:lines() do
          local key, value = line:match("(.+)=(.+)")
          if key == "offset_x" then offsetX = tonumber(value) end
          if key == "offset_y" then offsetY = tonumber(value) end
        end
        meta:close()
        
        -- Set frame center point (pivot)
        app.command.FrameProperties{
          center=Point(offsetX, offsetY)
        }
        
        -- Store offset data in cel's user data
        if cel then
          cel.data = string.format("offset:%d,%d", offsetX, offsetY)
          debug("Stored offset data in cel user data: " .. cel.data)
        end
      end
    end
    
    frameIndex = frameIndex + 1
  end
  
  -- Set layer edges to be visible after import
  if app.preferences then
    -- Use the correct document preferences API
    local docPref = app.preferences.document(sprite)
    if docPref and docPref.show then
      docPref.show.layer_edges = true
      debug("Enabled layer edges display for this document")
    else
      debug("Could not set layer_edges preference (editor section not found in document preferences)")
    end
  else
    debug("Could not set layer_edges preference (preferences not available)")
  end
  
  return true, sprite
end

-- Modify the export dialog function
function exportSHP()
  -- Get active sprite
  local sprite = app.activeSprite
  if not sprite then
    showError("No active sprite to export")
    return
  end
  
  -- Store original default extension preference
  local originalDefaultExt = nil
  if app.preferences and app.preferences.save_file then
    originalDefaultExt = app.preferences.save_file.default_extension
    -- Set SHP as default extension during export
    app.preferences.save_file.default_extension = "shp"
    debug("Temporarily set default image extension to SHP")
  end
  
  -- Check if sprite uses indexed color mode
  if sprite.colorMode ~= ColorMode.INDEXED then
    showError("SHP format needs an indexed palette. Convert your sprite to Indexed color mode first.")
    return
  end
  
  -- Check if sprite has any offset data in cels
  local hasOffsetData = spriteHasCelOffsetData(sprite)
  
  -- Default offset values for fallback
  local defaultOffsetX = math.floor(sprite.width / 2)
  local defaultOffsetY = math.floor(sprite.height / 2)
  
  -- Show initial export dialog - simplified without offset fields
  local dlg = Dialog("Export SHP File")
  dlg:file{
    id="outFile",
    label="Output SHP File:",
    save=true,
    filetypes={"shp"},
    focus=true
  }
  
  -- Just show informational text about offset data source
  if hasOffsetData then
    dlg:label{
      id="usingData",
      text="Using offset data from cels"
    }
  else
    dlg:label{
      id="noData",
      text="You will be prompted for offset values for frames without stored offsets"
    }
  end
  
  -- Store dialog result in outer scope
  local dialogResult = false
  local exportSettings = {}
  
  dlg:button{
    id="export",
    text="Export",
    onclick=function()
      dialogResult = true
      exportSettings.outFile = dlg.data.outFile
      dlg:close()
    end
  }
  
  dlg:button{
    id="cancel",
    text="Cancel",
    onclick=function()
      dialogResult = false
      dlg:close()
    end
  }
  
  -- Show dialog
  dlg:show()
  
  -- Handle result
  if not dialogResult then return end
  
  if not exportSettings.outFile or exportSettings.outFile == "" then
    showError("Please specify an output SHP file")
    return
  end

  if not converterExists then
    showError("SHP converter not found at: " .. converterPath)
    return
  end

  -- Create temp directory for files
  local tempDir = app.fs.joinPath(app.fs.tempPath, "exult-shp-" .. os.time())
  app.fs.makeDirectory(tempDir)
  
  -- Prepare file paths
  local metaPath = app.fs.joinPath(tempDir, "metadata.txt")
  local basePath = app.fs.joinPath(tempDir, "frame")
  
  -- Create metadata file
  local meta = io.open(metaPath, "w")
  meta:write(string.format("num_frames=%d\n", #sprite.frames))
  
  -- Track frame offsets
  local frameOffsets = {}
  
  -- First pass: Check which frames have offset data in cels
  for i, frame in ipairs(sprite.frames) do
    local frameNumber = frame.frameNumber
    local offsetNeeded = true
    
    -- Check for offset data in cel user data
    local layer = sprite.layers[1]
    local cel = layer:cel(frameNumber)
    
    if cel and cel.data then
      -- Try to extract offset from cel.data
      local x, y = cel.data:match("offset:(%d+),(%d+)")
      
      if x and y then
        frameOffsets[i] = {
          x = tonumber(x),
          y = tonumber(y)
        }
        offsetNeeded = false
        debug("Found offset in cel user data for frame " .. i .. ": " .. x .. "," .. y)
      end
    end
    
    -- If no cel data found, use default or prompt
    if offsetNeeded then
      frameOffsets[i] = {
        needsPrompt = true
      }
      debug("No offset data found for frame " .. i .. ", will prompt user")
    end
  end
  
  -- Second pass: Prompt for missing offsets
  for i, frameData in ipairs(frameOffsets) do
    if frameData.needsPrompt then
      -- Go to the frame to show it to the user
      app.command.GotoFrame{frame=sprite.frames[i].frameNumber}
      
      -- Create prompt dialog for this specific frame
      local frameDlg = Dialog("Frame " .. i .. " Offset")
      
      frameDlg:label{
        id="info",
        text="Set offset for frame " .. i .. " of " .. #sprite.frames
      }
      
      frameDlg:number{
        id="offsetX",
        label="Offset X:",
        text=tostring(defaultOffsetX),
        decimals=0
      }
      
      frameDlg:number{
        id="offsetY",
        label="Offset Y:",
        text=tostring(defaultOffsetY),
        decimals=0
      }
      
      local frameResult = false
      
      frameDlg:button{
        id="ok",
        text="OK",
        onclick=function()
          frameResult = true
          frameOffsets[i] = {
            x = frameDlg.data.offsetX,
            y = frameDlg.data.offsetY
          }
          frameDlg:close()
        end
      }
      
      -- Show dialog and wait for result
      frameDlg:show{wait=true}
      
      -- If user cancelled, use defaults
      if not frameResult then
        frameOffsets[i] = {
          x = defaultOffsetX,
          y = defaultOffsetY
        }
      end
    end
  end
  
  -- Now export each frame with its determined offset
  for i, frame in ipairs(sprite.frames) do
    local filepath = string.format("%s%d.png", basePath, i-1)
    
    -- Go to the frame we want to save
    app.command.GotoFrame{frame=frame.frameNumber}
    
    -- Get the cel directly
    local layer = sprite.layers[1]
    local cel = layer:cel(frame.frameNumber)
    
    -- Save the frame
    if cel and cel.image then
      cel.image:saveAs(filepath)
      debug("Saved frame " .. (i-1))
    else
      debug("ERROR: Could not find cel/image for frame " .. (i-1))
    end
    
    -- Get the offset for this frame
    local offsetX = frameOffsets[i].x
    local offsetY = frameOffsets[i].y
    
    -- Write metadata for pivot points
    meta:write(string.format("frame%d_offset_x=%d\n", i-1, offsetX))
    meta:write(string.format("frame%d_offset_y=%d\n", i-1, offsetY))
  end
  
  meta:close()
  
  -- Use first frame's offset as default for the converter command
  local cmdOffsetX = frameOffsets[1].x or defaultOffsetX
  local cmdOffsetY = frameOffsets[1].y or defaultOffsetY
  
  -- Create and execute the export command
  local cmd = quoteIfNeeded(converterPath) .. 
             " export " .. 
             quoteIfNeeded(basePath) .. 
             " " .. quoteIfNeeded(exportSettings.outFile) .. 
             " 0" ..
             " " .. cmdOffsetX ..
             " " .. cmdOffsetY ..
             " " .. quoteIfNeeded(metaPath)
  
  debug("Executing: " .. cmd)
  
  -- Execute command
  local success = executeHidden(cmd)
  if success then
    app.alert("SHP file exported successfully.")
  else
    showError("Failed to export SHP file.")
  end

  -- Restore original default extension preference
  if app.preferences and app.preferences.save_file and originalDefaultExt ~= nil then
    app.preferences.save_file.default_extension = originalDefaultExt
    debug("Restored original default image extension")
  end
end

function spriteHasCelOffsetData(sprite)
  -- Check if any cel has offset data stored
  for _, frame in ipairs(sprite.frames) do
    local layer = sprite.layers[1]
    local cel = layer:cel(frame.frameNumber)
    
    if cel and cel.data and cel.data:match("offset:") then
      return true
    end
  end
  
  return false
end

function init(plugin)
  debug("Initializing plugin...")
  
  -- Register file format first
  local formatRegistered = registerSHPFormat()
  debug("SHP format registered: " .. tostring(formatRegistered))
  
  -- Register commands
  plugin:newCommand{
    id="ImportSHP",
    title="Import SHP...",
    group="file_import",
    onclick=function() importSHP() end
  }
  
  plugin:newCommand{
    id="ExportSHP",
    title="Export SHP...",
    group="file_export",
    onclick=exportSHP
  }
  
  -- Register SHP file format for opening
  if formatRegistered then
    plugin:newCommand{
      id="OpenSHP",
      title="Ultima VII SHP",
      group="file_format",
      onclick=importSHP,
      file_format="shp"
    }
  end
end

return { init=init }