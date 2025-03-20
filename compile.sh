#!/bin/bash

nasm $1 -f elf64 -o temp.o -gdwarf
gcc temp.o -no-pie -lSDL3 -lm -o rayCast_inator.out
rm temp.o
