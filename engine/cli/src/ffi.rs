// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (c) 2026 Madis Väin

//! Calls into `libvabamorf.dylib`. The engine is not thread-safe, and
//! `Speller` must stay on the thread that opened it.

use std::ffi::{CStr, CString, c_char, c_int, c_void};

enum SpellerHandle {}

unsafe extern "C" {
    fn vm_open(dct_path_utf8: *const c_char, err_out: *mut *mut c_char) -> *mut SpellerHandle;
    fn vm_spell(speller: *mut SpellerHandle, word_utf8: *const c_char) -> c_int;
    fn vm_suggest(
        speller: *mut SpellerHandle,
        word_utf8: *const c_char,
        out: *mut *mut *mut c_char,
        count: *mut c_int,
    ) -> c_int;
    fn vm_free_suggestions(list: *mut *mut c_char, count: c_int);
    fn vm_close(speller: *mut SpellerHandle);
    fn vm_version() -> *const c_char;
    fn free(ptr: *mut c_void);
}

pub struct Speller {
    // Raw pointer: the engine is not thread-safe, so this type stays !Send.
    handle: *mut SpellerHandle,
}

pub enum CheckFailure {
    Spell,
    Suggest,
}

impl Speller {
    pub fn open(path: &CStr) -> Result<Self, String> {
        let mut error = std::ptr::null_mut();
        let handle = unsafe { vm_open(path.as_ptr(), &mut error) };
        if handle.is_null() {
            return Err(take_error(error));
        }
        if !error.is_null() {
            unsafe { free(error.cast()) };
        }
        Ok(Self { handle })
    }

    pub fn spell(&self, word: &CStr) -> Result<bool, CheckFailure> {
        match unsafe { vm_spell(self.handle, word.as_ptr()) } {
            1 => Ok(true),
            0 => Ok(false),
            _ => Err(CheckFailure::Spell),
        }
    }

    pub fn suggest(&self, word: &CStr) -> Result<Vec<String>, CheckFailure> {
        let mut out = std::ptr::null_mut();
        let mut count = 0;
        let status = unsafe { vm_suggest(self.handle, word.as_ptr(), &mut out, &mut count) };
        if status < 0 {
            return Err(CheckFailure::Suggest);
        }

        let suggestions = if out.is_null() || count <= 0 {
            Vec::new()
        } else {
            let pointers = unsafe { std::slice::from_raw_parts(out, count as usize) };
            pointers
                .iter()
                .map(|pointer| {
                    if pointer.is_null() {
                        String::new()
                    } else {
                        unsafe { CStr::from_ptr(*pointer) }
                            .to_string_lossy()
                            .into_owned()
                    }
                })
                .collect()
        };
        unsafe { vm_free_suggestions(out, count) };
        Ok(suggestions)
    }
}

impl Drop for Speller {
    fn drop(&mut self) {
        unsafe { vm_close(self.handle) };
    }
}

pub fn version() -> String {
    unsafe { CStr::from_ptr(vm_version()) }
        .to_string_lossy()
        .into_owned()
}

pub fn c_string(bytes: &[u8]) -> Result<CString, ()> {
    CString::new(bytes).map_err(|_| ())
}

fn take_error(error: *mut c_char) -> String {
    if error.is_null() {
        return "cannot open dictionary".to_string();
    }
    let message = unsafe { CStr::from_ptr(error) }
        .to_string_lossy()
        .into_owned();
    unsafe { free(error.cast()) };
    message
}
