-- Exult SHP Format Extension for Aseprite
-- Based on code from the Exult project

local pluginName = "exult-shp"
local pluginDir = app.fs.joinPath(app.fs.userConfigPath, "extensions", pluginName)
local converterPath = app.fs.joinPath(pluginDir, "exult_shp")

-- Debug helper
local function debug(message)
  print("[Exult SHP] " .. message)
end

-- Global utility function for quoting paths with spaces
function quoteIfNeeded(path)
  if path:find(" ") then
    return '"' .. path .. '"'
  else
    return path
  end
end

debug("Plugin initializing...")
debug("System Information:")
debug("OS: " .. (app.fs.pathSeparator == "/" and "Unix-like" or "Windows"))
debug("Temp path: " .. app.fs.tempPath)
debug("App path: " .. app.fs.appPath)
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

-- Error display helper
function showError(message)
  debug("ERROR: " .. message)
  app.alert{
    title="Exult SHP Error",
    text=message
  }
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
  dlg:check{
    id="separateFrames",
    label="Create Separate Frames:",
    text="Import as multiple frames",
    selected=true
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
      importSettings.separateFrames = dlg.data.separateFrames
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
                      importSettings.separateFrames)
end

function processImport(shpFile, paletteFile, outputBasePath, createSeparateFrames)
  if not converterExists then
    showError("SHP converter not found at: " .. converterPath)
    return false
  end

  debug("Importing SHP: " .. shpFile)
  debug("Palette: " .. (paletteFile ~= "" and paletteFile or "default"))
  debug("Output: " .. outputBasePath)
  debug("Separate frames: " .. tostring(createSeparateFrames))

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
  
  -- Create command
  local cmd = quoteIfNeeded(converterPath) .. " import " .. quoteIfNeeded(shpFile) .. " " .. quoteIfNeeded(outputBasePath)

  -- Only add palette if it's not empty
  if paletteFile and paletteFile ~= "" then
    cmd = cmd .. " " .. quoteIfNeeded(paletteFile)
  end

  -- Add separate parameter as the last argument
  if createSeparateFrames then
    cmd = cmd .. " separate"
  end
  
  debug("Executing: " .. cmd)
  
  -- Execute command
  local success = os.execute(cmd)
  debug("Command execution " .. (success and "succeeded" or "failed"))

  -- Check for output files - using the actual base path with SHP filename
  local firstFrame = actualOutputBase .. "_0.png"
  local spritesheet = actualOutputBase .. ".png"
  
  debug("Looking for first frame at: " .. firstFrame)
  debug("File exists: " .. tostring(app.fs.isFile(firstFrame)))
  
  if not (app.fs.isFile(firstFrame) or app.fs.isFile(spritesheet)) then
    debug("No output files found. Using experimental mode.")
    
    -- Try experimental mode directly 
    local expCmd = quoteIfNeeded(converterPath) .. 
                 " experimental " .. 
                 quoteIfNeeded(shpFile) .. 
                 " " .. quoteIfNeeded(outputBasePath)
    
    debug("Executing experimental command: " .. expCmd)
    os.execute(expCmd)
    
    -- Check again for output files
    if not (app.fs.isFile(firstFrame) or app.fs.isFile(spritesheet)) then
      debug("ERROR: All attempts to convert SHP file failed")
      return false
    end
  end

  -- Continue with loading the frames
  debug("Loading output files into Aseprite")
  
  -- Load resulting PNG(s)
  if createSeparateFrames then
    -- First scan for all frames to find max dimensions
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
    local sprite = app.open(firstFrame)
    if not sprite then
      showError("Failed to open first frame")
      return false
    end
    
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
        local hotspotX, hotspotY = 0, 0
        for line in meta:lines() do
          local key, value = line:match("(.+)=(.+)")
          if key == "hotspot_x" then hotspotX = tonumber(value) end
          if key == "hotspot_y" then hotspotY = tonumber(value) end
        end
        meta:close()
        
        app.command.GotoFrame{frame=1}
        app.command.FrameProperties{
          center=Point(hotspotX, hotspotY)
        }

        -- Create a special tag that will store hotspot info and show up visually in Aseprite
        local tagCreated = false
        local tagName = "hotspot_" .. hotspotX .. "_" .. hotspotY
        
        debug("Creating hotspot tag: " .. tagName)
        
        -- Method 1: Using app.sprite:newTag()
        if sprite.newTag then
          local tag = sprite:newTag(1, 1)
          if tag then
            tag.name = tagName
            tag.color = Color{ r=255, g=0, b=0 }
            debug("Created tag using sprite:newTag() method")
            tagCreated = true
          end
        end
        
        -- Method 2: Using FrameTagProperties if method 1 failed
        if not tagCreated then
          app.command.FrameTagProperties{
            name=tagName,
            color=Color{ r=255, g=0, b=0 },
            from=1,
            to=1
          }
          debug("Created tag using FrameTagProperties method")
        end

        debug("Created tag with hotspot data: hotspot_" .. hotspotX .. "_" .. hotspotY)
        
        -- Store hotspot data for first frame in global table
        if not _G.exultFrameData then _G.exultFrameData = {} end
        
        -- Store with BOTH possible key formats to ensure it's found during export
        local frameKey1 = sprite.filename .. "_1"
        local frameKey2 = sprite.filename .. "_0"
        _G.exultFrameData[frameKey1] = {
          hotspotX = hotspotX,
          hotspotY = hotspotY,
          width = sprite.width,
          height = sprite.height
        }
        _G.exultFrameData[frameKey2] = {
          hotspotX = hotspotX,
          hotspotY = hotspotY,
          width = sprite.width,
          height = sprite.height
        }
        
        debug("SINGLE FRAME: Stored hotspot data with keys:")
        debug("  " .. frameKey1 .. " = " .. hotspotX .. "," .. hotspotY)
        debug("  " .. frameKey2 .. " = " .. hotspotX .. "," .. hotspotY)
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
      
      -- Add new frame
      sprite:newFrame()
      app.command.GotoFrame{frame=frameIndex+1}
      
      -- Create new cel with this image
      local layer = sprite.layers[1]
      local cel = sprite:newCel(layer, frameIndex+1, frameImage, Point(0,0))
      
      -- Load and set pivot from metadata
      if app.fs.isFile(metaPath) then
        local meta = io.open(metaPath, "r")
        if meta then
          local hotspotX, hotspotY = 0, 0
          for line in meta:lines() do
            local key, value = line:match("(.+)=(.+)")
            if key == "hotspot_x" then hotspotX = tonumber(value) end
            if key == "hotspot_y" then hotspotY = tonumber(value) end
          end
          meta:close()
          
          -- Set frame center point (pivot)
          app.command.FrameProperties{
            center=Point(hotspotX, hotspotY)
          }
          
          -- Create a frame-specific tag that encodes the hotspot coordinates
          local tagName = string.format("hotspot_%d_%d_%d", frameIndex+1, hotspotX, hotspotY)
          local tagCreated = false
          
          debug("Creating frame-specific tag: " .. tagName)
          
          -- Method 1: Using app.sprite:newTag()
          if sprite.newTag then
            local tag = sprite:newTag(frameIndex+1, frameIndex+1)
            if tag then
              tag.name = tagName
              tag.color = Color{ r=255, g=0, b=0 }
              debug("Created tag using sprite:newTag() method")
              tagCreated = true
            end
          end
          
          -- Method 2: Using FrameTagProperties if method 1 failed
          if not tagCreated then
            app.command.FrameTagProperties{
              name=tagName,
              color=Color{ r=255, g=0, b=0 },
              from=frameIndex+1,
              to=frameIndex+1
            }
            debug("Created tag using FrameTagProperties method")
          end
          
          -- Store hotspot data in our global table
          local frameKey = sprite.filename .. "_" .. tostring(frameIndex+1)
          _G.exultFrameData[frameKey] = {
            hotspotX = hotspotX,
            hotspotY = hotspotY,
            width = frameImage.width,
            height = frameImage.height
          }
          debug("Stored hotspot data for " .. frameKey .. ": " .. hotspotX .. "," .. hotspotY)
        end
      end
      
      frameIndex = frameIndex + 1
    end
    
    return true
  else
    -- Convert single frame to separate frame for consistency
    debug("Converting single-frame SHP to use frame-based format")
    
    -- Re-run the import process but with separate frames
    local expCmd = quoteIfNeeded(converterPath) .. 
                 " import " .. 
                 quoteIfNeeded(shpFile) .. 
                 " " .. quoteIfNeeded(outputBasePath) ..
                 " separate" -- Force separate frames
    
    debug("Executing separate frame command: " .. expCmd)
    os.execute(expCmd)
    
    -- Process as regular frame-based import
    local firstFrame = actualOutputBase .. "_0.png"
    if app.fs.isFile(firstFrame) then
      debug("Successfully converted single-frame to frame-based format")
      
      -- Process exactly like multi-frame SHPs
      return processImport(shpFile, paletteFile, outputBasePath, true)
    else
      showError("Failed to convert single-frame SHP")
      return false
    end
  end
