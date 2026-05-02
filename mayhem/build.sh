#!/bin/bash -eu
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

# Fix DWARF 5 incompatibility with clang 22 (base-builder default)
export CFLAGS="$CFLAGS -gdwarf-4"
export CXXFLAGS="$CXXFLAGS -gdwarf-4"

# Build Liblouis
cd $SRC/liblouis
touch configure.ac Makefile.am aclocal.m4 configure Makefile.in
./autogen.sh
./configure --disable-maintainer-mode
make -j$(nproc) V=1

cd tests/fuzzing
cp ../tables/empty.ctb $OUT/
find ../.. -name "*.o" -exec ar rcs fuzz_lib.a {} \;

$CXX $CXXFLAGS -c table_fuzzer.cc -I/src/liblouis -o table_fuzzer.o
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE table_fuzzer.o -o $OUT/table_fuzzer fuzz_lib.a

# Compile with -Dmain=nomain to suppress the duplicate main() conflict
# with LIB_FUZZING_ENGINE which provides its own main
$CC $CFLAGS -Dmain=nomain -c fuzz_translate_generic.c -o fuzz_translate_generic.o \
    -I$SRC/liblouis -I$SRC/liblouis/liblouis
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE fuzz_translate_generic.o \
    -o $OUT/fuzz_translate_generic fuzz_lib.a

$CC $CFLAGS -Dmain=nomain -c fuzz_backtranslate.c -o fuzz_backtranslate.o \
    -I$SRC/liblouis -I$SRC/liblouis/liblouis
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE fuzz_backtranslate.o \
    -o $OUT/fuzz_backtranslate fuzz_lib.a

# Build corpus
zip $OUT/table_fuzzer_seed_corpus.zip $SRC/liblouis/tables/latinLetterDef6Dots.uti

# Copy out dictionary
cp $SRC/liblouis/tests/fuzzing/fuzz_translate_generic.dict $OUT/fuzz_translate_generic.dict
cp $SRC/liblouis/tests/fuzzing/fuzz_translate_generic.dict $OUT/fuzz_backtranslate.dict
