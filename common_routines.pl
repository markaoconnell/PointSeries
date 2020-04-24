#!/usr/bin/perl

use strict;

require "moc_levenshtein.pl";

my($DEBUG_LEVEL_1) = 0x1;
my($DEBUG_LEVEL_2) = 0x2;
my($DEBUG_LEVEL_3) = 0x4;
my($DEBUG) = 0;

my($YEAR_OF_RESULTS) = 2019;
my($MAX_NAME_DISTANCE) = 2;
my($MAX_CHECK_DISTANCE) = 6;

my($NO_RETURN_FROM_MATCH) = "NONE";

my(%nicknames_lookup);
my(%full_name_lookup);


#gender;start_age;end_age;course;
#F;0;12;White
sub read_year_to_course {
  my(%year_to_course);
  $year_to_course{"M"} = [];
  $year_to_course{"F"} = [];
  $year_to_course{"O"} = [];

  open(YEAR_TO_COURSE, "<year_to_course.csv");

  while (<YEAR_TO_COURSE>) {
    chomp;
    next if (/gender;start/);  # skip the header
    my($gender, $start_age, $end_age, $course) = split(";");

    print "Filling $start_age to $end_age for $gender as $course.\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
    my($index);
    foreach $index ($start_age .. $end_age) {
      $year_to_course{$gender}->[$index] = $course;
    }
  }
  close YEAR_TO_COURSE;
  return \%year_to_course;
}

sub set_year_of_results {
  $YEAR_OF_RESULTS = $_[0];
}

sub year_to_course {
  my($year_to_course_ref, $birth_year, $gender) = @_;
  print "$gender, $birth_year, age is " . ($YEAR_OF_RESULTS - $birth_year) . ", course is " . $year_to_course_ref->{$gender}->[2019 - $birth_year] . "\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
  my($age) = $YEAR_OF_RESULTS - $birth_year;

  # check if there was no age specified
  if ($age == $YEAR_OF_RESULTS) {
    $age = 21;  # make it the most competitive
  }
  
  return($year_to_course_ref->{$gender}->[$age]);
}


#171;Amram;Peter;M;1940
#1412;Anderson;Barbara;F;1970
# Read in the members together with their id
sub read_member_list {
  my($year_to_course_ref) = @_;
  my(%members_by_id);
  my(%target_course_by_id);
  my(%genders_by_id);
  my(%last_name_to_ids);

  open(MEMBER_FILE, "<./members.csv");
  while (<MEMBER_FILE>) {
    chomp;
    s/\r//;  # just in case
    
    my($id, $last, $first, $gender, $year, @aliases) = split(";");
    if (!exists($members_by_id{$id})) {
      $members_by_id{$id} = [];
    }

    if (($gender ne "M") && ($gender ne "F") && ($gender ne "O")) {
      print "Temporary ERROR: Only M, F, or O currently supported: $_\n";
    }
  
    $members_by_id{$id} = $last . ";" . $first;
    $genders_by_id{$id} = $gender;

    $target_course_by_id{$id} = year_to_course($year_to_course_ref, $year, $gender);
    if ($target_course_by_id{$id} eq "") {
      print "ERROR: No course found for $first $last $gender $year.\n";
    }
  }
  close MEMBER_FILE;

  # Identify duplicate members to remove
  my($member_id);
  my(%names_to_ids);  # for detecting duplicate members
  my(@ids_to_remove);
  foreach $member_id (keys(%members_by_id)) {
    my($name_key) = $members_by_id{$member_id};
    if (exists($names_to_ids{$name_key})) {
      print "Duplicate detected - $member_id / $names_to_ids{$name_key} are for $name_key.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);

      # Duplicate name detected!  Choose the lower numbered member id
      if ($member_id >= $names_to_ids{$name_key}) {
        push(@ids_to_remove, $member_id);
      }
      else {
        push(@ids_to_remove, $names_to_ids{$name_key});
        $names_to_ids{$name_key} = $member_id;
      }
    }
    else {
      $names_to_ids{$name_key} = $member_id;
    }
  }

  # Actually remove the duplicate ids
  foreach $member_id (@ids_to_remove) {
    print "Remving duplicate id - $member_id for $members_by_id{$member_id}.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
    delete $members_by_id{$member_id};
    delete $target_course_by_id{$member_id};
    delete $genders_by_id{$member_id};
  }

  # Create the optimized lookup of last name to id
  foreach $member_id (keys(%members_by_id)) {
    my($last, $first) = split(";", $members_by_id{$member_id});

    print "Member ($member_id), name $first - $last, runs on $target_course_by_id{$member_id} as $genders_by_id{$member_id}.\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);

    if (!exists($last_name_to_ids{$last})) {
      $last_name_to_ids{$last} = [];
    }
    push (@{$last_name_to_ids{$last}}, $member_id);
    $full_name_lookup{$last . ";" . $first} = $member_id;
  }

  # Read the nicknames tables
  open(NICKNAME_FILE, "<./nicknames.csv");
  while (<NICKNAME_FILE>) {
    chomp;
    my(@equivalent_names) = split(";");
    my($name_in_list);
    foreach $name_in_list (@equivalent_names) {
      $nicknames_lookup{$name_in_list} = \@equivalent_names;
    }
  }
  close(NICKNAME_FILE);

  return (\%members_by_id, \%target_course_by_id, \%genders_by_id, \%last_name_to_ids);
}