end

-- Export function 
function exportSHP()
  -- Get active sprite
  local sprite = app.activeSprite
  if not sprite then
    showError("No active sprite to export")
    return
  end
  
  -- Show export dialog
  local dlg = Dialog("Export SHP File")
  dlg:file{
    id="outFile",
    label="Output SHP File:",
    save=true,
    filetypes={"shp"},
    focus=true
  }
  dlg:check{
    id="useTransparency",
    label="Transparency:",
    text="Use transparent color (index 0)",
    selected=false
  }
  dlg:number{
    id="hotspotX",
    label="Hotspot X:",
    text=tostring(sprite.width / 2),
    decimals=0
  }
  dlg:number{
    id="hotspotY",
    label="Hotspot Y:",
    text=tostring(sprite.height / 2),
    decimals=0
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
      exportSettings.useTransparency = dlg.data.useTransparency
      exportSettings.hotspotX = dlg.data.hotspotX
      exportSettings.hotspotY = dlg.data.hotspotY
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
  
  -- Create temp directory for files
  local tempDir = app.fs.joinPath(app.fs.tempPath, "exult-shp-" .. os.time())
  app.fs.makeDirectory(tempDir)
  
  -- Prepare file paths
  local metaPath = app.fs.joinPath(tempDir, "metadata.txt")
  local basePath = app.fs.joinPath(tempDir, "frame")
  
  -- Create metadata file
  local meta = io.open(metaPath, "w")
  meta:write(string.format("num_frames=%d\n", #sprite.frames))
  
  -- Export each frame individually
  for i, frame in ipairs(sprite.frames) do
    local filepath = string.format("%s%d.png", basePath, i-1)
    
    -- Go to the frame we want to save in the original sprite
    app.command.GotoFrame{frame=frame.frameNumber}
    
    -- Get the cel directly
    local layer = sprite.layers[1]
    local cel = layer:cel(frame.frameNumber)
    
    -- Process the frame
    if cel and cel.image then
      -- Save the image directly
      cel.image:saveAs(filepath)
      debug("Directly saved frame " .. (i-1) .. " using image:saveAs")
    else
      debug("ERROR: Could not find cel/image for frame " .. (i-1))
    end
    
    -- Verify file was created
    if app.fs.isFile(filepath) then
      debug("Successfully saved frame " .. (i-1) .. " to: " .. filepath)
    else
      debug("ERROR: Failed to save frame " .. (i-1) .. " to: " .. filepath)
    end
    
    -- Check for frame-specific hotspot tags using format: hotspot_FRAME#_X_Y
    local frameNumber = frame.frameNumber
    local pivotFound = false
    local hotspotX = exportSettings.hotspotX
    local hotspotY = exportSettings.hotspotY
    
    -- First check all tags that mention this specific frame number
    for _, tag in ipairs(sprite.tags) do
      -- Look for pattern hotspot_FRAMENUMBER_X_Y
      local tagFrameNum, x, y = tag.name:match("^hotspot_(%d+)_(%d+)_(%d+)$")
      
      if tagFrameNum and tonumber(tagFrameNum) == frameNumber then
        hotspotX = tonumber(x)
        hotspotY = tonumber(y)
        pivotFound = true
        debug("Found frame-specific hotspot tag: " .. tag.name .. " with values " .. hotspotX .. "," .. hotspotY)
        break
      end
    end
    
    -- If no frame-specific tag was found, check the old formats
    if not pivotFound then
      for _, tag in ipairs(sprite.tags) do
        -- Only check tags that apply to this frame
        if tag.fromFrame.frameNumber <= frameNumber and 
           tag.toFrame.frameNumber >= frameNumber then
           
          -- Old format: hotspot_X_Y
          local x, y = tag.name:match("^hotspot_(%d+)_(%d+)$")
          if x and y then
            hotspotX = tonumber(x)
            hotspotY = tonumber(y)
            pivotFound = true
            debug("Using legacy hotspot tag format: " .. hotspotX .. "," .. hotspotY)
            break
          end
        end
      end
    end
    
    -- Only fall back to global table if no tag was found
    if not pivotFound and _G.exultFrameData then
      -- Special handling for single frames
      local frameKey = sprite.filename .. "_" .. tostring(frame.frameNumber)
      local storedData = _G.exultFrameData[frameKey]
      
      -- For single-frame SHPs, try with key "_1"
      if not storedData and #sprite.frames == 1 then
        frameKey = sprite.filename .. "_1"
        storedData = _G.exultFrameData[frameKey]
      end
      
      if storedData then
        hotspotX = storedData.hotspotX
        hotspotY = storedData.hotspotY
        debug("Using stored hotspot: " .. hotspotX .. "," .. hotspotY)
      end
    end
    
    -- Write metadata for pivot points
    meta:write(string.format("frame%d_hotspot_x=%d\n", i-1, hotspotX))
    meta:write(string.format("frame%d_hotspot_y=%d\n", i-1, hotspotY))
  end
  
  meta:close()
  
  local cmd = quoteIfNeeded(converterPath) .. 
             " export " .. 
             quoteIfNeeded(basePath) .. 
             " " .. quoteIfNeeded(exportSettings.outFile) .. 
             " " .. (exportSettings.useTransparency and "1" or "0") ..
             " " .. exportSettings.hotspotX ..
             " " .. exportSettings.hotspotY ..
             " " .. quoteIfNeeded(metaPath)
  
  debug("Executing: " .. cmd)
  
  if converterExists then
    debug("Converter found at: " .. converterPath)
    
    -- On Unix-like systems, try to ensure executable permission
    if app.fs.pathSeparator == "/" then
      os.execute("chmod +x " .. quoteIfNeeded(converterPath))
    end
  else
    debug("Converter NOT found at: " .. converterPath)
  end
  
  -- Execute command
  local success = os.execute(cmd)
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

-- Create a global table to store frame hotspot data across the entire plugin session
if not _G.exultFrameData then
  _G.exultFrameData = {}
end

return { init=init }