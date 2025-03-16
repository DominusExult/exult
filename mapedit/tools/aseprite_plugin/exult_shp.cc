#include "U7obj.h"
#include "databuf.h"
#include "ibuf8.h"
#include "ignore_unused_variable_warning.h"
#include "vgafile.h"
#include <png.h>
#include <string>
#include <memory>
#include <vector>
#include <iostream>
#include <cstring>

// Default Exult palette - copied from u7shp-old.cc
static unsigned char DefaultPalette[768] = {
    0x00, 0x00, 0x00, 0xF8, 0xF0, 0xCC, 0xF4, 0xE4, 0xA4, 0xF0, 0xDC, 0x78,
		0xEC, 0xD0, 0x50, 0xEC, 0xC8, 0x28, 0xD8, 0xAC, 0x20, 0xC4, 0x94, 0x18,
		0xB0, 0x80, 0x10, 0x9C, 0x68, 0x0C, 0x88, 0x54, 0x08, 0x74, 0x44, 0x04,
		0x60, 0x30, 0x00, 0x4C, 0x24, 0x00, 0x38, 0x14, 0x00, 0xF8, 0xFC, 0xFC,
		0xFC, 0xD8, 0xD8, 0xFC, 0xB8, 0xB8, 0xFC, 0x98, 0x9C, 0xFC, 0x78, 0x80,
		0xFC, 0x58, 0x64, 0xFC, 0x38, 0x4C, 0xFC, 0x1C, 0x34, 0xDC, 0x14, 0x28,
		0xC0, 0x0C, 0x1C, 0xA4, 0x08, 0x14, 0x88, 0x04, 0x0C, 0x6C, 0x00, 0x04,
		0x50, 0x00, 0x00, 0x34, 0x00, 0x00, 0x18, 0x00, 0x00, 0xFC, 0xEC, 0xD8,
		0xFC, 0xDC, 0xB8, 0xFC, 0xCC, 0x98, 0xFC, 0xBC, 0x7C, 0xFC, 0xAC, 0x5C,
		0xFC, 0x9C, 0x3C, 0xFC, 0x8C, 0x1C, 0xFC, 0x7C, 0x00, 0xE0, 0x6C, 0x00,
		0xC0, 0x60, 0x00, 0xA4, 0x50, 0x00, 0x88, 0x44, 0x00, 0x6C, 0x34, 0x00,
		0x50, 0x24, 0x00, 0x34, 0x18, 0x00, 0x18, 0x08, 0x00, 0xFC, 0xFC, 0xD8,
		0xF4, 0xF4, 0x9C, 0xEC, 0xEC, 0x60, 0xE4, 0xE4, 0x2C, 0xDC, 0xDC, 0x00,
		0xC0, 0xC0, 0x00, 0xA4, 0xA4, 0x00, 0x88, 0x88, 0x00, 0x6C, 0x6C, 0x00,
		0x50, 0x50, 0x00, 0x34, 0x34, 0x00, 0x18, 0x18, 0x00, 0xD8, 0xFC, 0xD8,
		0xB0, 0xFC, 0xAC, 0x8C, 0xFC, 0x80, 0x6C, 0xFC, 0x54, 0x50, 0xFC, 0x28,
		0x38, 0xFC, 0x00, 0x28, 0xDC, 0x00, 0x1C, 0xC0, 0x00, 0x14, 0xA4, 0x00,
		0x0C, 0x88, 0x00, 0x04, 0x6C, 0x00, 0x00, 0x50, 0x00, 0x00, 0x34, 0x00,
		0x00, 0x18, 0x00, 0xD4, 0xD8, 0xFC, 0xB8, 0xB8, 0xFC, 0x98, 0x98, 0xFC,
		0x7C, 0x7C, 0xFC, 0x5C, 0x5C, 0xFC, 0x3C, 0x3C, 0xFC, 0x00, 0x00, 0xFC,
		0x00, 0x00, 0xE0, 0x00, 0x00, 0xC0, 0x00, 0x00, 0xA4, 0x00, 0x00, 0x88,
		0x00, 0x00, 0x6C, 0x00, 0x00, 0x50, 0x00, 0x00, 0x34, 0x00, 0x00, 0x18,
		0xE8, 0xC8, 0xE8, 0xD4, 0x98, 0xD4, 0xC4, 0x6C, 0xC4, 0xB0, 0x48, 0xB0,
		0xA0, 0x28, 0xA0, 0x8C, 0x10, 0x8C, 0x7C, 0x00, 0x7C, 0x6C, 0x00, 0x6C,
		0x60, 0x00, 0x60, 0x50, 0x00, 0x50, 0x44, 0x00, 0x44, 0x34, 0x00, 0x34,
		0x24, 0x00, 0x24, 0x18, 0x00, 0x18, 0xF4, 0xE8, 0xE4, 0xEC, 0xDC, 0xD4,
		0xE4, 0xCC, 0xC0, 0xE0, 0xC0, 0xB0, 0xD8, 0xB0, 0xA0, 0xD0, 0xA4, 0x90,
		0xC8, 0x98, 0x80, 0xC4, 0x8C, 0x74, 0xAC, 0x7C, 0x64, 0x98, 0x6C, 0x58,
		0x80, 0x5C, 0x4C, 0x6C, 0x4C, 0x3C, 0x54, 0x3C, 0x30, 0x3C, 0x2C, 0x24,
		0x28, 0x1C, 0x14, 0x10, 0x0C, 0x08, 0xEC, 0xEC, 0xEC, 0xDC, 0xDC, 0xDC,
		0xCC, 0xCC, 0xCC, 0xBC, 0xBC, 0xBC, 0xAC, 0xAC, 0xAC, 0x9C, 0x9C, 0x9C,
		0x8C, 0x8C, 0x8C, 0x7C, 0x7C, 0x7C, 0x6C, 0x6C, 0x6C, 0x60, 0x60, 0x60,
		0x50, 0x50, 0x50, 0x44, 0x44, 0x44, 0x34, 0x34, 0x34, 0x24, 0x24, 0x24,
		0x18, 0x18, 0x18, 0x08, 0x08, 0x08, 0xE8, 0xE0, 0xD4, 0xD8, 0xC8, 0xB0,
		0xC8, 0xB0, 0x90, 0xB8, 0x98, 0x70, 0xA8, 0x84, 0x58, 0x98, 0x70, 0x40,
		0x88, 0x5C, 0x2C, 0x7C, 0x4C, 0x18, 0x6C, 0x3C, 0x0C, 0x5C, 0x34, 0x0C,
		0x4C, 0x2C, 0x0C, 0x3C, 0x24, 0x0C, 0x2C, 0x1C, 0x08, 0x20, 0x14, 0x08,
		0xEC, 0xE8, 0xE4, 0xDC, 0xD4, 0xD0, 0xCC, 0xC4, 0xBC, 0xBC, 0xB0, 0xAC,
		0xAC, 0xA0, 0x98, 0x9C, 0x90, 0x88, 0x8C, 0x80, 0x78, 0x7C, 0x70, 0x68,
		0x6C, 0x60, 0x5C, 0x60, 0x54, 0x50, 0x50, 0x48, 0x44, 0x44, 0x3C, 0x38,
		0x34, 0x30, 0x2C, 0x24, 0x20, 0x20, 0x18, 0x14, 0x14, 0xE0, 0xE8, 0xD4,
		0xC8, 0xD4, 0xB4, 0xB4, 0xC0, 0x98, 0x9C, 0xAC, 0x7C, 0x88, 0x98, 0x60,
		0x70, 0x84, 0x4C, 0x5C, 0x70, 0x38, 0x4C, 0x5C, 0x28, 0x40, 0x50, 0x20,
		0x38, 0x44, 0x1C, 0x30, 0x3C, 0x18, 0x28, 0x30, 0x14, 0x20, 0x24, 0x10,
		0x18, 0x1C, 0x08, 0x0C, 0x10, 0x04, 0xEC, 0xD8, 0xCC, 0xDC, 0xB8, 0xA0,
		0xCC, 0x98, 0x7C, 0xBC, 0x80, 0x5C, 0xAC, 0x64, 0x3C, 0x9C, 0x50, 0x24,
		0x8C, 0x3C, 0x0C, 0x7C, 0x2C, 0x00, 0x6C, 0x24, 0x00, 0x60, 0x20, 0x00,
		0x50, 0x1C, 0x00, 0x44, 0x14, 0x00, 0x34, 0x10, 0x00, 0x24, 0x0C, 0x00,
		0xF0, 0xF0, 0xFC, 0xE4, 0xE4, 0xFC, 0xD8, 0xD8, 0xFC, 0xCC, 0xCC, 0xFC,
		0xC0, 0xC0, 0xFC, 0xB4, 0xB4, 0xFC, 0xA8, 0xA8, 0xFC, 0x9C, 0x9C, 0xFC,
		0x84, 0xD0, 0x00, 0x84, 0xB0, 0x00, 0x7C, 0x94, 0x00, 0x68, 0x78, 0x00,
		0x50, 0x58, 0x00, 0x3C, 0x40, 0x00, 0x2C, 0x24, 0x00, 0x1C, 0x08, 0x00,
		0x20, 0x00, 0x00, 0xEC, 0xD8, 0xC4, 0xDC, 0xC0, 0xB4, 0xCC, 0xB4, 0xA0,
		0xBC, 0x9C, 0x94, 0xAC, 0x90, 0x80, 0x9C, 0x84, 0x74, 0x8C, 0x74, 0x64,
		0x7C, 0x64, 0x58, 0x6C, 0x54, 0x4C, 0x60, 0x48, 0x44, 0x50, 0x40, 0x38,
		0x44, 0x34, 0x2C, 0x34, 0x2C, 0x24, 0x24, 0x18, 0x18, 0x18, 0x10, 0x10,
		0xFC, 0xF8, 0xFC, 0xAC, 0xD4, 0xF0, 0x70, 0xAC, 0xE4, 0x34, 0x8C, 0xD8,
		0x00, 0x6C, 0xD0, 0x30, 0x8C, 0xD8, 0x6C, 0xB0, 0xE4, 0xB0, 0xD4, 0xF0,
		0xFC, 0xFC, 0xF8, 0xFC, 0xEC, 0x40, 0xFC, 0xC0, 0x28, 0xFC, 0x8C, 0x10,
		0xFC, 0x50, 0x00, 0xC8, 0x38, 0x00, 0x98, 0x28, 0x00, 0x68, 0x18, 0x00,
		0x7C, 0xDC, 0x7C, 0x44, 0xB4, 0x44, 0x18, 0x90, 0x18, 0x00, 0x6C, 0x00,
		0xF8, 0xB8, 0xFC, 0xFC, 0x64, 0xEC, 0xFC, 0x00, 0xB4, 0xCC, 0x00, 0x70,
		0xFC, 0xFC, 0x00, 0x00, 0x00, 0xFF, 0x00, 0xFC, 0x00, 0xFC, 0x00, 0x00,
		0xFC, 0xFC, 0xFC, 0x61, 0x61, 0x61, 0xC0, 0xC0, 0xC0, 0xFC, 0x00, 0xF1
};

