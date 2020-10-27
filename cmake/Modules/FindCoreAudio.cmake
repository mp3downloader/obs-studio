# Once done these will be defined:
#
#  COREAUDIO_FOUND
#  COREAUDIO_LIBRARIES

find_library(COREAUDIO_FRAMEWORK CoreAudio)

set(COREAUDIO_LIBRARIES ${COREAUDIO_FRAMEWORK})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CoreAudio DEFAULT_MSG COREAUDIO_FRAMEWORK)
mark_as_advanced(COREAUDIO_FRAMEWORK)
