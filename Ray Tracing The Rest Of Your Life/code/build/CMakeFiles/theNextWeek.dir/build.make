# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.20

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Disable VCS-based implicit rules.
% : %,v

# Disable VCS-based implicit rules.
% : RCS/%

# Disable VCS-based implicit rules.
% : RCS/%,v

# Disable VCS-based implicit rules.
% : SCCS/s.%

# Disable VCS-based implicit rules.
% : s.%

.SUFFIXES: .hpux_make_needs_suffix_list

# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/local/Cellar/cmake/3.20.3/bin/cmake

# The command to remove a file.
RM = /usr/local/Cellar/cmake/3.20.3/bin/cmake -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code"

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build"

# Include any dependencies generated for this target.
include CMakeFiles/theNextWeek.dir/depend.make
# Include any dependencies generated by the compiler for this target.
include CMakeFiles/theNextWeek.dir/compiler_depend.make

# Include the progress variables for this target.
include CMakeFiles/theNextWeek.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/theNextWeek.dir/flags.make

CMakeFiles/theNextWeek.dir/RayTracing.cpp.o: CMakeFiles/theNextWeek.dir/flags.make
CMakeFiles/theNextWeek.dir/RayTracing.cpp.o: ../RayTracing.cpp
CMakeFiles/theNextWeek.dir/RayTracing.cpp.o: CMakeFiles/theNextWeek.dir/compiler_depend.ts
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir="/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object CMakeFiles/theNextWeek.dir/RayTracing.cpp.o"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -MD -MT CMakeFiles/theNextWeek.dir/RayTracing.cpp.o -MF CMakeFiles/theNextWeek.dir/RayTracing.cpp.o.d -o CMakeFiles/theNextWeek.dir/RayTracing.cpp.o -c "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/RayTracing.cpp"

CMakeFiles/theNextWeek.dir/RayTracing.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/theNextWeek.dir/RayTracing.cpp.i"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/RayTracing.cpp" > CMakeFiles/theNextWeek.dir/RayTracing.cpp.i

CMakeFiles/theNextWeek.dir/RayTracing.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/theNextWeek.dir/RayTracing.cpp.s"
	/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/c++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/RayTracing.cpp" -o CMakeFiles/theNextWeek.dir/RayTracing.cpp.s

# Object files for target theNextWeek
theNextWeek_OBJECTS = \
"CMakeFiles/theNextWeek.dir/RayTracing.cpp.o"

# External object files for target theNextWeek
theNextWeek_EXTERNAL_OBJECTS =

theNextWeek: CMakeFiles/theNextWeek.dir/RayTracing.cpp.o
theNextWeek: CMakeFiles/theNextWeek.dir/build.make
theNextWeek: CMakeFiles/theNextWeek.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir="/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build/CMakeFiles" --progress-num=$(CMAKE_PROGRESS_2) "Linking CXX executable theNextWeek"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/theNextWeek.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/theNextWeek.dir/build: theNextWeek
.PHONY : CMakeFiles/theNextWeek.dir/build

CMakeFiles/theNextWeek.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/theNextWeek.dir/cmake_clean.cmake
.PHONY : CMakeFiles/theNextWeek.dir/clean

CMakeFiles/theNextWeek.dir/depend:
	cd "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build" && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code" "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code" "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build" "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build" "/Users/huben/Desktop/Huris/MyGrowthPath/Computer Graphics/RayTracing/Ray Tracing The Next Week/code/build/CMakeFiles/theNextWeek.dir/DependInfo.cmake" --color=$(COLOR)
.PHONY : CMakeFiles/theNextWeek.dir/depend
