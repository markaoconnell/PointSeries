#!/usr/bin/perl

use strict;

require "common_routines.pl";
require "config.pl";

my($FULL_DEBUG) = 0x1;
my($DEBUG_LEVEL_1) = 0x2;
my($DEBUG_LEVEL_2) = 0x4;
my($DEBUG_LEVEL_3) = 0x8;
#my($DEBUG) = $FULL_DEBUG | $DEBUG_LEVEL_1 | $DEBUG_LEVEL_2 | $DEBUG_LEVEL_3 | 0;
my($DEBUG) = 0;

my($TOTAL_POINTS_KEY) = "total_points";
my($EVENTS_KEY) = "events_key";
my($EVENT_NAME_TO_POINTS) = 1;
my($EVENT_NAME_TO_COURSE) = 2;

my($SUMMARY_MEMBER_KEY) = "member";
my($SUMMARY_POINTS_KEY) = "points";

my($html_results) = 1;
my($print_html_header) = 1;

my($year_to_course_ref) = read_year_to_course();

my($members_by_id_ref, $target_course_by_id_ref, $genders_by_id_ref, $last_name_to_ids_ref) = read_member_list($year_to_course_ref);

my(%config) = read_configuration();
my(@odd_even) = qw(even odd);
my($result_year) = "";
my($output_file) = "";

#Process the command line options
while ($ARGV[0] =~ /^-/) {
  if ($ARGV[0] eq "-nohtml") {
    $html_results = 0;
    shift;
  }
  elsif ($ARGV[0] eq "-nohdr") {
    $print_html_header = 0;
    shift;
  }
  elsif ($ARGV[0] eq "-year") {
    $result_year = $ARGV[1];
    shift; shift;
  }
  elsif ($ARGV[0] eq "-o") {
    $output_file = $ARGV[1];
    shift; shift;
  }
  else {
    print "Warning: Ignoring unknown option $ARGV[0].\n";
    shift;
  }
}

