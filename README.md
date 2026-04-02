# FileWorkbench

This was/is intended to be a file renamer, tag editor and file processing tool offering:
+ Search / Replace
+ Common Case operations
+ Pascal Style string operations
+ Load a variety of metadata into a grid.  Use Column names in the string operations
+ User can create scripts

This is a rewrite of an existing hobby codebase - The first version was entirely complete, but I stupidly/lazily used third party components belonging to my employer (DevEx controls). 

Metatags supported by the first version:
+ EXIF
+ ID3
+ Media Metadata
+ NTFS Storages
+ Kodi style nfo tags (tvshow and episode only at this time)

# Current status
Metadata loading and viewing in grid is complete
Grid export to csv or clipboard is complete
Renaming and metadata saving is not yet implemented.  

# Notes
This project has been used as a framework for video processing.  After I had ffprobe implemented to read video metadata, I was presented with a project requiring video processing based on existing metadata.  Most of the code had alrady been implemented in FileRenamer2, so I used this project for that...

This is my first multi-threaded project.  I keep hacking in additional processing in the main thread, then am slowly work back through them migrating them to worker threads...

# History
2026-04-02: Renamed project to FileWorkbench.  Clearly File Renaming isn't a current priority to me...