// Function prototype
bool saveFrameToPNG(const char* filename, const unsigned char* data, int width, int height, unsigned char* palette);

// Function to import SHP to PNG
bool importSHP(const char* shpFilename, const char* outputPngFilename, const char* paletteFile, bool createSeparateFiles) {
    // Load palette - either from specified file or use default game palette
    unsigned char palette[768];
    
    if (strlen(paletteFile) > 0) {
        // Load from specified palette file
        U7object pal_obj(paletteFile, 0);
        size_t len;
        auto buf = pal_obj.retrieve(len);
        if (buf && len >= 768) {
            std::memcpy(palette, buf.get(), 768);
            std::cout << "Using palette from file: " << paletteFile << std::endl;
        } else {
            std::cerr << "Warning: Could not load palette file, using default" << std::endl;
            // Use default palette as fallback
            std::memcpy(palette, DefaultPalette, 768);
        }
    } else {
        // Always use the default palette
        std::memcpy(palette, DefaultPalette, 768);
        std::cout << "Using default palette" << std::endl;
    }
    
    // Extract the base filename from shpFilename (remove path and extension)
    std::string baseFilename = shpFilename;
    
    // Remove path if present
    size_t lastSlash = baseFilename.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        baseFilename = baseFilename.substr(lastSlash + 1);
    }
    
    // Remove extension if present
    size_t lastDot = baseFilename.find_last_of(".");
    if (lastDot != std::string::npos) {
        baseFilename = baseFilename.substr(0, lastDot);
    }
    
    // Create output directory path if needed
    std::string outputDir = "";
    
    // Extract directory from outputPngFilename if there is one
    std::string outputPath = outputPngFilename;
    size_t lastPathSep = outputPath.find_last_of("/\\");
    if (lastPathSep != std::string::npos) {
        outputDir = outputPath.substr(0, lastPathSep + 1);
    }
    
    // Combine output directory with base filename
    std::string finalOutputBase = outputDir + baseFilename;
    
    // Log the filename extraction
    std::cout << "Using base filename: " << baseFilename << std::endl;
    std::cout << "Final output base: " << finalOutputBase << std::endl;
    
    // Load SHP file using Shape_file constructor
    Shape_file shape(shpFilename);

    int frameCount = shape.get_num_frames();
    if (frameCount == 0) {
        std::cerr << "Error: No frames found in SHP file" << std::endl;
        return false;
    }

    // Find max dimensions
    int width = 0;
    int height = 0;
    for (int i = 0; i < frameCount; i++) {
        Shape_frame* frame = shape.get_frame(i);
        if (!frame) continue;
        width = std::max(width, frame->get_width());
        height = std::max(height, frame->get_height());
    }

    if (createSeparateFiles) {
        // Create individual PNG for each frame
        for (int i = 0; i < frameCount; i++) {
            Shape_frame* frame = shape.get_frame(i);
            if (!frame) continue;

            // Use baseFilename instead of outputPngFilename
            std::string frameFilename = finalOutputBase + "_" + std::to_string(i) + ".png";
            std::string metadataFilename = finalOutputBase + "_" + std::to_string(i) + ".meta";

            // Get frame data and dimensions - make sure to get the actual dimensions for this frame
            int frameWidth = frame->get_width();
            int frameHeight = frame->get_height();
            int hotspot_x = frame->get_xleft();
            int hotspot_y = frame->get_yabove();
            
            // Debug output for frame dimensions
            std::cout << "Frame " << i << " dimensions: " << frameWidth << "x" << frameHeight << std::endl;

            // Write frame info to metadata file
            FILE* metaFile = fopen(metadataFilename.c_str(), "w");
            if (metaFile) {
                // Write frame dimensions to metadata
                fprintf(metaFile, "frame_width=%d\nframe_height=%d\n", frameWidth, frameHeight);
                
                // Calculate hotspot and offsets
                int xoff = -hotspot_x;
                int yoff = -hotspot_y;
                
                // Write hotspot and offset info
                fprintf(metaFile, "hotspot_x=%d\nhotspot_y=%d\n", hotspot_x, hotspot_y);
                fprintf(metaFile, "offset_x=%d\noffset_y=%d\n", xoff, yoff);
                fclose(metaFile);
            }
            
            // Create an image buffer with the CORRECT dimensions for this frame
            Image_buffer8 imagebuf(frameWidth, frameHeight);
            
            // Fill with index 255 for transparency
            imagebuf.fill8(255);
            
            // Paint with x_offset=hotspot_x, y_offset=hotspot_y to position correctly
            frame->paint(&imagebuf, hotspot_x, hotspot_y);
            const unsigned char* pixels = imagebuf.get_bits();
            
            // Create PNG from frame data with the correct dimensions
            if (!saveFrameToPNG(frameFilename.c_str(), pixels, frameWidth, frameHeight, palette)) {
                std::cerr << "Error: Failed to save frame " << i << " to PNG" << std::endl;
                return false;
            }
        }
    } else {
        // Create single spritesheet PNG
        std::string metadataFilename = finalOutputBase + ".meta";
        FILE* metaFile = fopen(metadataFilename.c_str(), "w");
        if (metaFile) {
            fprintf(metaFile, "num_frames=%d\nwidth=%d\nheight=%d\n",
                    frameCount, width, height);

            for (int i = 0; i < frameCount; i++) {
                Shape_frame* frame = shape.get_frame(i);
                if (!frame) continue;
                
                // Calculate hotspot and offsets
                int hotspot_x = frame->get_xleft();
                int hotspot_y = frame->get_yabove();
                
                // Use the same offset calculation for both RLE and flat frames
                int xoff = -hotspot_x;
                int yoff = -hotspot_y;
                
                // Write info to metadata file
                fprintf(metaFile, "frame%d_hotspot_x=%d\nframe%d_hotspot_y=%d\n",
                        i, hotspot_x, i, hotspot_y);
                fprintf(metaFile, "frame%d_offset_x=%d\nframe%d_offset_y=%d\n",
                        i, xoff, i, yoff);
            }
            fclose(metaFile);
        }

        // Use finalOutputBase for the spritesheet output too
        std::string spritesheetFilename = finalOutputBase + ".png";
        
        std::cerr << "Spritesheet saving not yet implemented" << std::endl;
        return false;
    }

    return true;
}

