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
  -- For debugging, run raw command instead with output captured
  if debugEnabled then
    debug("Executing with output capture: " .. cmd)
    local tmpFile = app.fs.joinPath(app.fs.tempPath, "exult-shp-output-" .. os.time() .. ".txt")
    
    -- Add output redirection to file
    local redirectCmd
    if app.fs.pathSeparator == "\\" then
      -- Windows
      redirectCmd = cmd .. " > " .. quoteIfNeeded(tmpFile) .. " 2>&1"
    else
      -- Unix-like (macOS, Linux)
      redirectCmd = cmd .. " > " .. quoteIfNeeded(tmpFile) .. " 2>&1"
    end
    
    -- Execute the command
    local success = os.execute(redirectCmd)
    
    -- Read and log the output
    if app.fs.isFile(tmpFile) then
      local file = io.open(tmpFile, "r")
      if file then
        debug("Command output:")
        local output = file:read("*all")
        debug(output or "<no output>")
        file:close()
      end
      -- Clean up temp file (comment this out if you want to keep the logs)
      -- app.fs.removeFile(tmpFile)
    end
    
    return success
  else
    -- Check operating system and add appropriate redirection
    local redirectCmd
    if app.fs.pathSeparator == "\\" then
      -- Windows
      redirectCmd = cmd .. " > NUL 2>&1"
    else
      -- Unix-like (macOS, Linux)
      redirectCmd = cmd .. " > /dev/null 2>&1"
    end
    
    return os.execute(redirectCmd)
  end
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

function getCelOffsetData(cel)
  if not cel then return nil end
  
  -- Only extract from cel's user data
  if cel.data and cel.data:match("offset:") then
    local x, y = cel.data:match("offset:(%d+),(%d+)")
    if x and y then
      return {
        offsetX = tonumber(x),
        offsetY = tonumber(y)
      }
    end
  end
  
  return nil
end

