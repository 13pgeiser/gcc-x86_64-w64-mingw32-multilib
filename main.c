#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(int argc, char* argv[]) {
	z_stream defstream;
	memset(&defstream, 0, sizeof(defstream));
	int ret = deflateInit(&defstream, Z_BEST_COMPRESSION);
	fprintf(stderr, "Hello! ret=%d\n", ret);
	return 0;
}

