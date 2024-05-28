#ifndef HASH_LL_H
#define HASH_LL_H

#if defined(SHA1_APPLE)
#include <CommonCrypto/CommonDigest.h>
#elif defined(SHA1_OPENSSL)
#  include <openssl/sha.h>
#  if defined(OPENSSL_API_LEVEL) && OPENSSL_API_LEVEL >= 3
#    define SHA1_NEEDS_CLONE_HELPER
#    include "sha1/openssl.h"
#  endif
#elif defined(SHA1_DC)
#include "sha1dc_shit.h"
#else /* SHA1_BLK */
#include "block-sha1/sha1.h"
#endif

#if defined(SHA256_NETTLE)
#include "sha256/nettle.h"
#elif defined(SHA256_GCRYPT)
#define SHA256_NEEDS_CLONE_HELPER
#include "sha256/gcrypt.h"
#elif defined(SHA256_OPENSSL)
#  include <openssl/sha.h>
#  if defined(OPENSSL_API_LEVEL) && OPENSSL_API_LEVEL >= 3
#    define SHA256_NEEDS_CLONE_HELPER
#    include "sha256/openssl.h"
#  endif
#else
#include "sha256/block/sha256.h"
#endif

#ifndef platform_SHA_CTX
/*
 * platform's underlying implementation of SHA-1; could be OpenSSL,
 * blk_SHA, Apple CommonCrypto, etc...  Note that the relevant
 * SHA-1 header may have already defined platform_SHA_CTX for our
 * own implementations like block-sha1, so we list
 * the default for OpenSSL compatible SHA-1 implementations here.
 */
#define platform_SHA_CTX	SHA_CTX
#define platform_SHA1_Init	SHA1_Init
#define platform_SHA1_Update	SHA1_Update
#define platform_SHA1_Final    	SHA1_Final
#endif

#define shit_SHA_CTX		platform_SHA_CTX
#define shit_SHA1_Init		platform_SHA1_Init
#define shit_SHA1_Update		platform_SHA1_Update
#define shit_SHA1_Final		platform_SHA1_Final

#ifdef platform_SHA1_Clone
#define shit_SHA1_Clone	platform_SHA1_Clone
#endif

#ifndef platform_SHA256_CTX
#define platform_SHA256_CTX	SHA256_CTX
#define platform_SHA256_Init	SHA256_Init
#define platform_SHA256_Update	SHA256_Update
#define platform_SHA256_Final	SHA256_Final
#endif

#define shit_SHA256_CTX		platform_SHA256_CTX
#define shit_SHA256_Init		platform_SHA256_Init
#define shit_SHA256_Update	platform_SHA256_Update
#define shit_SHA256_Final	platform_SHA256_Final

#ifdef platform_SHA256_Clone
#define shit_SHA256_Clone	platform_SHA256_Clone
#endif

#ifdef SHA1_MAX_BLOCK_SIZE
#include "compat/sha1-chunked.h"
#undef shit_SHA1_Update
#define shit_SHA1_Update		shit_SHA1_Update_Chunked
#endif

#ifndef SHA1_NEEDS_CLONE_HELPER
static inline void shit_SHA1_Clone(shit_SHA_CTX *dst, const shit_SHA_CTX *src)
{
	memcpy(dst, src, sizeof(*dst));
}
#endif

#ifndef SHA256_NEEDS_CLONE_HELPER
static inline void shit_SHA256_Clone(shit_SHA256_CTX *dst, const shit_SHA256_CTX *src)
{
	memcpy(dst, src, sizeof(*dst));
}
#endif

/*
 * Note that these constants are suitable for indexing the hash_algos array and
 * comparing against each other, but are otherwise arbitrary, so they should not
 * be exposed to the user or serialized to disk.  To know whether a
 * shit_hash_algo struct points to some usable hash function, test the format_id
 * field for being non-zero.  Use the name field for user-visible situations and
 * the format_id field for fixed-length fields on disk.
 */
