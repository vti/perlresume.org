#!/usr/bin/env perl
use FindBin '$RealBin';
BEGIN { use local::lib "$RealBin/../../perl5" }
use Dancer;
use Perlresume;
dance;
