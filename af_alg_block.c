// af_alg_block.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>

static int (*real_socket)(int, int, int) = NULL;

static void resolve_socket(void) {
    if (real_socket)
        return;
    real_socket = dlsym(RTLD_NEXT, "socket");
    if (!real_socket) {
        fprintf(stderr, "af_alg_block: dlsym(RTLD_NEXT, \"socket\") failed\n");
        _exit(1);
    }
}

int socket(int domain, int type, int protocol) {
    resolve_socket();

    if (domain == AF_ALG) {
        errno = EAFNOSUPPORT;
        return -1;
    }

    return real_socket(domain, type, protocol);
}
