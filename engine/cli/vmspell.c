/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 *
 * Talks to Vabamorf only through vabamorf_c.h.
 */
#include "vabamorf_c.h"

#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static int file_exists(const char *path) {
	struct stat info;
	return path && stat(path, &info) == 0 && S_ISREG(info.st_mode);
}

static char *dictionary_beside_executable(void) {
	char stack[4096];
	uint32_t size = (uint32_t)sizeof(stack);
	char *heap = 0;
	char *path = stack;
	if (_NSGetExecutablePath(stack, &size) != 0) {
		heap = (char *)malloc(size);
		if (!heap) {
			return 0;
		}
		if (_NSGetExecutablePath(heap, &size) != 0) {
			free(heap);
			return 0;
		}
		path = heap;
	}

	char *real = realpath(path, 0);
	free(heap);
	if (!real) {
		return 0;
	}
	char *slash = strrchr(real, '/');
	if (!slash) {
		free(real);
		return 0;
	}
	size_t directory = (size_t)(slash - real);
	const char *suffix = "/et.dct";
	char *dictionary = (char *)malloc(directory + strlen(suffix) + 1);
	if (!dictionary) {
		free(real);
		return 0;
	}
	memcpy(dictionary, real, directory);
	memcpy(dictionary + directory, suffix, strlen(suffix) + 1);
	free(real);
	return dictionary;
}

static void usage(FILE *stream) {
	fputs("usage: vmspell [--dict PATH] WORD...\n"
		"       vmspell --version\n"
		"       vmspell --help\n", stream);
}

static int check_word(vm_speller *speller, const char *word) {
	int spelled = vm_spell(speller, word);
	if (spelled < 0) {
		fprintf(stderr, "vmspell: cannot check '%s'\n", word);
		return 1;
	}
	if (spelled == 1) {
		printf("%s -- OK\n", word);
		return 0;
	}

	char **suggestions = 0;
	int count = 0;
	if (vm_suggest(speller, word, &suggestions, &count) != 0) {
		fprintf(stderr, "vmspell: cannot suggest for '%s'\n", word);
		return 1;
	}
	printf("%s -- Vigane, soovitan:", word);
	for (int index = 0; index < count; ++index) {
		printf(" %s", suggestions[index] ? suggestions[index] : "");
	}
	printf("\n");
	vm_free_suggestions(suggestions, count);
	return 0;
}

int main(int argc, char **argv) {
	const char *dict_flag = 0;
	const char **words = (const char **)calloc((size_t)argc, sizeof(char *));
	if (!words) {
		fprintf(stderr, "vmspell: out of memory\n");
		return 1;
	}
	int word_count = 0;

	for (int index = 1; index < argc; ++index) {
		const char *arg = argv[index];
		if (strcmp(arg, "--help") == 0) {
			usage(stdout);
			free(words);
			return 0;
		}
		if (strcmp(arg, "--version") == 0) {
			printf("%s\n", vm_version());
			free(words);
			return 0;
		}
		if (strcmp(arg, "--dict") == 0) {
			if (index + 1 >= argc) {
				usage(stderr);
				free(words);
				return 2;
			}
			dict_flag = argv[++index];
			continue;
		}
		if (strncmp(arg, "--", 2) == 0) {
			usage(stderr);
			free(words);
			return 2;
		}
		words[word_count++] = arg;
	}

	if (word_count == 0) {
		usage(stderr);
		free(words);
		return 2;
	}

	const char *dictionary = dict_flag;
	char *owned = 0;
	if (!dictionary) {
		const char *from_env = getenv("VABAMORF_DICT");
		if (from_env && from_env[0]) {
			dictionary = from_env;
		} else if (file_exists("et.dct")) {
			dictionary = "et.dct";
		} else {
			owned = dictionary_beside_executable();
			dictionary = owned;
		}
	}
	if (!dictionary || !dictionary[0]) {
		fprintf(stderr, "vmspell: dictionary not found\n");
		free(owned);
		free(words);
		return 1;
	}

	char *error = 0;
	vm_speller *speller = vm_open(dictionary, &error);
	if (!speller) {
		fprintf(stderr, "vmspell: %s\n", error ? error : "cannot open dictionary");
		free(error);
		free(owned);
		free(words);
		return 1;
	}
	free(error);

	int status = 0;
	for (int index = 0; index < word_count; ++index) {
		if (check_word(speller, words[index]) != 0) {
			status = 1;
			break;
		}
	}

	vm_close(speller);
	free(owned);
	free(words);
	return status;
}