// Function to save a frame to a PNG file
bool saveFrameToPNG(const char* filename, const unsigned char* data, int width, int height, unsigned char* palette) {
    // Create file for writing
    FILE* fp = fopen(filename, "wb");
    if (!fp) {
        std::cerr << "Error: Failed to open file for writing: " << filename << std::endl;
        return false;
    }

    // Initialize libpng structures
    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    if (!png_ptr) {
        fclose(fp);
        return false;
    }

    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) {
        png_destroy_write_struct(&png_ptr, nullptr);
        fclose(fp);
        return false;
    }

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        fclose(fp);
        return false;
    }

    png_init_io(png_ptr, fp);

    // Set image attributes for indexed color PNG
    png_set_IHDR(
        png_ptr,
        info_ptr,
        width,
        height,
        8, // bit depth
        PNG_COLOR_TYPE_PALETTE,
        PNG_INTERLACE_NONE,
        PNG_COMPRESSION_TYPE_DEFAULT,
        PNG_FILTER_TYPE_DEFAULT
    );

    // Set up the palette
    png_color png_palette[256];
    for (int i = 0; i < 256; i++) {
        png_palette[i].red = palette[i * 3];
        png_palette[i].green = palette[i * 3 + 1];
        png_palette[i].blue = palette[i * 3 + 2];
    }
    
    png_set_PLTE(png_ptr, info_ptr, png_palette, 256);

    // Create full transparency array - 0 is fully transparent, 255 is fully opaque
    png_byte trans[256];
    for (int i = 0; i < 256; i++) {
        // Make only index 255 transparent
        trans[i] = (i == 255) ? 0 : 255;
    }
    
    // Set transparency for all palette entries, with index 255 being transparent
    png_set_tRNS(png_ptr, info_ptr, trans, 256, nullptr);

    // Write the PNG info
    png_write_info(png_ptr, info_ptr);

    // Allocate memory for row pointers
    std::vector<png_bytep> row_pointers(height);
    for (int y = 0; y < height; ++y) {
        row_pointers[y] = const_cast<png_bytep>(&data[y * width]);
    }

    // Write image data
    png_write_image(png_ptr, row_pointers.data());
    png_write_end(png_ptr, nullptr);

    // Clean up
    png_destroy_write_struct(&png_ptr, &info_ptr);
    fclose(fp);

    std::cout << "Successfully saved PNG: " << filename << std::endl;
    return true;
}