sub find_best_match_by_distance {
  my($name_to_check, @names_list) = @_;

  my(@match_distances);
  my($entry_key);
  my($dist);
  foreach $entry_key (@names_list) {
     $dist = distance($name_to_check, $entry_key);
     if ($dist < $MAX_CHECK_DISTANCE) {
       if (!exists($match_distances[$dist])) {
         $match_distances[$dist] = [];
       }
       push(@{$match_distances[$dist]}, $entry_key);
     }
  }

  my($distance_measure);
  foreach $distance_measure (0..$MAX_NAME_DISTANCE) {
    if (exists($match_distances[$distance_measure]) && ($#{@match_distances[$distance_measure]} >= 0)) {  # Are there entries?
      print "Matches of length $distance_measure: " . join("--", @{$match_distances[$distance_measure]}) . "\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
      return(@{$match_distances[$distance_measure]});
    }
    else {
      print "No matches for $name_to_check of length $distance_measure\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
    }
  }

  return ();
}

sub find_best_name_match {
  my($members_by_id, $last_name_to_ids, $last_name, $first_name) = @_;

  # Find the member id of the competitor, if the person appears to be a member
  my($result_name_key) = $last_name . ";" . $first_name;

  # is there an exact match?
  if (exists($full_name_lookup{$result_name_key})) {
    print "Found exact match for $result_name_key : $full_name_lookup{$result_name_key}.\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
    return($full_name_lookup{$result_name_key});
  }

  # Look for a match on the last name
  my(@best_last_name_matches) = ();
  if (exists($last_name_to_ids->{$last_name})) {
    $best_last_name_matches[0] = $last_name;
  }
  else {
    @best_last_name_matches = find_best_match_by_distance($last_name, keys(%{$last_name_to_ids}));
  }

  print "Best last name matches for $last_name are " . join(";", @best_last_name_matches) . "\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);

  if ($#best_last_name_matches == -1) {
    return $NO_RETURN_FROM_MATCH;  # no matches
  }
  elsif ($#best_last_name_matches == 0) {
    # There's an exact match with this last name - just return that
    if (exists($full_name_lookup{$best_last_name_matches[0] . ";" . $first_name})) {
      print "Found exact match for modified last name ($best_last_name_matches[0]) $result_name_key : " .
                         $full_name_lookup{$best_last_name_matches[0] . ";" . $first_name} . ".\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
      return($full_name_lookup{$best_last_name_matches[0] . ";" . $first_name});
    }

    # There's a single member with this name - see if there's a close first name match
    if ($#{$last_name_to_ids->{$best_last_name_matches[0]}} == 0) {
      my($member_last_name, $member_first_name) = split(";", $members_by_id->{$last_name_to_ids->{$best_last_name_matches[0]}->[0]});
      print "Checking single member with last name $last_name : $member_first_name and $first_name\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
      if (distance($first_name, $member_first_name) < $MAX_NAME_DISTANCE) {
        print "Single member with last name $last_name : $member_first_name sufficiently matches $first_name\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);

        if (distance($last_name . ";" . $first_name, $member_last_name . ";" . $member_first_name) < $MAX_NAME_DISTANCE) {
          return($last_name_to_ids->{$best_last_name_matches[0]}->[0]);
        }
        else {
          print "Insufficient overall match: $last_name;$first_name vs $member_last_name;$member_first_name\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
        }
      }
    }
  }

  # Do the full blown nickname check
  # For each possible member, get the list of nicknames associated
  my($possible_last_name, $possible_member_id);
  my(%possible_nicknames);
  foreach $possible_last_name (@best_last_name_matches) {
    foreach $possible_member_id (@{$last_name_to_ids->{$possible_last_name}}) {
      my($member_last_name, $member_first_name) = split(";", $members_by_id->{$possible_member_id});
      my(@nicknames_to_check);
      if (exists($nicknames_lookup{$member_first_name})) {
        @nicknames_to_check = @{$nicknames_lookup{$member_first_name}};
      }
      else {
        @nicknames_to_check[0] = $member_first_name;
      }

      my($possible_nickname);
      foreach $possible_nickname (@nicknames_to_check) {
        if (!exists($possible_nicknames{$possible_last_name . ";" . $possible_nickname})) {
          $possible_nicknames{$possible_last_name . ";" . $possible_nickname} = [];
        }

        push(@{$possible_nicknames{$possible_last_name . ";" . $possible_nickname}}, $possible_member_id);
      }
    }
  }

  # find the closest match amongst all the possible nicknames etc
  print "Checking for a match $last_name;$first_name vs " . join(",", keys(%possible_nicknames)) . "\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
  my(@best_name_matches);
  @best_name_matches = find_best_match_by_distance($last_name . ";" . $first_name, keys(%possible_nicknames));

  if ($#best_name_matches == -1) {
    # No matches - not a member
    # Last ditch attempt - if the first name is a single character and it matches only one possible
    # member, assume that is it
    my($candidate_return_id) = $NO_RETURN_FROM_MATCH;
    my($initial_of_first_name) = $first_name;
    $initial_of_first_name =~ s/\.$//;   # Remove a trailing .
    if (length($initial_of_first_name) == 1) {
      print "Checking initials $last_name;$first_name ($initial_of_first_name)\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
      foreach $possible_last_name (@best_last_name_matches) {
        foreach $possible_member_id (@{$last_name_to_ids->{$possible_last_name}}) {
          my($member_last_name, $member_first_name) = split(";", $members_by_id->{$possible_member_id});
          if (substr($member_first_name, 0, 1) eq $initial_of_first_name) {
            if ($candidate_return_id eq $NO_RETURN_FROM_MATCH) {
              print "Checking initials $last_name;$first_name ($initial_of_first_name) matches $members_by_id->{$possible_member_id}\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);
              $candidate_return_id = $possible_member_id;
            }
            else {
              # There is a collision, two members with the same last name share a first initial
              # Nothing to do but give up at this point
              return $NO_RETURN_FROM_MATCH;
            }
          }
        }
      }
    }
    return ($candidate_return_id);
  }
  elsif ($#best_name_matches == 0) {
    # One name match - is this one member id?
    if ($#{$possible_nicknames{$best_name_matches[0]}} == 0) {
      # yes, only one member has this - return this id
      return $possible_nicknames{$best_name_matches[0]}->[0];
    }
  }

  # Either there are multiple matches, or there are are multiple members with this nickname
  # If they are all the same member id, we're good, otherwise we're ambiguous
  # and we return NONE.
  print "Multiple matches for $last_name;$first_name : " . join(",", @best_name_matches) . "\n" if (($DEBUG & $DEBUG_LEVEL_1) != 0);

  # Initialize this to the first member id in the list
  my($member_id_to_return) = $possible_nicknames{$best_name_matches[0]}->[0];
  my($possible_name);
  foreach $possible_name (@best_name_matches) {
    foreach $possible_member_id (@{$possible_nicknames{$possible_name}}) {
      if ($member_id_to_return != $possible_member_id) {
        # Houston, we have a problem.  Return NONE to indicate the ambiguity
        print "Ambiguous match for $last_name;$first_name : $members_by_id->{$member_id_to_return} ($member_id_to_return) and $members_by_id->{$possible_member_id} ($possible_member_id).\n";
        return ($NO_RETURN_FROM_MATCH);
      }
    }
  }

  return($member_id_to_return);
}

1;
