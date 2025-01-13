OS=$(shell uname)

ifeq ($(OS), Darwin)
all: darwin
else
all: unix
endif

wasm:
	mkdir -p ../lib
	$(CC) -c -Os --target=wasm32 --sysroot=$(shell odin root)/vendor/libc stb_truetype.c     -o ../lib/stb_truetype_wasm.o

unix:
	mkdir -p ../lib
	$(CC) -c -O2 -Os -fPIC stb_truetype.c
	$(AR) rcs ../lib/stb_truetype.a stb_truetype.o

	#$(CC) -fPIC -shared -Wl,-soname=stb_truetype.so -o ../lib/stb_truetype.so stb_image_truetype.o
	rm *.o

darwin:
	mkdir -p ../lib
	lipo -create stb_truetype-x86_64.o stb_truetype-arm64.o -output ../lib/darwin/stb_truetype.a
	$(CC) -arch x86_64 -c -O2 -Os -fPIC stb_truetype.c -o stb_truetype-x86_64.o -mmacosx-version-min=10.12
	$(CC) -arch arm64  -c -O2 -Os -fPIC stb_truetype.c -o stb_truetype-arm64.o -mmacosx-version-min=10.12

	rm *.o
