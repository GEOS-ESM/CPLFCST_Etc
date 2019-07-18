# NOTE There is no real "make" to do in CPLFCST_Etc. It's a set
#      of scripts and files. For now we just INSTALL

# Using MESSAGE_NEVER to not overwhelm the installation
# messages with all these installs
install (
   DIRECTORY .
   DESTINATION CPLFCST
   USE_SOURCE_PERMISSIONS
   MESSAGE_NEVER
   PATTERN "CMakeLists.txt" EXCLUDE
   )
