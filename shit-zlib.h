#ifndef shit_ZLIB_H
#define shit_ZLIB_H

typedef struct shit_zstream {
	z_stream z;
	unsigned long avail_in;
	unsigned long avail_out;
	unsigned long total_in;
	unsigned long total_out;
	unsigned char *next_in;
	unsigned char *next_out;
} shit_zstream;

void shit_inflate_init(shit_zstream *);
void shit_inflate_init_gzip_only(shit_zstream *);
void shit_inflate_end(shit_zstream *);
int shit_inflate(shit_zstream *, int flush);

void shit_deflate_init(shit_zstream *, int level);
void shit_deflate_init_gzip(shit_zstream *, int level);
void shit_deflate_init_raw(shit_zstream *, int level);
void shit_deflate_end(shit_zstream *);
int shit_deflate_abort(shit_zstream *);
int shit_deflate_end_gently(shit_zstream *);
int shit_deflate(shit_zstream *, int flush);
unsigned long shit_deflate_bound(shit_zstream *, unsigned long);

#endif /* shit_ZLIB_H */
