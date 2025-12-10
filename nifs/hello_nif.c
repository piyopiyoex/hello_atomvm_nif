#include "hello_nif.h"

#include <context.h>
#include <defaultatoms.h>
#include <nifs.h>
#include <portnifloader.h>
#include <term.h>

#include <string.h>

// #define ENABLE_TRACE
#include <trace.h>

// NIF implementation: Elixir.HelloNif.hello/0
static term hello_nif_hello(Context *ctx, int argc, term argv[])
{
    (void) ctx;
    (void) argc;
    (void) argv;

    // Minimal “it works” example: just return an integer.
    return term_from_int(1234);
}

static const struct Nif hello_nif_hello_nif = {
    .base.type = NIFFunctionType,
    .nif_ptr = hello_nif_hello
};

// Resolve NIFs in this collection by name.
const struct Nif *hello_nif_get_nif(const char *nifname)
{
    TRACE("Locating NIF %s ...\n", nifname);

    // AtomVM uses "Module:fun/arity" for NIF names.
    if (strcmp("Elixir.HelloNif:hello/0", nifname) == 0) {
        TRACE("Resolved NIF %s\n", nifname);
        return &hello_nif_hello_nif;
    }

    return NULL;
}

// Register this NIF collection with AtomVM.
REGISTER_NIF_COLLECTION(atomvm_hello_nif, NULL, NULL, hello_nif_get_nif)