#Read the Friendly names of the events
my(%friendly_names);
open(FRIENDLY_NAME_FILE, "<./friendly_names.csv");
while(<FRIENDLY_NAME_FILE>) {
  next if (/^#/);  # skip comment lines
  chomp;
  my($filename, $friendly_name) = split(";");
  $friendly_names{$filename} = $friendly_name;
}
close(FRIENDLY_NAME_FILE);


my(%current_results);
# Read the summary file
#591;323.4;Wachusett;98;BlueHills;33;
#171;123.5;BlueHills;87.2;RavenRock;44.3;

my(%results_by_course);
open(SUMMARY_FILE, "<./summary.csv");
while (<SUMMARY_FILE>) {
  chomp;
  my($member_id, $total_points_so_far, @events_and_points) = split(";");

  print "Found member $member_id, $members_by_id_ref->{$member_id}, current points $total_points_so_far.\n" if (($DEBUG & $FULL_DEBUG) != 0); 
  next if ($#events_and_points == -1);  # member has not run any events, just skip them

  $current_results{$member_id} = {};
  $current_results{$member_id}->{$TOTAL_POINTS_KEY} = $total_points_so_far;
  $current_results{$member_id}->{$EVENTS_KEY} = \@events_and_points;

  my($result_key) = $target_course_by_id_ref->{$member_id} . "-" . $genders_by_id_ref->{$member_id};
  if (!exists($results_by_course{$result_key})) {
    $results_by_course{$result_key} = [];
  }
  push(@{$results_by_course{$result_key}}, $member_id);
  print "Adding $members_by_id_ref->{$member_id}:$member_id to $result_key with points $current_results{$member_id}->{$TOTAL_POINTS_KEY}\n" .
        "\tand events: " . join("-", @{$current_results{$member_id}->{$EVENTS_KEY}}) . "\n" if (($DEBUG & $FULL_DEBUG) != 0);
}
close(SUMMARY_FILE);

if ($output_file eq "") {
  open(OUTPUT_FILE, ">-");  # use STDOUT
}
else {
  open(OUTPUT_FILE, ">$output_file");
}

my($course, $gender);

html_print_header();
my($page_prefix) = $config{"web_summary_title_prefix"};
my($suffix) = "";
$suffix = " for $result_year" if ($result_year ne "");
html_print_simple($config{"web_summary_results_banner"}, $page_prefix . " Results" . $suffix . "\n\n");


# Print the overall results for each age group
foreach $course (qw(White Yellow Orange Brown Green Red Blue)) {
  foreach $gender (qw(M F)) {
    my($result_key) = $course . "-" . $gender;
    if (!exists($results_by_course{$result_key})) {
      $results_by_course{$result_key} = [];
    }
    
    html_print_simple($config{"web_summary_results_class_" . lc($course)}, "Results for $gender $course\n\n");
    print "$course-$gender has " . ($#{$results_by_course{$result_key}} + 1) . " results.\n" if (($DEBUG & $FULL_DEBUG) != 0);
    my(@sorted_results) = sort { $current_results{$b}->{$TOTAL_POINTS_KEY} <=> $current_results{$a}->{$TOTAL_POINTS_KEY} } @{$results_by_course{$result_key}};
    print "$result_key has sorted results: " . join(";", @sorted_results) . "\n" if (($DEBUG & $FULL_DEBUG) != 0);
    if ($#sorted_results >= 0) {
      my($member);
      html_print_table_header($config{"web_summary_results_class_header"}, "%-30s  %s   %s\n", "Name", "Total Points", "Events");
      my($row_count) = 0;
      foreach $member (@sorted_results) {
        my($last, $first) = split(";", $members_by_id_ref->{$member});
        my($formatted_points) = sprintf("%9.3f", $current_results{$member}->{$TOTAL_POINTS_KEY});
        html_print_entry($config{"web_summary_results_class_row_" . $odd_even[$row_count++ & 0x1]},
                            "%-30s  %9s        %3d\n", html_ref_anchor_name($last, $first), $formatted_points, int(($#{$current_results{$member}->{$EVENTS_KEY}} + 1) / 3));
      }
      html_print_end("\n\n\n\n");
    }
    else {
      html_print_table_header($config{"web_summary_results_class_header"}, "%-30s  %s   %s\n", "Name", "Total Points", "Events");
      html_print_entry($config{"web_summary_results_class_row_even"},
                            "%-30s  %9s        %3d\n", "No results found.", "", 0); 
      html_print_end("\n\n\n\n");
    }
    html_print_separator("\n\n\n\n");
  }
}


# Print the results per member
# Also gather the list of events to show per-event results
my($member_id);
my(%events_hash);
foreach $member_id (keys(%current_results)) {
  my($last, $first) = split(";", $members_by_id_ref->{$member_id});
  html_anchor_name($last, $first);
  html_print_simple($config{"web_summary_results_individual_name"}, "Results for $first $last.\n");
  html_print_table_header($config{"web_summary_results_individual_header"}, "%-30s    %-8s    \n", "Event Name", "Points");
  my(@events_list) = @{$current_results{$member_id}->{$EVENTS_KEY}};
  my($event_name_index);
  for ($event_name_index = 0; $event_name_index <= $#events_list; $event_name_index += 3) {
    if (!exists($events_hash{$events_list[$event_name_index]})) {
      $events_hash{$events_list[$event_name_index]} = {};
    }

    # Save the event result - grouped by course run and gender, for later printing (by event)
    my($event_ref) = $events_hash{$events_list[$event_name_index]};
    my($course_id) = $events_list[$event_name_index + $EVENT_NAME_TO_COURSE] . "-" . $genders_by_id_ref->{$member_id};
    if (!exists($event_ref->{$course_id})) {
      $event_ref->{$course_id} = [];
    }
    my($event_result_ref) = {};
    $event_result_ref->{$SUMMARY_MEMBER_KEY} = $member_id;
    $event_result_ref->{$SUMMARY_POINTS_KEY} = $events_list[$event_name_index + $EVENT_NAME_TO_POINTS];
    push(@{$event_ref->{$course_id}}, $event_result_ref);

    # Print the result for this member
    my($event_name_to_print) = $events_list[$event_name_index];
    $event_name_to_print =~ s#^.*/##;   # Get the basename of the event

    if (exists($friendly_names{$event_name_to_print})) {
      $event_name_to_print = $friendly_names{$event_name_to_print};
    }
    else {
      # Do a few standard manipulations on the name to make it nicer to print
      $event_name_to_print =~ s/\.csv//;
      $event_name_to_print =~ s/_edit.*$//;
    }

    my($count_points_for_this_event) = ($event_name_index < 30);
    my($formatted_points) = sprintf("%9.3f", $events_list[$event_name_index + $EVENT_NAME_TO_POINTS]);
    html_print_event_points($config{"web_summary_results_individual_row_" . $odd_even[$event_name_index & 0x1]},
                            "%-30s  %9s %-2s\n", $count_points_for_this_event, html_ref_anchor_event($event_name_to_print), $formatted_points);
  }
  my($formatted_points) = sprintf("%9.3f", $current_results{$member_id}->{$TOTAL_POINTS_KEY});
  html_print_entry($config{"web_summary_results_individual_total"}, "%-30s  %9s\n\n\n", "Total Points (10 events)", $formatted_points);
  html_print_end("");
}


# Now print the results per course
my($course_name);
foreach $course_name (sort(keys(%events_hash))) {
  my($event_name_to_print) = $course_name;

  # This should really be in a function rather than duplicated...
  $event_name_to_print =~ s#^.*/##;  # Get the basename of the event name file

  if (exists($friendly_names{$event_name_to_print})) {
    $event_name_to_print = $friendly_names{$event_name_to_print};
  }
  else {
    # Do a few standard manipulations on the name to make it nicer to print
    $event_name_to_print =~ s/\.csv//;
    $event_name_to_print =~ s/_edit.*$//;
  }
  html_anchor_event($event_name_to_print);
  html_print_simple($config{"web_summary_results_event_name"}, "Results for course: $event_name_to_print\n");
  
  my($course_color_gender);
  my($gender);

  # The net effect of this funniness with the course names is that
  # the "normal" color courses are shown first, in order of difficulty,
  # followed by any unusual courses which are scored - especially those
  # scored by age and gender.
  my(@course_list) = map { ($_ . "-F", $_ . "-M") } (qw(White Yellow Orange Tan Brown Green Red Blue));
  my(@all_courses_to_show) = sort(keys(%{$events_hash{$course_name}}));
  print "All courses at $course_name: " . join(";", @all_courses_to_show) . "\n" if (($DEBUG & $FULL_DEBUG) != 0);
  my(%courses_shown);
  foreach $course_color_gender (@course_list, @all_courses_to_show) {
      next if (!exists($events_hash{$course_name}->{$course_color_gender}));
      next if (exists($courses_shown{$course_color_gender}));
      $courses_shown{$course_color_gender} = 1;   # Record that we've shown this course

      my($event_ref) = $events_hash{$course_name}->{$course_color_gender};
      my(@sorted_results) = sort { $b->{$SUMMARY_POINTS_KEY} <=> $a->{$SUMMARY_POINTS_KEY} } @{$event_ref};
      my($color) = $course_color_gender;
      $color =~ s/^.*://;   # Strip off the course name for non-standard courses
      $color =~ s/-.*$//;   # Strip off the gender for all courses
      html_print_simple($config{"web_summary_results_class_" . lc($color)}, "Results for $course_color_gender.\n");
      
      html_print_table_header($config{"web_summary_results_event_header"}, "%-30s  %-8s\n", "Name", "Points");
      my($event_result_ref);
      my($entry_num) = 0;
      foreach $event_result_ref (@sorted_results) {
        my($last, $first) = split(";", $members_by_id_ref->{$event_result_ref->{$SUMMARY_MEMBER_KEY}});
        my($formatted_points) = sprintf("%9.3f", $event_result_ref->{$SUMMARY_POINTS_KEY});
        html_print_entry($config{"web_summary_results_event_row_" . $odd_even[$entry_num++ & 0x1]}, "%-30s  %9s\n", html_ref_anchor_name($last, $first), $formatted_points);
      }
      html_print_end("\n\n");
  }
  html_print_separator("\n\n\n");
}

html_print_trailer();

close(OUTPUT_FILE);

sub html_ref_anchor_event {
  my($event_name) = @_;
  if ($html_results) {
    return("<a href=\"\#$event_name\"> $event_name </a>");
  }
  else {
    return $event_name;
  }
}

sub html_ref_anchor_name {
  my($last, $first) = @_;
  if ($html_results) {
    return("<a href=\"\#$last;$first\"> $first $last </a>");
  }
  else {
    return ($first . " " . $last);
  }
}

sub html_anchor_event {
  my($event_name) = @_;
  if ($html_results) {
    print OUTPUT_FILE "<a name=\"$event_name\"></a>";
  }
}

sub html_anchor_name {
  my($last, $first) = @_;
  if ($html_results) {
    print OUTPUT_FILE "<a name=\"$last;$first\"></a>";
  }
}

sub html_print_entry {
  my($row_class, $format_string, @fields) = @_;
  $row_class = "class=\"$row_class\"" if ($row_class ne "");
  if ($html_results) {
    print OUTPUT_FILE "<tr $row_class><td>" . join("</td><td>", @fields) . "</td></tr>\n";
  }
  else {
    printf OUTPUT_FILE $format_string, @fields;
  }
}

sub html_print_event_points {
  my($row_class, $format_string, $event_points_valid, @fields) = @_;
  $row_class = "class=\"$row_class\"" if ($row_class ne "");

  if ($html_results) {
    if ($event_points_valid) {
      print OUTPUT_FILE "<tr $row_class><td>" . join("</td><td>", @fields) . "</td></tr>\n";
    }
    else {
      print OUTPUT_FILE "<tr $row_class><td><strike>" . join("</strike></td><td><strike>", @fields) . "</strike></td></tr>\n";
    }
  }
  else {
    if ($event_points_valid) {
      printf OUTPUT_FILE $format_string, @fields, "";
    }
    else {
      printf OUTPUT_FILE $format_string, @fields, "X";
    }
  }
}

sub html_print_table_header {
  my($row_class, $format_string, @fields) = @_;
  $row_class = "class=\"$row_class\"" if ($row_class ne "");

  if ($html_results) {
    print OUTPUT_FILE "<table><tr $row_class><th>" . join("</th><th>", @fields) . "</th></tr>\n";
  }
  else {
    printf OUTPUT_FILE $format_string, @fields;
  }
}

sub html_print_end {
  if ($html_results) {
    print OUTPUT_FILE "</table>\n";
  }
  else {
    print OUTPUT_FILE @_;
  }
}

sub html_print_simple {
  my($para_class, $string_to_print) = @_;
  $para_class = "class=\"$para_class\"" if ($para_class ne "");

  if ($html_results) {
    print OUTPUT_FILE "<p $para_class>$string_to_print</p>\n";
  }
  else {
    print OUTPUT_FILE "$string_to_print";
  }
}

sub html_print_separator {
  my($sep_string) = @_;
  if ($html_results) {
    print OUTPUT_FILE "<p><p><p>\n";
  }
  else {
    print OUTPUT_FILE $sep_string;
  }
}

sub html_print_header {
  if ($html_results && $print_html_header) {
    my($stylesheet) = $config{"web_summary_stylesheet"};
    $stylesheet = "<link href=\"$stylesheet\" rel=\"stylesheet\">" if ($stylesheet ne "");
    print OUTPUT_FILE "<html><head> <title>" . $config{"web_summary_title_prefix"} . " Results</title> $stylesheet </head> <body>\n";
  }
}

sub html_print_trailer {
  if ($html_results && $print_html_header) {
    print OUTPUT_FILE "</body></html>\n";
  }
}
