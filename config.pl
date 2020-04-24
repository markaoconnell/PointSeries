#!/usr/bin/perl

use strict;


my($DEBUG_LEVEL_1) = 0x1;
my($DEBUG_LEVEL_2) = 0x2;
my($DEBUG_LEVEL_3) = 0x4;
my($DEBUG) = 0;


my($CONFIG_FILE_NAME) = "config_options.csv";
sub read_configuration {
  my(%config);
  open(CONFIG_FILE, "<$CONFIG_FILE_NAME");

  while (<CONFIG_FILE>) {
    chomp;
    s/#.*$//;
    s/^\s*//;  # Remove leading whitespace
    next if (/^$/);  # skip empty lines (or lines which are just a comment)

    my($key,$value) = split(";");
    $key =~ s/^\s*//;  #Remove whitespace
    $key =~ s/\s*$//;
    $value =~ s/^\s*//;
    $value =~ s/\s*$//;

    $config{$key} = $value;
#   print "Adding configuration of $key -> $value.\n";
  }

  close(CONFIG_FILE);

  return (%config);
}


1;