function setCelOffsetData(cel, offsetX, offsetY)
  if not cel then return end
  
  -- Store offset directly in the cel's user data only
  cel.data = string.format("offset:%d,%d", offsetX or 0, offsetY or 0)
  debug("Stored offset data in cel user data: " .. cel.data)
  
  -- No longer store in layer name
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
  
  -- First scan for all frames to find max dimensions and offset extremes
  local maxWidth, maxHeight = 0, 0
  local minOffsetX, minOffsetY = 999999, 999999
  local maxRightEdge, maxBottomEdge = -999999, -999999
  local frameIndex = 0
  
  -- Scan all frames once to determine canvas size and gather offset data
  local maxOffsetX = 0
  local maxOffsetY = 0
  local offsetData = {}  -- Store all offset data in a table to avoid re-reading files
  
  -- First pass: gather all offset data and find dimensions
  while true do
    local framePath = actualOutputBase .. "_" .. frameIndex .. ".png"
    local metaPath = actualOutputBase .. "_" .. frameIndex .. ".meta"
    
    if not app.fs.isFile(framePath) then break end
    
    local image = Image{fromFile=framePath}
    local offsetX, offsetY = 0, 0
    
    -- Read offset from metadata
    if app.fs.isFile(metaPath) then
      local meta = io.open(metaPath, "r")
      if meta then
        for line in meta:lines() do
          local key, value = line:match("(.+)=(.+)")
          if key == "offset_x" then offsetX = tonumber(value) end
          if key == "offset_y" then offsetY = tonumber(value) end
        end
        meta:close()
      end
    end
    
    -- Store offset data for later use
    offsetData[frameIndex] = {
      offsetX = offsetX,
      offsetY = offsetY,
      width = image.width,
      height = image.height
    }
    
    -- Track maximum offsets
    maxOffsetX = math.max(maxOffsetX, offsetX)
    maxOffsetY = math.max(maxOffsetY, offsetY)
    
    -- Track maximum extents
    local rightEdge = offsetX + image.width
    local bottomEdge = offsetY + image.height
    maxRightEdge = math.max(maxRightEdge, rightEdge)
    maxBottomEdge = math.max(maxBottomEdge, bottomEdge)
    
    frameIndex = frameIndex + 1
  end
  
  debug("Found " .. frameIndex .. " frames, canvas size: " .. maxWidth .. "x" .. maxHeight)
  debug("Processed " .. frameIndex .. " frames with offsets. Maximum offset: (" .. maxOffsetX .. "," .. maxOffsetY .. ")")
  
  -- Calculate canvas size - using the rightmost and bottommost edges
  maxWidth = maxRightEdge
  maxHeight = maxBottomEdge
  
  debug("Canvas calculated: " .. maxWidth .. "x" .. maxHeight .. " based on max offsets: (" .. maxOffsetX .. "," .. maxOffsetY .. ")")
  
  -- Fix the first frame positioning (around line 400-425):
  -- Position the first cel based on offset
  
  debug("Maximum offsets: (" .. maxOffsetX .. "," .. maxOffsetY .. ")")
  
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
  debug("Set sprite filename to: " .. shpFile)
  
  -- RESIZE TO EXACT DIMENSIONS - no centering, no buffer, top-aligned
  if sprite.width ~= maxWidth or sprite.height ~= maxHeight then
    debug("Resizing sprite to exact dimensions: " .. maxWidth .. "x" .. maxHeight)
    
    -- Resize WITHOUT centering - position at top-left (0,0)
    sprite:resize(maxWidth, maxHeight, 0, 0)
    
    -- Ensure first cel remains at top-left (0,0)
    local cel = sprite.layers[1]:cel(1)
    if cel then
      cel.position = Point(0, 0)
      debug("Positioned first cel at top-left (0,0)")
    end
  end
  
  -- Fix the first frame positioning (around line 400-425):
  -- Position the first cel based on offset
  local firstMeta = actualOutputBase .. "_0.meta"
  local firstOffsetX, firstOffsetY = 0, 0
    
  if app.fs.isFile(firstMeta) then
    local meta = io.open(firstMeta, "r")
    if meta then
      for line in meta:lines() do
        local key, value = line:match("(.+)=(.+)")
        if key == "offset_x" then firstOffsetX = tonumber(value) end
        if key == "offset_y" then firstOffsetY = tonumber(value) end
      end
      meta:close()
    end
  end
    
  -- Calculate position based on offset from top-left
  -- An offset of (x,y) means the image should be positioned at (maxOffsetX-x, maxOffsetY-y)
  local adjustedX = maxOffsetX - firstOffsetX
  local adjustedY = maxOffsetY - firstOffsetY
  
  -- Set the position
  local cel = sprite.layers[1]:cel(1)
  if cel then
    cel.position = Point(adjustedX, adjustedY)
    debug("Positioned first cel at adjusted position: (" .. adjustedX .. "," .. adjustedY .. ")")
  end
  
  -- Rename the first layer to indicate it's frame 1
  local baseLayer = sprite.layers[1]
  baseLayer.name = "Frame 1"
  
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
      
      -- Store offset data in the cel's user data
      local firstFrameCel = baseLayer:cel(1)
      if firstFrameCel then
        setCelOffsetData(firstFrameCel, offsetX, offsetY)
      end
    end
  end
  
  -- Now add additional frames as layers
  local frameIndex = 1
  while true do
    local framePath = actualOutputBase .. "_" .. frameIndex .. ".png"
    local metaPath = actualOutputBase .. "_" .. frameIndex .. ".meta"
    
    if not app.fs.isFile(framePath) then
      debug("No more frames at index " .. frameIndex)
      break
    end
    
    debug("Adding frame " .. frameIndex .. " as layer")
    
    -- Load the image
    local frameImage = Image{fromFile=framePath}
    
    -- Add new layer (instead of frame)
    local newLayer = sprite:newLayer()
    newLayer.name = "Frame " .. (frameIndex + 1) -- 1-based naming
    
    -- Create new cel with this image - positioned at absolute offset
    local frameData = offsetData[frameIndex]
    if frameData then
      local offsetX = frameData.offsetX
      local offsetY = frameData.offsetY
      
      -- Calculate position based on offset from top-left
      local adjustedX = maxOffsetX - offsetX
      local adjustedY = maxOffsetY - offsetY
      
      -- Create cel with correct position
      local cel = sprite:newCel(newLayer, 1, frameImage, Point(adjustedX, adjustedY))
      debug("Positioned layer " .. frameIndex .. " at adjusted position: (" .. adjustedX .. "," .. adjustedY .. ")")
      
      -- Store offset in cel user data (no need to re-read metadata)
      setCelOffsetData(cel, offsetX, offsetY)
    end
    
    frameIndex = frameIndex + 1
  end
  
  -- We're now done with all layers. Replace the first layer's cel image to ensure exact dimensions
  debug("Replacing first layer's cel with original image to preserve dimensions")
  local originalFramePath = actualOutputBase .. "_0.png"
  
  -- Load the original first frame image again
  if app.fs.isFile(originalFramePath) then
    -- Get the original image
    local originalImage = Image{fromFile=originalFramePath}
    
    -- Get the first layer and its cel
    local firstLayer = sprite.layers[1]
    local firstCel = firstLayer:cel(1)
    
    if firstCel then
      -- Store the current position and offset data BEFORE deleting the cel
      local currentPosition = firstCel.position
      local offsetData = nil
      
      -- Safely get the offset data before removing the cel
      if firstCel then
        offsetData = getCelOffsetData(firstCel)
        debug("Saved offset data from original cel: " .. 
              (offsetData and (offsetData.offsetX .. "," .. offsetData.offsetY) or "none"))
      end
      
      -- Remove the old cel first
      sprite:deleteCel(firstLayer, 1)
      
      -- Now add the new cel
      local newCel = sprite:newCel(firstLayer, 1, originalImage, currentPosition)
      
      -- Apply the saved offset data to the new cel
      if offsetData then
        setCelOffsetData(newCel, offsetData.offsetX, offsetData.offsetY)
        debug("Re-applied offset data to new cel: " .. offsetData.offsetX .. "," .. offsetData.offsetY)
      end
      
      debug("Replaced first cel image with original dimensions " .. originalImage.width .. "x" .. originalImage.height)
    end
  end
  
  -- Set layer edges to be visible after import
  if app.preferences then
    -- Use the correct document preferences API
    local docPref = app.preferences.document(sprite)
    if docPref and docPref.show then
      docPref.show.layer_edges = true
      debug("Enabled layer edges display for this document")
    else
      debug("Could not set layer_edges preference (show section not found in document preferences)")
    end
  else
    debug("Could not set layer_edges preference (preferences not available)")
  end
  
  return true, sprite
