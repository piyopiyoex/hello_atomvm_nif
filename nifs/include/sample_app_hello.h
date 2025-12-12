#ifndef __SAMPLE_APP_HELLO_H__
#define __SAMPLE_APP_HELLO_H__

#include <nifs.h>

#ifdef __cplusplus
extern "C" {
#endif

const struct Nif *sample_app_hello_get_nif(const char *nifname);

#ifdef __cplusplus
}
#endif

#endif
