#include "sample_app_hello.h"

#include <string.h>

#include <context.h>
#include <defaultatoms.h>
#include <nifs.h>
#include <portnifloader.h>
#include <term.h>

// #define ENABLE_TRACE
#include <trace.h>

static term make_error(Context *ctx, term reason)
{
    term t = term_alloc_tuple(2, &ctx->heap);
    term_put_tuple_element(t, 0, term_from_atom_index(ERROR_ATOM_INDEX));
    term_put_tuple_element(t, 1, reason);
    return t;
}

static term make_ok(Context *ctx)
{
    (void) ctx;
    return term_from_atom_index(OK_ATOM_INDEX);
}

static term make_ok_tuple(Context *ctx, term payload)
{
    term t = term_alloc_tuple(2, &ctx->heap);
    term_put_tuple_element(t, 0, term_from_atom_index(OK_ATOM_INDEX));
    term_put_tuple_element(t, 1, payload);
    return t;
}

// NIF implementation: Elixir.SampleApp.Hello:ping/0
static term ping_0(Context *ctx, int argc, term argv[])
{
    (void) argv;

    if (argc != 0) {
        return make_error(ctx, term_from_atom_index(BADARG_ATOM_INDEX));
    }

    return make_ok(ctx);
}

static const struct Nif ping_0_nif = {
    .base.type = NIFFunctionType,
    .nif_ptr = ping_0
};

// NIF implementation: Elixir.SampleApp.Hello:echo/1
static term echo_1(Context *ctx, int argc, term argv[])
{
    if (argc != 1 || !term_is_binary(argv[0])) {
        return make_error(ctx, term_from_atom_index(BADARG_ATOM_INDEX));
    }

    // Return the payload unchanged.
    return make_ok_tuple(ctx, argv[0]);
}

static const struct Nif echo_1_nif = {
    .base.type = NIFFunctionType,
    .nif_ptr = echo_1
};

// Resolve NIFs in this collection by name.
const struct Nif *sample_app_hello_get_nif(const char *nifname)
{
    TRACE("Locating NIF %s ...\n", nifname);

    // AtomVM uses "Elixir.Module:fun/arity" for NIF names.
    if (strcmp("Elixir.SampleApp.Hello:ping/0", nifname) == 0) {
        TRACE("Resolved NIF %s\n", nifname);
        return &ping_0_nif;
    }

    if (strcmp("Elixir.SampleApp.Hello:echo/1", nifname) == 0) {
        TRACE("Resolved NIF %s\n", nifname);
        return &echo_1_nif;
    }

    return NULL;
}

static void sample_app_hello_init(GlobalContext *global)
{
    (void) global;
    TRACE("sample_app_hello_init\n");
}

static void sample_app_hello_destroy(GlobalContext *global)
{
    (void) global;
    TRACE("sample_app_hello_destroy\n");
}

// Register this NIF collection with AtomVM.
REGISTER_NIF_COLLECTION(
    sample_app_hello,
    sample_app_hello_init,
    sample_app_hello_destroy,
    sample_app_hello_get_nif)
