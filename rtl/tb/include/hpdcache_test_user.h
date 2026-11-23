/**
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/**
 *  Description: Reference model for the per-word user bits (e.g. CHERI capability tags)
 *
 *  The testbench does not model the full semantics of user bits. Instead, every data word has a
 *  fixed expected user value which is a hash of the word address:
 *
 *    - the driver always sends the expected value on the user field of write requests,
 *    - the memory model always returns the expected value on read responses,
 *    - the scoreboard checks the user field of read responses and of memory writes.
 *
 *  Any mismatch means that user bits were corrupted inside the cache (e.g. an undetected or
 *  miscorrected SRAM error) or written to the wrong location.
 *
 *  Exception: non-capability AMOs (and SC) clear the user bits of the written word. Words
 *  touched by such operations are "tainted" and are no longer checked.
 */
#ifndef __HPDCACHE_TEST_USER_H__
#define __HPDCACHE_TEST_USER_H__

#include "hpdcache_test_defs.h"
#include <cstdint>
#include <unordered_set>

class hpdcache_test_user
{
public:
    static constexpr unsigned WORD_BYTES = ((HPDCACHE_WORD_WIDTH) + 8 - 1) / 8;
    static constexpr unsigned USER_WIDTH = HPDCACHE_USER_WORD_WIDTH;
    static constexpr uint32_t USER_MASK =
        (USER_WIDTH >= 32) ? 0xffffffffu : ((1u << USER_WIDTH) - 1u);

    static constexpr bool enabled() { return HPDCACHE_USER_EN != 0; }

    static inline uint64_t word_index(uint64_t byte_addr) { return byte_addr / WORD_BYTES; }

    //  Expected user value of the data word containing the given byte address
    static inline uint32_t expected(uint64_t byte_addr)
    {
        uint64_t h = word_index(byte_addr) * 0x9E3779B97F4A7C15ULL;
        h ^= h >> 29;
        return static_cast<uint32_t>(h >> 32) & USER_MASK;
    }

    //  Mark the words overlapping [byte_addr, byte_addr + bytes) as no longer checked
    static void taint(uint64_t byte_addr, uint64_t bytes)
    {
        if (bytes == 0) bytes = 1;
        for (uint64_t w = word_index(byte_addr); w <= word_index(byte_addr + bytes - 1); w++) {
            tainted_words().insert(w);
        }
    }

    static bool is_tainted(uint64_t byte_addr)
    {
        return tainted_words().count(word_index(byte_addr)) != 0;
    }

    static uint64_t nb_checks;

private:
    static std::unordered_set<uint64_t>& tainted_words()
    {
        static std::unordered_set<uint64_t> s;
        return s;
    }
};

inline uint64_t hpdcache_test_user::nb_checks = 0;

#endif /* __HPDCACHE_TEST_USER_H__ */
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
