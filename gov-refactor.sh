(base) obinexus@OBINexusPC:~/obinexus/pkg/gov-std-web$ chmod +x refactor.sh
(base) obinexus@OBINexusPC:~/obinexus/pkg/gov-std-web$ ./refactor.sh
./refactor.sh: line 1: schemas/: Is a directory
./refactor.sh: line 3: To: command not found
CMake Error at /usr/share/cmake-3.25/Modules/FindPackageHandleStandardArgs.cmake:230 (message):
  Could NOT find PkgConfig (missing: PKG_CONFIG_EXECUTABLE)
Call Stack (most recent call first):
  /usr/share/cmake-3.25/Modules/FindPackageHandleStandardArgs.cmake:600 (_FPHSA_FAILURE_MESSAGE)
  /usr/share/cmake-3.25/Modules/FindPkgConfig.cmake:99 (find_package_handle_standard_args)
  CMakeLists.txt:18 (find_package)


-- Configuring incomplete, 
errors occurred! See also 
"/home/obinexus/obinexus/pkg/gov-std-web/build/CMakeFiles/CMakeOutput.log". 
make: *** No targets 
specified and no makefile 
found.  Stop. ./refactor.sh: 
line 8: Or: command not found 
make: *** No rule to make 
target 'debug'.  Stop. make: 
*** No rule to make target 
'test'.  Stop. make: *** No 
rule to make target 
'validate-manifest'.  Stop. 
./refactor.sh: line 12: 
./gov-refactor.sh:: No such 
file or direc
