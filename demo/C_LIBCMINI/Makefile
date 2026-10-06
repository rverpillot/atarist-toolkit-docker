CC= m68k-atari-mintelf-gcc
LIBCMINI=/usr/local/m68k-atari-libcmini
CFLAGS=-std=gnu99 -I$(LIBCMINI)/include -nostdlib $(LIBCMINI)/lib/crt0.o
LINKFLAGS=-s -L$(LIBCMINI)/lib -lcmini -lgcc

all: clean main

main: 
	mkdir -p out
	$(CC) $(CFLAGS) src/main.c -o out/main.tos $(LINKFLAGS)

clean:
	rm -rf out/*.tos