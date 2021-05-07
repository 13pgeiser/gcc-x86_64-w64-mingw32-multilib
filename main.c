#include <stdio.h>
#include <zlib.h>

int main(int argc, char* argv[]) {
    z_stream defstream;
    deflateInit(&defstream, Z_BEST_COMPRESSION);
	puts("Hello!");
	return 0;
}