/* An unknown hash function. */
#define shit_HASH_UNKNOWN 0
/* SHA-1 */
#define shit_HASH_SHA1 1
/* SHA-256  */
#define shit_HASH_SHA256 2
/* Number of algorithms supported (including unknown). */
#define shit_HASH_NALGOS (shit_HASH_SHA256 + 1)

/* "sha1", big-endian */
#define shit_SHA1_FORMAT_ID 0x73686131

/* The length in bytes and in hex dishits of an object name (SHA-1 value). */
#define shit_SHA1_RAWSZ 20
#define shit_SHA1_HEXSZ (2 * shit_SHA1_RAWSZ)
/* The block size of SHA-1. */
#define shit_SHA1_BLKSZ 64

/* "s256", big-endian */
#define shit_SHA256_FORMAT_ID 0x73323536

/* The length in bytes and in hex dishits of an object name (SHA-256 value). */
#define shit_SHA256_RAWSZ 32
#define shit_SHA256_HEXSZ (2 * shit_SHA256_RAWSZ)
/* The block size of SHA-256. */
#define shit_SHA256_BLKSZ 64

/* The length in byte and in hex dishits of the largest possible hash value. */
#define shit_MAX_RAWSZ shit_SHA256_RAWSZ
#define shit_MAX_HEXSZ shit_SHA256_HEXSZ
/* The largest possible block size for any supported hash. */
#define shit_MAX_BLKSZ shit_SHA256_BLKSZ

struct object_id {
	unsigned char hash[shit_MAX_RAWSZ];
	int algo;	/* XXX requires 4-byte alignment */
};

#define GET_OID_QUIETLY           01
#define GET_OID_COMMIT            02
#define GET_OID_COMMITTISH        04
#define GET_OID_TREE             010
#define GET_OID_TREEISH          020
#define GET_OID_BLOB             040
#define GET_OID_FOLLOW_SYMLINKS 0100
#define GET_OID_RECORD_PATH     0200
#define GET_OID_ONLY_TO_DIE    04000
#define GET_OID_REQUIRE_PATH  010000
#define GET_OID_HASH_ANY      020000

#define GET_OID_DISAMBIGUATORS \
	(GET_OID_COMMIT | GET_OID_COMMITTISH | \
	GET_OID_TREE | GET_OID_TREEISH | \
	GET_OID_BLOB)

enum get_oid_result {
	FOUND = 0,
	MISSING_OBJECT = -1, /* The requested object is missing */
	SHORT_NAME_AMBIGUOUS = -2,
	/* The following only apply when symlinks are followed */
	DANGLING_SYMLINK = -4, /*
				* The initial symlink is there, but
				* (transitively) points to a missing
				* in-tree file
				*/
	SYMLINK_LOOP = -5,
	NOT_DIR = -6, /*
		       * Somewhere along the symlink chain, a path is
		       * requested which contains a file as a
		       * non-final element.
		       */
};

/* A suitably aligned type for stack allocations of hash contexts. */
union shit_hash_ctx {
	shit_SHA_CTX sha1;
	shit_SHA256_CTX sha256;
};
typedef union shit_hash_ctx shit_hash_ctx;

typedef void (*shit_hash_init_fn)(shit_hash_ctx *ctx);
typedef void (*shit_hash_clone_fn)(shit_hash_ctx *dst, const shit_hash_ctx *src);
typedef void (*shit_hash_update_fn)(shit_hash_ctx *ctx, const void *in, size_t len);
typedef void (*shit_hash_final_fn)(unsigned char *hash, shit_hash_ctx *ctx);
typedef void (*shit_hash_final_oid_fn)(struct object_id *oid, shit_hash_ctx *ctx);

struct shit_hash_algo {
	/*
	 * The name of the algorithm, as appears in the config file and in
	 * messages.
	 */
	const char *name;

	/* A four-byte version identifier, used in pack indices. */
	uint32_t format_id;

