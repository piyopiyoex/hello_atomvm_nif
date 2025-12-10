set(ATOMVM_HELLO_NIF_COMPONENT_SRCS
    "nifs/hello_nif.c"
)

idf_component_register(
    SRCS ${ATOMVM_HELLO_NIF_COMPONENT_SRCS}
    INCLUDE_DIRS "nifs/include"
    PRIV_REQUIRES "libatomvm" "avm_sys"
)

idf_build_set_property(
    LINK_OPTIONS "-Wl,--whole-archive;${CMAKE_CURRENT_BINARY_DIR}/lib${COMPONENT_NAME}.a;-Wl,--no-whole-archive"
    APPEND
)

