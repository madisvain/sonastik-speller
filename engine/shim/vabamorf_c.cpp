/* SPDX-License-Identifier: LGPL-2.1-or-later
 * Copyright (c) 2026 Madis Väin
 *
 * Every C++ exception is caught here. Nothing unwinds across the C ABI.
 */
#include "vabamorf_c.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <new>

#include "proof/proof.h"

#ifndef VM_VABAMORF_COMMIT
#define VM_VABAMORF_COMMIT unknown
#endif

#define VM_STRINGIFY(x) #x
#define VM_TOSTRING(x) VM_STRINGIFY(x)

struct vm_speller {
	CLinguistic ling;
};

static char *dup_cstr(const char *text) {
	if (!text) {
		text = "";
	}
	size_t length = std::strlen(text);
	char *copy = static_cast<char *>(std::malloc(length + 1));
	if (!copy) {
		return 0;
	}
	std::memcpy(copy, text, length + 1);
	return copy;
}

static char *current_exception_message() {
	try {
		throw;
	} catch (const CLinguisticException &ex) {
		CFSString text = ex.GetText();
		const char *narrow = text;
		if (!narrow || !narrow[0]) {
			narrow = "dictionary error";
		}
		return dup_cstr(narrow);
	} catch (const VEAD &ex) {
		char buffer[256];
		std::snprintf(buffer, sizeof(buffer), "vabamorf error %d at %s:%d",
			ex.errNo, ex.file ? ex.file : "?", ex.line);
		return dup_cstr(buffer);
	} catch (const CFSException &) {
		return dup_cstr("vabamorf error");
	} catch (const std::exception &ex) {
		return dup_cstr(ex.what());
	} catch (...) {
		return dup_cstr("unknown vabamorf error");
	}
}

static void assign_error(char **err_out, char *message) {
	if (err_out) {
		*err_out = message;
	} else {
		std::free(message);
	}
}

static int widen(const char *utf8, CFSWString *wide) {
	if (!utf8) {
		return -1;
	}
	bool failed = false;
	*wide = FSStrAtoW(CFSAString(utf8), FSCP_UTF8, &failed);
	if (failed) {
		return -1;
	}
	return 0;
}

vm_speller *vm_open(const char *dct_path_utf8, char **err_out) {
	if (err_out) {
		*err_out = 0;
	}
	if (!dct_path_utf8 || !dct_path_utf8[0]) {
		assign_error(err_out, dup_cstr("empty dictionary path"));
		return 0;
	}

	vm_speller *speller = 0;
	try {
		speller = new vm_speller();
		speller->ling.Open(CFSAString(dct_path_utf8));
		return speller;
	} catch (...) {
		delete speller;
		assign_error(err_out, current_exception_message());
		return 0;
	}
}

int vm_spell(vm_speller *speller, const char *word_utf8) {
	if (!speller) {
		return -1;
	}
	try {
		CFSWString wide;
		if (widen(word_utf8, &wide) != 0) {
			return -1;
		}
		return speller->ling.SpellWord(wide) == SPL_NOERROR ? 1 : 0;
	} catch (...) {
		return -1;
	}
}

int vm_suggest(vm_speller *speller, const char *word_utf8, char ***out, int *count) {
	if (out) {
		*out = 0;
	}
	if (count) {
		*count = 0;
	}
	if (!speller || !out || !count) {
		return -1;
	}

	try {
		CFSWString wide;
		if (widen(word_utf8, &wide) != 0) {
			return -1;
		}
		CFSWStringArray suggestions = speller->ling.Suggest(wide, false);
		INTPTR size = suggestions.GetSize();
		if (size < 0 || size > 100000) {
			return -1;
		}
		if (size == 0) {
			return 0;
		}

		char **list = static_cast<char **>(std::calloc(static_cast<size_t>(size), sizeof(char *)));
		if (!list) {
			return -1;
		}
		for (INTPTR index = 0; index < size; ++index) {
			bool failed = false;
			CFSAString utf8 = FSStrWtoA(suggestions[index], FSCP_UTF8, &failed);
			(void)failed;
			const char *text = utf8;
			list[index] = dup_cstr(text);
			if (!list[index]) {
				vm_free_suggestions(list, static_cast<int>(index));
				return -1;
			}
		}
		*out = list;
		*count = static_cast<int>(size);
		return 0;
	} catch (...) {
		return -1;
	}
}

void vm_free_suggestions(char **list, int count) {
	if (!list) {
		return;
	}
	if (count < 0) {
		count = 0;
	}
	for (int index = 0; index < count; ++index) {
		std::free(list[index]);
	}
	std::free(list);
}

void vm_close(vm_speller *speller) {
	if (!speller) {
		return;
	}
	try {
		delete speller;
	} catch (...) {
	}
}

const char *vm_version(void) {
	return "vabamorf " VM_TOSTRING(VM_VABAMORF_COMMIT);
}
