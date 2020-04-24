#!/usr/bin/perl

require "common_routines.pl";

use strict;

my($FULL_DEBUG) = 0x1;
my($DEBUG_LEVEL_1) = 0x2;
my($DEBUG_LEVEL_2) = 0x4;
my($DEBUG_LEVEL_3) = 0x8;
my($DEBUG) = 0;

my($NAME_KEY) = "name_key";
my($COMPETITION_COURSE_KEY) = "competition_course_key";
my($TOTAL_POINTS_KEY) = "total_points_key";
my($EVENTS_KEY) = "events_key";
my($NEW_EVENT_KEY) = "new_event_key";
my($NEW_EVENT_POINTS) = "new_event_points";
my($NEW_EVENT_COURSE) = "new_event_course";
my($NEW_EVENT_NAME_KEY) = "new_event_name_key";

my($MAX_NAME_DISTANCE) = 3;

use POSIX qw(strftime);

my($year_to_course_ref) = read_year_to_course();
my($members_by_id_ref, $target_course_by_id_ref, $genders_by_id_ref, $last_name_to_ids_ref) = read_member_list($year_to_course_ref);



my(%current_results);
#591;323.4;Wachusett;98;BlueHills;33;
#171;123.5;BlueHills;87.2;RavenRock;44.3;
# Initialize the summary file if needed
if ( ! -f "./summary.csv") {
  my($member_id);
  open(SUMMARY_FILE, ">./summary.csv");
  foreach $member_id (keys(%{$members_by_id_ref})) {
    print SUMMARY_FILE "$member_id;\n";
  }
  close(SUMMARY_FILE);
}


# Read the summary file
open(SUMMARY_FILE, "<./summary.csv");
while (<SUMMARY_FILE>) {
  chomp;
  my($member_id, $total_points_so_far, @events_course_and_points) = split(";");
  $current_results{$member_id} = {};
  $current_results{$member_id}->{$TOTAL_POINTS_KEY} = $total_points_so_far;
  $current_results{$member_id}->{$EVENTS_KEY} = \@events_course_and_points;
  print "Found member $member_id, $members_by_id_ref->{$member_id}, current points $total_points_so_far.\n" if (($DEBUG & $FULL_DEBUG) != 0); 
}
close(SUMMARY_FILE);


my(@members) = keys(%current_results);

# Read the input file
#MemberId;FirstName;LastName;Course;DNF;FinishPlace;BasePointsScored
#NONE;Chris;Dalke, Ben Martell;White;0;1;100.60
# Match with a member and save the information
while (<>) {
  chomp;
  next if (/^MemberId/);

  my($member_id, $first_name, $last_name, $course, $dnf, $finish_place, $points) = split(";");
  print "Found result $member_id: $first_name, $last_name, $points.\n" if (($DEBUG & $FULL_DEBUG) != 0);

  my($result_name_key) = "$last_name;$first_name";
  $member_id =~ s/-[a-z]$//;   # Strip off the single character suffix if there is one

  if ($member_id ne "NONE") {
    if (!exists($current_results{$member_id}->{$NEW_EVENT_KEY})) {
      $current_results{$member_id}->{$NEW_EVENT_KEY} = [];
    }
    my($new_event_index) = $#{$current_results{$member_id}->{$NEW_EVENT_KEY}} + 1;
    my($new_event_hash) = {};
    $new_event_hash->{$NEW_EVENT_POINTS} = $points;
    $new_event_hash->{$NEW_EVENT_COURSE} = $course;
    $new_event_hash->{$NEW_EVENT_NAME_KEY} = $ARGV;
    $current_results{$member_id}->{$NEW_EVENT_KEY}->[$new_event_index] = $new_event_hash;
  }
  else {
    print "Name \"$result_name_key\" does not appear to be a member, ignoring it.\n" if (($DEBUG & $FULL_DEBUG) != 0);
  }
}


