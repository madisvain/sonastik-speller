/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 *
 * C ABI over Filosoft Vabamorf. One vm_speller, one thread.
 * The engine is not thread-safe. Callers serialize access.
 */
#ifndef VM_VABAMORF_C_H
#define VM_VABAMORF_C_H

#if defined(__GNUC__)
#  define VM_API __attribute__((visibility("default")))
#else
#  define VM_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vm_speller vm_speller;

/* Opens et.dct. On success returns a speller and sets *err_out to NULL
 * when err_out is non-NULL. On failure returns NULL. When err_out is
 * non-NULL, *err_out is a malloc'd message the caller frees with free,
 * or NULL if the message could not be allocated. err_out may be NULL.
 */
VM_API vm_speller *vm_open(const char *dct_path_utf8, char **err_out);

/* 1 = spelled correctly, 0 = misspelled, <0 = error (NULL handle, bad UTF-8,
 * or an engine exception). Exceptions never leave this library.
 */
VM_API int vm_spell(vm_speller *speller, const char *word_utf8);

/* Writes a malloc'd list of malloc'd UTF-8 suggestions. The caller frees
 * the list with vm_free_suggestions. Returns 0 on success, including an
 * empty suggestion list (*out is NULL and *count is 0). Returns <0 on
 * error and then *out is NULL and *count is 0 when those pointers are
 * non-NULL. bStartSentence is not exposed yet.
 */
VM_API int vm_suggest(vm_speller *speller, const char *word_utf8, char ***out, int *count);

VM_API void vm_free_suggestions(char **list, int count);

/* Safe on NULL. Swallows engine exceptions raised while closing. */
VM_API void vm_close(vm_speller *speller);

/* Static string: "vabamorf <commit>". Never NULL. */
VM_API const char *vm_version(void);

#ifdef __cplusplus
}
#endif

#endif