end

-- Add this helper function to check for offset tags
function spriteHasCelOffsetData(sprite)
  -- Check if any cel has offset data stored
  for i, layer in ipairs(sprite.layers) do
    local cel = layer:cel(1)
    if cel and cel.data and cel.data:match("offset:") then
      return true
    end
  end
  return false
end

-- Replace the exportSHP function with this improved version:
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
  
  -- Default offset values for fallback
  local defaultOffsetX = math.floor(sprite.width / 2)
  local defaultOffsetY = math.floor(sprite.height / 2)
  
  -- Count how many layers already have offset data
  local layersWithOffsets = 0
  for _, layer in ipairs(sprite.layers) do
    local cel = layer:cel(1)
    if cel and getCelOffsetData(cel) then
      layersWithOffsets = layersWithOffsets + 1
    end
  end
  
  -- Show initial export dialog - simplified without offset fields
  local dlg = Dialog("Export SHP File")
  dlg:file{
    id="outFile",
    label="Output SHP File:",
    save=true,
    filetypes={"shp"},
    focus=true
  }
  
  -- Show informational text about layer offsets
  if layersWithOffsets == #sprite.layers then
    dlg:label{
      id="allOffsetsSet",
      text="All layers have offset data. Ready to export."
    }
  elseif layersWithOffsets > 0 then
    dlg:label{
      id="someOffsetsSet",
      text=layersWithOffsets .. " of " .. #sprite.layers .. " layers have offset data. You'll be prompted for the rest."
    }
  else
    dlg:label{
      id="noOffsets",
      text="No layers have offset data. You'll be prompted to set offsets for each layer."
    }
  end
  
  -- Add option to edit existing offsets
  dlg:check{
    id="editExisting",
    text="Edit existing offsets",
    selected=false
  }
  
  -- Store dialog result in outer scope
  local dialogResult = false
  local exportSettings = {}
  
  dlg:button{
    id="export",
    text="Export",
    onclick=function()
      dialogResult = true
      exportSettings.outFile = dlg.data.outFile
      exportSettings.editExisting = dlg.data.editExisting
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
  meta:write(string.format("num_frames=%d\n", #sprite.layers))
  
  -- Track frame offsets - the index in this array is the export frame number
  local layerOffsets = {}
  
  -- First pass: Check which layers need offset prompts
  for i, layer in ipairs(sprite.layers) do
    local offsetNeeded = true
    
    -- Check for cel user data first
    local cel = layer:cel(1)
    local offsetData = cel and getCelOffsetData(cel)
    
    if offsetData and not exportSettings.editExisting then
      layerOffsets[i] = {
        x = offsetData.offsetX,
        y = offsetData.offsetY,
        fromData = true
      }
      offsetNeeded = false
      debug("Using existing offset from cel data for layer " .. i .. ": " .. offsetData.offsetX .. "," .. offsetData.offsetY)
    end
    
    -- Mark for prompting if still needed
    if offsetNeeded then
      layerOffsets[i] = {
        needsPrompt = true
      }
    end
  end
  
  -- Second pass: Prompt for missing offsets
  for i, layerData in ipairs(layerOffsets) do
    if layerData.needsPrompt then
      -- Make this layer visible and others invisible for visual reference
      for j, otherLayer in ipairs(sprite.layers) do
        otherLayer.isVisible = (j == i)
      end
      
      -- Create prompt dialog for this specific layer
      local layerDlg = Dialog("Layer Offset")
      
      -- Get cleaner name (without offset info)
      local cleanName = sprite.layers[i].name:gsub(" %[.*%]$", "")
      
      layerDlg:label{
        id="info",
        text="Set offset for " .. cleanName .. " (" .. i .. " of " .. #sprite.layers .. ")"
      }
      
      -- If we have existing data, use it as default
      local cel = sprite.layers[i]:cel(1)
      local existingData = cel and getCelOffsetData(cel)
      local initialX = defaultOffsetX
      local initialY = defaultOffsetY
      
      if existingData then
        initialX = existingData.offsetX
        initialY = existingData.offsetY
      end
      
      layerDlg:number{
        id="offsetX",
        label="Offset X:",
        text=tostring(initialX),
        decimals=0
      }
      
      layerDlg:number{
        id="offsetY",
        label="Offset Y:",
        text=tostring(initialY),
        decimals=0
      }
      
      local layerResult = false
      
      layerDlg:button{
        id="ok",
        text="OK",
        onclick=function()
          layerResult = true
          layerOffsets[i] = {
            x = layerDlg.data.offsetX,
            y = layerDlg.data.offsetY
          }
          layerDlg:close()
        end
      }
      
      -- Show dialog and wait for result
      layerDlg:show{wait=true}
      
      -- If user cancelled, use defaults or existing data
      if not layerResult then
        if existingData then
          layerOffsets[i] = {
            x = existingData.offsetX,
            y = existingData.offsetY
          }
        else
          layerOffsets[i] = {
            x = defaultOffsetX,
            y = defaultOffsetY
          }
        end
      end
      
      -- Store the value in the cel for future use
      local cel = sprite.layers[i]:cel(1)
      if cel then
        setCelOffsetData(cel, layerOffsets[i].x, layerOffsets[i].y)
      end
    end
  end
  
  -- Restore all layers to visible
  for _, layer in ipairs(sprite.layers) do
    layer.isVisible = true
  end
  
  -- Now export each layer as a frame - directly to image files preserving original dimensions
  for i, layer in ipairs(sprite.layers) do
    local frameIndex = i - 1 -- Convert to 0-based for the SHP file
    local filepath = string.format("%s%d.png", basePath, frameIndex)
    
    debug("Exporting layer " .. i .. " (" .. layer.name .. ") as frame " .. frameIndex)
    
    -- Get the cel for this layer
    local cel = layer:cel(1)
    if cel then
      -- Get just the cel image (not including position)
      local celImage = cel.image
      
      -- Write the image directly to a file without creating a sprite
      celImage:saveAs(filepath)
      
      -- Verify the file was created
      if not app.fs.isFile(filepath) then
        debug("WARNING: Failed to export frame " .. frameIndex)
      else
        -- Get offset from cel data
        local offsetData = getCelOffsetData(cel)
        local offsetX = offsetData and offsetData.offsetX or 0
        local offsetY = offsetData and offsetData.offsetY or 0
        
        -- Write to metadata file
        meta:write(string.format("frame%d_offset_x=%d\n", frameIndex, offsetX))
        meta:write(string.format("frame%d_offset_y=%d\n", frameIndex, offsetY))
        
        debug("Exported frame " .. frameIndex .. " with dimensions " .. 
              celImage.width .. "x" .. celImage.height .. 
              " and offsets: " .. offsetX .. "," .. offsetY)
      end
    end
  end
  
  -- Close metadata file
  meta:close()
  
  -- Create and execute the export command
  local cmd = quoteIfNeeded(converterPath) .. 
             " export " .. 
             quoteIfNeeded(basePath) .. 
             " " .. quoteIfNeeded(exportSettings.outFile) .. 
             " 0" ..
             " " .. layerOffsets[1].x ..
             " " .. layerOffsets[1].y ..
             " " .. quoteIfNeeded(metaPath)
  
  debug("Executing: " .. cmd)
  
  -- Execute command
  local success = executeHidden(cmd)
  
  -- Restore original default extension preference
  if app.preferences and app.preferences.save_file and originalDefaultExt ~= nil then
    app.preferences.save_file.default_extension = originalDefaultExt
    debug("Restored original default image extension")
  end
  
  if success then
    app.alert("SHP file exported successfully.")
  else
    showError("Failed to export SHP file.")
  end
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