# Walk through the members, looking for those with new information
# Pick their best course from the information
my($member);
foreach $member (keys(%current_results)) {
  # New information for this member, pick their best event for the day
  if (exists($current_results{$member}->{$NEW_EVENT_KEY})) {
    if ($#{$current_results{$member}->{$NEW_EVENT_KEY}} > 0) {
      my(@results_set) = @{$current_results{$member}->{$NEW_EVENT_KEY}};
      @results_set = sort { $b->{$NEW_EVENT_POINTS} <=> $a->{$NEW_EVENT_POINTS} } @results_set;
      print "$members_by_id_ref->{$member} ran " . ($#results_set + 1) . " courses, best was $results_set[0]->{$NEW_EVENT_COURSE} with $results_set[0]->{$NEW_EVENT_POINTS} points.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);

      my($new_results) = [];
      $new_results->[0] = $results_set[0];
      $current_results{$member}->{$NEW_EVENT_KEY} = $new_results;
    }
    else {
      my(@results_set) = @{$current_results{$member}->{$NEW_EVENT_KEY}};
      print "$members_by_id_ref->{$member} ran " . ($#results_set + 1) . " course $results_set[0]->{$NEW_EVENT_COURSE} with $results_set[0]->{$NEW_EVENT_POINTS} points.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
    }

    # Update their total points and the list of events scoring points
    # Convert to an easily sortable array of hashes
    my(@prior_events) = ();
    my($index, $hash_index);
    for ($index = 0, $hash_index = 0; $index <= $#{$current_results{$member}->{$EVENTS_KEY}}; $index += 3, $hash_index++) {
      $prior_events[$hash_index] = {};
      $prior_events[$hash_index]->{$NEW_EVENT_NAME_KEY} = $current_results{$member}->{$EVENTS_KEY}->[$index];
      $prior_events[$hash_index]->{$NEW_EVENT_POINTS} = $current_results{$member}->{$EVENTS_KEY}->[$index + 1];
      $prior_events[$hash_index]->{$NEW_EVENT_COURSE} = $current_results{$member}->{$EVENTS_KEY}->[$index + 2];
    }
    $prior_events[$hash_index] = {};
    $prior_events[$hash_index]->{$NEW_EVENT_NAME_KEY} = $current_results{$member}->{$NEW_EVENT_KEY}->[0]->{$NEW_EVENT_NAME_KEY};
    $prior_events[$hash_index]->{$NEW_EVENT_POINTS} = $current_results{$member}->{$NEW_EVENT_KEY}->[0]->{$NEW_EVENT_POINTS};
    $prior_events[$hash_index]->{$NEW_EVENT_COURSE} = $current_results{$member}->{$NEW_EVENT_KEY}->[0]->{$NEW_EVENT_COURSE};
  
    # Sort them (top 10 results count)
    @prior_events = sort { $b->{$NEW_EVENT_POINTS} <=> $a->{$NEW_EVENT_POINTS} } @prior_events;
  
    my($new_total_points) = 0;
    for ($index = 0; ($index <= $#prior_events) && ($index < 10); $index++) {
      $new_total_points += $prior_events[$index]->{$NEW_EVENT_POINTS};
    }
  
    $current_results{$member}->{$TOTAL_POINTS_KEY} = $new_total_points;
    my(@new_event_set) = map { ( $_->{$NEW_EVENT_NAME_KEY}, $_->{$NEW_EVENT_POINTS}, $_->{$NEW_EVENT_COURSE} ) } @prior_events;
    $current_results{$member}->{$EVENTS_KEY} = \@new_event_set;
  
    print "$members_by_id_ref->{$member} new total points: $new_total_points, events: " . join(";", @{$current_results{$member}->{$EVENTS_KEY}}) . "\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
    #print "\t" . join("=", @new_event_set) . "\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
  }
}


# save the results back to the summary file
my($now) = strftime '%Y-%m-%d-%H-%M-%S', localtime();
qx(cp summary.csv summary-backup-$now.csv);
open(SUMMARY_FILE, ">summary.csv");
my($member);
foreach $member (keys(%current_results)) {
  my($entry) = $current_results{$member};
  print SUMMARY_FILE join(";", $member, $entry->{$TOTAL_POINTS_KEY}, @{$entry->{$EVENTS_KEY}}) . "\n";
}
close(SUMMARY_FILE);
