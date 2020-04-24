#!/usr/bin/perl

use strict;
require "common_routines.pl";

my($FULL_DEBUG) = 0x1;
my($DEBUG_LEVEL_1) = 0x2;
my($DEBUG_LEVEL_2) = 0x4;
my($DEBUG_LEVEL_3) = 0x8;
#my($DEBUG) = $DEBUG_LEVEL_3 | $DEBUG_LEVEL_2 | $DEBUG_LEVEL_1 | $FULL_DEBUG | 0;
#my($DEBUG) = $DEBUG_LEVEL_3 | $DEBUG_LEVEL_2 | 0;
my($DEBUG) = 0;

my($FINISH_OK) = 0;
my($FINISH_DNF) = 2;
my($FINISH_MP) = 3;

my($COURSE_SCORING_BY_COURSE) = "normal";
my($COURSE_SCORING_BY_AGE_AND_GENDER) = "by_age_and_gender";
my($COURSE_SCORING_BY_GENDER) = "by_gender";
my($COURSE_SCORING_ZERO) = "zero";
my($COURSE_SCORING_CATEGORY_SEPARATOR) = ":";


# Read in the course adjustments
#$base_points_scored *= $course_bonus{$target_course_by_id{$member_id}}->{$course_name};
my(%course_bonus) = ();
open(COURSE_ADJUSTMENT_FILE, "<./course_adjustment.csv");
while(<COURSE_ADJUSTMENT_FILE>) {
  next if (/^Target/);
  chomp;
  my($target_course, $actual_course, $factor) = split(";");
  if (!exists($course_bonus{$target_course})) {
    $course_bonus{$target_course} = {};
  }

  $course_bonus{$target_course}->{$actual_course} = $factor;
  print "Bonus for running $actual_course instead of $target_course is: $factor.\n" if (($DEBUG & $FULL_DEBUG) != 0);
}
close (COURSE_ADJUSTMENT_FILE);


# Read in the scoring mode for the various courses
my(%course_scoring_mode) = ();
open(COURSE_SCORING_MODE_FILE, "<./course_to_scoring_mode.csv");
while(<COURSE_SCORING_MODE_FILE>) {
  next if (/^CourseName/);
  chomp;
  my($target_course, $scoring_mode) = split(";");
  $course_scoring_mode{$target_course} = $scoring_mode;

  print "Scoring mode for $target_course set to $scoring_mode.\n" if (($DEBUG & $FULL_DEBUG) != 0);
}
close (COURSE_SCORING_MODE_FILE);

my($year_to_course_ref) = read_year_to_course();

my($members_by_id_ref, $target_course_by_id_ref, $genders_by_id_ref, $last_name_to_ids_ref) = read_member_list($year_to_course_ref);


# Allow the specification of an output file
# and the specification of what year the results are for
my($outfile_name) = "results_of_meet.csv";
my($year_of_results) = -1;
while ($ARGV[0] =~ /^-/) {
  if ($ARGV[0] eq "-o") {
    $outfile_name = $ARGV[1];
    shift; shift;
  }
  elsif ($ARGV[0] eq "-y") {
    $year_of_results = $ARGV[1];
    shift; shift;
  }
  else {
    print "Unknown option $ARGV[0].  Ignoring it.\n";
    shift;
  }
}

# If no year was specified, default to the currenty year
if ($year_of_results == -1) {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year_of_results = $year + 1900;
}
set_year_of_results($year_of_results);