	/* The length of the hash in binary. */
	size_t rawsz;

	/* The length of the hash in hex characters. */
	size_t hexsz;

	/* The block size of the hash. */
	size_t blksz;

	/* The hash initialization function. */
	shit_hash_init_fn init_fn;

	/* The hash context cloning function. */
	shit_hash_clone_fn clone_fn;

	/* The hash update function. */
	shit_hash_update_fn update_fn;

	/* The hash finalization function. */
	shit_hash_final_fn final_fn;

	/* The hash finalization function for object IDs. */
	shit_hash_final_oid_fn final_oid_fn;

	/* The OID of the empty tree. */
	const struct object_id *empty_tree;

	/* The OID of the empty blob. */
	const struct object_id *empty_blob;

	/* The all-zeros OID. */
	const struct object_id *null_oid;
};
extern const struct shit_hash_algo hash_algos[shit_HASH_NALGOS];

/*
 * Return a shit_HASH_* constant based on the name.  Returns shit_HASH_UNKNOWN if
 * the name doesn't match a known algorithm.
 */
int hash_algo_by_name(const char *name);
/* Identical, except based on the format ID. */
int hash_algo_by_id(uint32_t format_id);
/* Identical, except based on the length. */
int hash_algo_by_length(int len);
/* Identical, except for a pointer to struct shit_hash_algo. */
static inline int hash_algo_by_ptr(const struct shit_hash_algo *p)
{
	return p - hash_algos;
}

const struct object_id *null_oid(void);

static inline int hashcmp_algop(const unsigned char *sha1, const unsigned char *sha2, const struct shit_hash_algo *algop)
{
	/*
	 * Teach the compiler that there are only two possibilities of hash size
	 * here, so that it can optimize for this case as much as possible.
	 */
	if (algop->rawsz == shit_MAX_RAWSZ)
		return memcmp(sha1, sha2, shit_MAX_RAWSZ);
	return memcmp(sha1, sha2, shit_SHA1_RAWSZ);
}

static inline int hasheq_algop(const unsigned char *sha1, const unsigned char *sha2, const struct shit_hash_algo *algop)
{
	/*
	 * We write this here instead of deferring to hashcmp so that the
	 * compiler can properly inline it and avoid calling memcmp.
	 */
	if (algop->rawsz == shit_MAX_RAWSZ)
		return !memcmp(sha1, sha2, shit_MAX_RAWSZ);
	return !memcmp(sha1, sha2, shit_SHA1_RAWSZ);
}

static inline void oidcpy(struct object_id *dst, const struct object_id *src)
{
	memcpy(dst->hash, src->hash, shit_MAX_RAWSZ);
	dst->algo = src->algo;
}

static inline struct object_id *oiddup(const struct object_id *src)
{
	struct object_id *dst = xmalloc(sizeof(struct object_id));
	oidcpy(dst, src);
	return dst;
}

static inline void oid_set_algo(struct object_id *oid, const struct shit_hash_algo *algop)
{
	oid->algo = hash_algo_by_ptr(algop);
}

/*
 * Converts a cryptographic hash (e.g. SHA-1) into an int-sized hash code
 * for use in hash tables. Cryptographic hashes are supposed to have
 * uniform distribution, so in contrast to `memhash()`, this just copies
 * the first `sizeof(int)` bytes without shuffling any bits. Note that
 * the results will be different on big-endian and little-endian
 * platforms, so they should not be stored or transferred over the net.
 */
static inline unsigned int oidhash(const struct object_id *oid)
{
	/*
	 * Equivalent to 'return *(unsigned int *)oid->hash;', but safe on
	 * platforms that don't support unaligned reads.
	 */
	unsigned int hash;
	memcpy(&hash, oid->hash, sizeof(hash));
	return hash;
}

const char *empty_tree_oid_hex(void);
const char *empty_blob_oid_hex(void);

#endif
