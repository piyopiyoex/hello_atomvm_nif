idf_component_register(
    SRCS "nifs/sample_app_hello.c"
    INCLUDE_DIRS "nifs/include"
    PRIV_REQUIRES "libatomvm" "avm_sys"
)

# Ensure the NIF collection registration object is not discarded by the linker.
# Without whole-archive, the REGISTER_NIF_COLLECTION(...) symbol can be GC'd if
# nothing in the app directly references it.
idf_build_set_property(
    LINK_OPTIONS
        "-Wl,--whole-archive;${CMAKE_CURRENT_BINARY_DIR}/lib${COMPONENT_NAME}.a;-Wl,--no-whole-archive"
    APPEND
)
