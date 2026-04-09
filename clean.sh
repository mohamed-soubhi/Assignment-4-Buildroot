#!/bin/bash
# Script to clean the buildroot build directory
# Runs make distclean from the buildroot directory

cd `dirname $0`
make -C buildroot distclean