#Stno;SI card;Database Id;Surname;First name;YB;S;Block;nc;Start;Finish;Time;Classifier;Club no.;Cl.name;City;Nat;Cl. no.;Short;Long;Num1;Num2;Num3;Text1;Text2;Text3;Adr. name;Street;Line2;Zip;City;Phone;Fax;EMail;Id/Club;Rented;Start fee;Paid;Course no.;Course;km;m;Course controls;Pl;Start punch;Finish punch;Control1;Punch1;Control2;Punch2;Control3;Punch3;Control4;Punch4;Control5;Punch5;Control6;Punch6;Control7;Punch7;Control8;Punch8;Control9;Punch9;Control10;Punch10;(may be more) ...
#21;2026367;;Grimm;Astrid;; ;;0;11:23:36;11:29:47;06:11;0;0;; ;;1;String;String;0;0;0; ;;;;;;;;;;;;1;0;0;8;String;0;0;8;1;11:23:36;11:29:47;145;00:30;146;01:19;147;01:36;148;02:09;149;02:25;150;03:02;151;04:31;152;05:30;150;03:04;150;03:06;;;;;;;;;;;;;;;;;;;;
#82;102026372;;Fiedler;Catherine;; ;;0;12:29:41;12:39:34;09:53;0;0;; ;;1;String;String;0;0;0; ;;;;;;;;;;;;0;0;0;8;String;0;0;8;2;12:29:41;12:39:34;145;00:29;146;02:01;147;02:22;148;03:00;149;03:47;150;04:44;151;06:46;152;09:03;;;;;;;;;;;;;;;;;;;;;;;;
#42;2056513;;Commons;Michael;; ;;0;12:21:29;13:37:19;75:50;0;1;;NEOC;;2;Short White;Short White;0;0;0; ;;;;;;;;;;;;0;0;0;9;Short White;0;0;3;1;12:21:29;13:37:19;157;25:26;158;34:39;165;71:21;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#42;2033301;;Miller;Patti;; ;;0;12:21:29;13:37:19;75:50;0;1;;NEOC;;2;Short White;Short White;0;0;0; ;;;;;;;;;;;;0;0;0;9;Short White;0;0;3;1;12:21:29;13:37:19;157;25:26;158;34:39;165;71:21;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#23;2026368;;Grimm;Torsten;; ;;0;11:34:15;12:16:05;41:50;0;0;; ;;3;White;White;0;0;0; ;;;;;;;;;;;;1;0;0;1;White;2.1;85;9;1;11:34:15;12:16:05;157;05:07;158;07:49;159;09:40;160;13:47;161;22:32;162;27:40;163;32:12;164;34:29;165;39:03;;;;;;;;;;;;;;;;;;;;;;
#8;2026372;;Liu;Julie;; ;;0;11:34:36;12:16:55;42:19;0;0;; ;;3;White;White;0;0;0; ;;;;;;;;;;;;1;0;0;1;White;2.1;85;9;2;11:34:36;12:16:55;157;04:50;158;07:24;159;09:16;160;13:30;161;22:14;162;27:20;163;31:49;164;34:06;165;38:39;;;;;;;;;;;;;;;;;;;;;;
#22;2026366;;Grimm;Andrew;; ;;0;11:34:29;12:16:48;42:19;0;0;; ;;3;White;White;0;0;0; ;;;;;;;;;;;;1;0;0;1;White;2.1;85;9;2;11:34:29;12:16:48;157;05:15;158;07:44;159;09:38;160;13:46;161;22:04;162;27:13;163;32:05;164;34:43;165;38:52;;;;;;;;;;;;;;;;;;;;;;
#9;2026373;;Liu;Jason;; ;;0;11:34:16;12:17:22;43:06;0;0;; ;;3;White;White;0;0;0; ;;;;;;;;;;;;1;0;0;1;White;2.1;85;9;4;11:34:16;12:17:22;157;05:14;158;07:47;159;09:38;160;13:56;161;22:28;162;26:56;163;32:08;164;34:48;165;38:55;;;;;;;;;;;;;;;;;;;;;;
#47;4619318;;Ellis;Michael;; ;;0;11:44:33;12:27:50;43:17;0;0;; ;;3;White;White;0;0;0; ;;;;;;;;;;;;1;0;0;1;White;2.1;85;9;5;11:44:33;12:27:50;157;03:27;158;05:39;159;08:01;160;11:43;161;17:48;162;25:00;163;31:35;164;34:46;165;39:36;;;;;;;;;;;;;;;;;;;;;;

