#!/bin/bash

set -e
dub build
export TIL_PATH=$PWD
dub run til:run -b release -- test.til
