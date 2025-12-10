#ifndef __HELLO_NIF_H__
#define __HELLO_NIF_H__

#include <nifs.h>

// Minimal AtomVM NIF collection for Elixir.HelloNif.
const struct Nif *hello_nif_get_nif(const char *nifname);

#endif
