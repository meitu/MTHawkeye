//
// Copyright (c) 2008-present, Meitu, Inc.
// All rights reserved.
//
// This source code is licensed under the license found in the LICENSE file in
// the root directory of this source tree.
//
// Created on: 2018/7/19
// Created by: EuanC
//


#ifndef mtha_locking_h
#define mtha_locking_h

#include <libkern/OSAtomic.h>
#include <os/lock.h>
#include <pthread/pthread.h>


#if 0 // only available in the furture

typedef os_unfair_lock _malloc_lock_s;
#define _MALLOC_LOCK_INIT OS_UNFAIR_LOCK_INIT

__attribute__((always_inline)) static inline void _malloc_lock_init(_malloc_lock_s *lock) {
    *lock = OS_UNFAIR_LOCK_INIT;
}

__attribute__((always_inline)) static inline void _malloc_lock_lock(_malloc_lock_s *lock) {
    return os_unfair_lock_lock(lock);
}

__attribute__((always_inline)) static inline bool _malloc_lock_trylock(_malloc_lock_s *lock) {
    return os_unfair_lock_trylock(lock);
}

__attribute__((always_inline)) static inline void _malloc_lock_unlock(_malloc_lock_s *lock) {
    return os_unfair_lock_unlock(lock);
}

// use pthread_mutex_ under iOS 10.0
#else

typedef pthread_mutex_t _malloc_lock_s;
#define _MALLOC_LOCK_INIT PTHREAD_MUTEX_INITIALIZER

__attribute__((always_inline)) static inline void _malloc_lock_init(_malloc_lock_s *lock) {
    _malloc_lock_s _os_lock_handoff_init;
    pthread_mutex_init(&_os_lock_handoff_init, NULL);
    *lock = _os_lock_handoff_init;
}

__attribute__((always_inline)) static inline int _malloc_lock_lock(_malloc_lock_s *lock) {
    return pthread_mutex_lock(lock);
}

__attribute__((always_inline)) static inline int _malloc_lock_trylock(_malloc_lock_s *lock) {
    return pthread_mutex_trylock(lock);
}

__attribute__((always_inline)) static inline int _malloc_lock_unlock(_malloc_lock_s *lock) {
    return pthread_mutex_unlock(lock);
}

#endif //


////////////////////////////////////////
/// MARK: -

#if defined(__i386__) || defined(__x86_64__)

#if defined(__has_attribute)
#if __has_attribute(address_space)
#define OS_GS_RELATIVE __attribute__((address_space(256)))
#endif
#endif

#ifdef OS_GS_RELATIVE
#define _os_tsd_get_base() ((void *OS_GS_RELATIVE *)0)
#else
__attribute__((always_inline)) __inline__ void *
    _os_tsd_get_direct(unsigned long slot) {
    void *ret;
    __asm__("mov %%gs:%1, %0"
            : "=r"(ret)
            : "m"(*(void **)(slot * sizeof(void *))));
    return ret;
}

__attribute__((always_inline)) __inline__ int
    _os_tsd_set_direct(unsigned long slot, void *val) {
#if defined(__i386__) && defined(__PIC__)
    __asm__("movl %1, %%gs:%0"
            : "=m"(*(void **)(slot * sizeof(void *)))
            : "rn"(val));
#elif defined(__i386__) && !defined(__PIC__)
    __asm__("movl %1, %%gs:%0"
            : "=m"(*(void **)(slot * sizeof(void *)))
            : "ri"(val));
#else
    __asm__("movq %1, %%gs:%0"
            : "=m"(*(void **)(slot * sizeof(void *)))
            : "rn"(val));
#endif
    return 0;
}
#endif

#elif defined(__arm__) || defined(__arm64__)

__attribute__((always_inline, pure)) static __inline__ void **
    _os_tsd_get_base(void) {
#if defined(__arm__) && defined(_ARM_ARCH_6)
    uintptr_t tsd;
    __asm__("mrc p15, 0, %0, c13, c0, 3"
            : "=r"(tsd));
    tsd &= ~0x3ul; /* lower 2-bits contain CPU number */
#elif defined(__arm__) && defined(_ARM_ARCH_5)
    register uintptr_t tsd asm("r9");
#elif defined(__arm64__)
    uint64_t tsd;
    __asm__("mrs %0, TPIDRRO_EL0"
            : "=r"(tsd));
    tsd &= ~0x7ull;
#endif

    return (void **)(uintptr_t)tsd;
}
#define _os_tsd_get_base() _os_tsd_get_base()

#else
#error _os_tsd_get_base not implemented on this architecture
#endif

#ifdef _os_tsd_get_base
__attribute__((always_inline)) __inline__ void *
    _os_tsd_get_direct(unsigned long slot) {
    return _os_tsd_get_base()[slot];
}

__attribute__((always_inline)) __inline__ int
    _os_tsd_set_direct(unsigned long slot, void *val) {
    _os_tsd_get_base()[slot] = val;
    return 0;
}
#endif


#endif /* mtha_locking_h */
