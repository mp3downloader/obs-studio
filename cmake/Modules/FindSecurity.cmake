# Once done these will be defined:
#
#  SECURITY_FOUND
#  SECURITY_LIBRARIES

find_library(SECURITY_FRAMEWORK Security)

set(SECURITY_LIBRARIES ${SECURITY_FRAMEWORK})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Security DEFAULT_MSG SECURITY_FRAMEWORK)
mark_as_advanced(SECURITY_FRAMEWORK)