// Function to export PNG to SHP
bool exportSHP(const char* pngFilename, const char* outputShpFilename, bool useTransparency,
               int hotspotX, int hotspotY, const char* metadataFile) {
    std::cerr << "Exporting SHP is not yet implemented" << std::endl;
    return false;
}

// Main function unchanged
int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cout << "Usage:" << std::endl;
        std::cout << "  Import mode: " << argv[0] << " import <shp_file> <output_png> [palette_file] [separate]" << std::endl;
        std::cout << "  Export mode: " << argv[0] << " export <png_file> <output_shp> [use_transparency] [hotspot_x] [hotspot_y] [metadata_file]" << std::endl;
        std::cout << "  Experimental mode: " << argv[0] << " experimental <shp_file> <output_png>" << std::endl;
        return 1;
    }

    std::string mode = argv[1];

    if (mode == "import") {
        if (argc < 4) {
            std::cerr << "Import mode requires SHP file and output path" << std::endl;
            return 1;
        }

        const char* shpFilename = argv[2];
        const char* outputPath = argv[3];

        // Handle optional parameters
        const char* paletteFile = "";
        bool separateFrames = true;  // Default to separate frames

        // Parse remaining arguments
        for (int i = 4; i < argc; i++) {
            if (strcmp(argv[i], "separate") == 0) {
                separateFrames = true;
            } else if (argv[i][0] != '\0') {
                paletteFile = argv[i];
            }
        }

        std::cout << "Loading SHP file: " << shpFilename << std::endl;
        std::cout << "Output path: " << outputPath << std::endl;
        std::cout << "Palette file: " << (strlen(paletteFile) > 0 ? paletteFile : "default") << std::endl;
        std::cout << "Separate frames: " << (separateFrames ? "yes" : "no") << std::endl;

        if (!importSHP(shpFilename, outputPath, paletteFile, separateFrames)) {
            std::cerr << "Failed to import SHP" << std::endl;
            return 1;
        }

        return 0;
    } else if (mode == "export") {
        const char* pngFilename = argv[2];
        const char* shpOutput = argv[3];
        bool useTransparency = (argc > 4) ? (strcmp(argv[4], "1") == 0) : true;
        int hotspotX = (argc > 5) ? atoi(argv[5]) : 0;
        int hotspotY = (argc > 6) ? atoi(argv[6]) : 0;
        const char* metadataFile = (argc > 7) ? argv[7] : nullptr;

        if (exportSHP(pngFilename, shpOutput, useTransparency, hotspotX, hotspotY, metadataFile)) {
            std::cout << "Successfully converted PNG to SHP" << std::endl;
            return 0;
        } else {
            std::cerr << "Failed to convert PNG to SHP" << std::endl;
            return 1;
        }
    } else if (mode == "experimental") {
        std::cerr << "Experimental mode is not longer supported" << std::endl;
        return 1;
    } else {
        std::cerr << "Unknown mode. Use 'import' or 'export'." << std::endl;
        return 1;
    }
}