my(%num_competitors_per_course_per_gender);
$num_competitors_per_course_per_gender{"M"} = {};
$num_competitors_per_course_per_gender{"F"} = {};
$num_competitors_per_course_per_gender{"O"} = {};
my(@point_scorers);
while (<>) {
  chomp;
  s/\r//;
  print "Line is \"$_\"\n" if (($DEBUG & $FULL_DEBUG) != 0);
  next if (/^Stno;SI/);
  my($start_number, $si_card, $db_id, $last_name, $first_name, $YB, $S_field, $Block_field, $non_compete, $start_time, $finish_time, $time_taken, $classifier, $club_member_number, $huh,
     $club_name, $nationality, $class_number, $course_name, $long, $number_1, $number_2, $number_3, $text_1, $text_2, $text_3, 
     $address_name, $street, $address_line_2, $address_zip, $address_city, $address_phone, $fax_number, $email, $club_id, $stick_was_rented, $start_fee_paid, $amount_paid, 
     $course_number, $full_course_name, $kilometers, $meters, $number_controls, $finish_place, $start_punch_time, $finish_punch_time, @controls_and_punches) = split(";"); 

  # Not sure why, but sometimes these fields are surrounded by quotes
  $first_name =~ s/"//g;
  $first_name =~ s/^\s+//;
  $first_name =~ s/\s+$//;

  $last_name =~ s/"//g;
  $last_name =~ s/^\s+//;
  $last_name =~ s/\s+$//;

  $club_name =~ s/"//g;
  $club_name =~ s/^\s+//;
  $club_name =~ s/\s+$//;

  $course_name =~ s/"//g;

  if ($course_name eq "") {
    $course_name = $full_course_name;
    $course_name =~ s/"//g;
  }

# print "$first_name $last_name is in $club_name, $time_taken, $classifier, $club_member_number, $huh.\n";
  print "Skipping $last_name;$first_name as non_competitor.\n" if ($non_compete);
  next if ($non_compete);


  my($dnf) = 0;
  $dnf = 1 if ($classifier != $FINISH_OK);
  print "$first_name $last_name competed on $course_name and finished $finish_place (DNF = $dnf, classifier = $classifier) out of UNKNOWN competitors.\n"  if (($DEBUG & $DEBUG_LEVEL_1) != 0);
#  my($index, $controls_punched) = (0,0);
#  for ($index = 1; $index <= $#controls_and_punches; $index += 2) {
#    print "Checking $index: $controls_and_punches[$index]\n" if (($DEBUG & $FULL_DEBUG) != 0);
#    my($time_at_control) = $controls_and_punches[$index];
#    $time_at_control =~ s/"//g;
#    if ($time_at_control eq "-----") {
#      $dnf = 1;
#    }
#    if (($time_at_control ne "-----") && ($time_at_control ne "")) {
#      print "GOOD: $index: $controls_and_punches[$index]\n" if (($DEBUG & $FULL_DEBUG) != 0);
#      $controls_punched++;
#    }
#  }
#  #print "Classifier is $classifier, DNF is $dnf.\n";
#  if (($classifier == $FINISH_OK) && $dnf) {
#    print "$first_name, $last_name, $course_name, $ARGV, Classifier is $classifier, DNF is $dnf - NO MATCH.\n";
#  }
#  elsif (($classifier != $FINISH_OK) && !$dnf) {
#    print "$first_name, $last_name, $course_name, $ARGV, Classifier is $classifier, DNF is $dnf - NO MATCH.\n";
#  }
#  else {
#    print "Classifier is $classifier, DNF is $dnf - MATCH.\n";
#  }

  my($best_match) = find_best_name_match($members_by_id_ref, $last_name_to_ids_ref, $last_name, $first_name);
  if ($best_match eq "NONE") {

    my(@last_name_pieces) = split(' ', $last_name);
    my(@first_name_pieces) = split(' ', $first_name);
    if (($#last_name_pieces >= 0) || ($#first_name_pieces >= 0)) {
      # There's a space in the name - try switching the space from the first to last name (or vice-versa) as a final try
      my($index);
      for ($index = 1; $index <= $#last_name_pieces; $index++) {
         my($new_last_name) = join(" ", @last_name_pieces[$index..$#last_name_pieces]);
         my($new_first_name) = join(" ", @first_name_pieces, @last_name_pieces[0 .. $index - 1]);
         print "Trying $new_last_name;$new_first_name.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
         $best_match = find_best_name_match($members_by_id_ref, $last_name_to_ids_ref, $new_last_name, $new_first_name);
         last if ($best_match ne "NONE");
      }
      if ($best_match eq "NONE") {
        for ($index = 1; $index <= $#first_name_pieces; $index++) {
           my($new_last_name) = join(" ", @first_name_pieces[$index .. $#first_name_pieces], @last_name_pieces);
           my($new_first_name) = join(" ", @first_name_pieces[0 .. $index - 1]);
           print "Trying $new_last_name;$new_first_name.\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
           $best_match = find_best_name_match($members_by_id_ref, $last_name_to_ids_ref, $new_last_name, $new_first_name);
           last if ($best_match ne "NONE");
        }
      }
    }
  }
  print "Found $best_match for $last_name;$first_name, " . (($best_match ne "NONE") ? $members_by_id_ref->{$best_match} : "No matching member") . ".\n" if (($DEBUG & $DEBUG_LEVEL_3) != 0);
  
  my($current_gender);
  my($gender_finish_place);
  if ($best_match ne "NONE") {
    print "$ARGV: Found a match for $last_name;$first_name: $members_by_id_ref->{$best_match}\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
    $current_gender = $genders_by_id_ref->{$best_match};
  }
  else {
    if ($club_name ne "") {
      print "$last_name;$first_name claims to be in club \"$club_name\" but no matching name found.\n";
    }
    else {
      print "No match for $last_name;$first_name, ignoring it.\n";
    }
    $current_gender = "U";
  }

  my($course_name_for_scoring) = $course_name;
  if ($course_scoring_mode{$course_name} eq $COURSE_SCORING_BY_AGE_AND_GENDER) {
    if (exists($target_course_by_id_ref->{$best_match})) {
      $course_name_for_scoring = $course_name . $COURSE_SCORING_CATEGORY_SEPARATOR . $target_course_by_id_ref->{$best_match};
    }
    $num_competitors_per_course_per_gender{$current_gender}->{$course_name_for_scoring}++;
    $gender_finish_place = $num_competitors_per_course_per_gender{$current_gender}->{$course_name_for_scoring};
  }
  else {
    $num_competitors_per_course_per_gender{$current_gender}->{$course_name}++;
    $gender_finish_place = $num_competitors_per_course_per_gender{$current_gender}->{$course_name};
  }

  print "$first_name $last_name $current_gender competed on $course_name ($course_name_for_scoring) and finished $gender_finish_place out of currently known $num_competitors_per_course_per_gender{$current_gender}->{$course_name} competitors.\n"  if (($DEBUG & $DEBUG_LEVEL_1) != 0);
  print "$first_name $last_name found " . join("--", @controls_and_punches) . " on $course_name ($course_name_for_scoring).\n"  if (($DEBUG & $DEBUG_LEVEL_1) != 0);
  print "$first_name $last_name competed on $course_name ($course_name_for_scoring): $gender_finish_place/$num_competitors_per_course_per_gender{$current_gender}->{$course_name} " . ($dnf ? "DNF" : "good") . ".\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);

  push(@point_scorers, join(";", $best_match, $first_name, $last_name, $course_name, $course_name_for_scoring, $dnf, $gender_finish_place));
}


open(OUTPUT_FILE, ">$outfile_name");
print OUTPUT_FILE join(";", "MemberId", "FirstName", "LastName", "Course", "DNF", "FinishPlace", "BasePointsScored") . "\n";
my($entry);
foreach $entry (@point_scorers) {
  my($member_id, $first_name, $last_name, $course_name, $course_name_for_scoring, $dnf, $finish_place) = split(";", $entry);
  my($base_points_scored);

  $member_id =~ s/-[a-z]$//;  # Strip off the suffix, if there is one
  if ($dnf || ($member_id eq "NONE")) {
    $base_points_scored = 0;
  }
  else {
    my($total_competitors) = $num_competitors_per_course_per_gender{$genders_by_id_ref->{$member_id}}->{$course_name_for_scoring};
    if ($total_competitors == 0) {
      print "Entry $entry has 0 competitors, id:$member_id, G:$genders_by_id_ref->{$member_id}\n";
    }
    # Award points in this mode for the %age of competitors that I beat
    $base_points_scored = ((($total_competitors - $finish_place + 1)) / $total_competitors) * 100;
    $base_points_scored += ($total_competitors / 10);
    if (($course_scoring_mode{$course_name} eq $COURSE_SCORING_BY_COURSE) && exists($course_bonus{$target_course_by_id_ref->{$member_id}}->{$course_name})) {
      $base_points_scored *= $course_bonus{$target_course_by_id_ref->{$member_id}}->{$course_name};

      if ($target_course_by_id_ref->{$member_id} ne $course_name) {
        print "Runner \"$first_name $last_name\" ran wrong course ($course_name instead of $target_course_by_id_ref->{$member_id}), scaling result by: $course_bonus{$target_course_by_id_ref->{$member_id}}->{$course_name}\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
      }
    }
    elsif ($course_scoring_mode{$course_name} eq $COURSE_SCORING_BY_GENDER) {
      print "Runner \"$first_name $last_name\" scored by gender on course $course_name_for_scoring, no scaling.\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
    }
    elsif ($course_scoring_mode{$course_name} eq $COURSE_SCORING_BY_AGE_AND_GENDER) {
      print "Runner \"$first_name $last_name\" scored by age/gender on course $course_name_for_scoring, no scaling.\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
    }
    elsif ($course_scoring_mode{$course_name} eq $COURSE_SCORING_ZERO) {
      print "Runner \"$first_name $last_name\" on course $course_name_for_scoring which is worth zero points.\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
      $base_points_scored = 0;
    }
    else {
      print "Runner \"$first_name $last_name\" ran unknown course ($course_name instead of $target_course_by_id_ref->{$member_id}), no points\n" if (($DEBUG & $DEBUG_LEVEL_2) != 0);
      $base_points_scored = 0;
    }
  }
  my($points) = sprintf("%0.3f", $base_points_scored);

  print OUTPUT_FILE join(";", $member_id, $first_name, $last_name, $course_name_for_scoring, $dnf, $finish_place, $points) . "\n";
}
close(OUTPUT_FILE);
