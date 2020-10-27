# Once done these will be defined:
#
#  AUDIOTOOLBOX_FOUND
#  AUDIOTOOLBOX_LIBRARIES

find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox)

set(AUDIOTOOLBOX_LIBRARIES ${AUDIOTOOLBOX_FRAMEWORK})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(AudioToolbox DEFAULT_MSG AUDIOTOOLBOX_FRAMEWORK)
mark_as_advanced(AUDIOTOOLBOX_FRAMEWORK)
