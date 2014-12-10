#!/usr/local/pipeline-link/perl
# create_affine_reg_to_atlas_vbm.pm 





my $PM = "create_affine_reg_to_atlas_vbm.pm";
my $VERSION = "2014/11/25";
my $NAME = "Create bulk rigid/affine registration to a specified atlas";
my $DESC = "ants";
my $ggo = 1;  # Needed for compatability with seg_pipe code

use strict;
use warnings;
no warnings qw(uninitialized);

use vars qw($Hf $BADEXIT $GOODEXIT $test_mode);
require Headfile;
require pipeline_utilities;

my ($atlas,$contrast, $runlist,$work_path,$current_path);
my ($xform_code,$xform_path,$xform_suffix,$domain_dir,$domain_path,$inputs_dir);
my (@array_of_runnos,@jobs);
my (%create_go,%create_output);
my $go = 1;
my $job;

# ------------------
sub create_affine_reg_to_atlas_vbm {  # Main code
# ------------------


    create_affine_reg_to_atlas_vbm_Runtime_check();

    foreach my $runno (@array_of_runnos) {
	my $to_xform_path=get_nii_from_inputs($inputs_dir,$runno,$contrast);
	my $result_path_base = "${current_path}/${runno}_";
	$go = $create_go{$runno};
	$xform_suffix =  $Hf->get_value('rigid_transform_suffix');
	#get_target_path($runno,$contrast);


	($xform_path,$job) = create_affine_transform($go,$xform_code, $domain_path, $to_xform_path,  $result_path_base, '',$PM); # We are setting atlas as fixed and current runno as moving...this is opposite of what happens in seg_pipe_mc, when you are essential passing around the INVERSE of that registration to atlas step, but accounting for it by setting "-i 1" with $do_inverse_bool.

	my @f_xform_array = $forward_xform_hash->{$runno};
	my @i_xform_array = $inverse_xform_hash->{$runno};
	$forward_xform_hash->{$runno}=push(@f_xform_array,"$xform_path");
	$inverse_xform_hash->{$runno}=push("-i $xform_path",@i_xform_array);
	
	if ($xform_suffix eq 'NO_KEY') {
	    if ($xform_path =~ m/${result_path_base}(.*$)/) { #grep to get suffix
		$xform_suffix = $1;
		print STDOUT " Ants adds the following suffix to the resulting affine transforms: ${xform_suffix}\n";
		$Hf->set_value('rigid_transform_suffix',$xform_suffix);
	    }
	}

	if ($job > 1) {
	    push(@jobs,$job);
	}
    }

    if (cluster_check()) {
	my $interval = 2;
	my $verbose = 1;
	my $done_waiting = cluster_wait_for_jobs($interval,$verbose,@jobs);

	if ($done_waiting) {
	    print STDOUT  "  All rigid registration jobs have completed; moving on to next step.\n";
	}
    }
}

# ------------------
sub create_affine_reg_to_atlas_vbm_Init_check {
# ------------------
    my $init_error_msg='';
    my $message_prefix="$PM:\n";

# check for valid atlas
    $atlas = $Hf->get_value('atlas_name');
    $contrast = $Hf->get_value('rigid_contrast');
 
    $domain_dir   = $Hf->get_value ('rigid_atlas_dir');   
    $domain_path  = "$domain_dir/${atlas}_${contrast}.nii"; 
    if (!-e $domain_path)  {
	$init_error_msg = $init_error_msg."For rigid contrast ${contrast}: missing domain nifti file ${domain_path}\n";
    } else {
	$Hf->set_value('rigid_atlas_path',$domain_path);
    }


    $inputs_dir = $Hf->get_value('inputs_dir');
    if ($init_error_msg ne '') {
	$init_error_msg = $message_prefix.$init_error_msg;
    }
    return($init_error_msg);
}

# ------------------
sub create_affine_reg_to_atlas_vbm_Runtime_check {
# ------------------

# Set up work
    $work_path = $Hf->get_value('work_dir');
    $current_path = $Hf->get_value('rigid_work_dir');

    if ($current_path eq 'NO_KEY') {
	$current_path = "${work_path}/${contrast}";
	$Hf->set_value('rigid_work_dir',$current_path);
	if (! -e $current_path) {
	    mkdir ($current_path,0777);
	}
    }

    $runlist = $Hf->get_value('complete_comma_list');
    @array_of_runnos = split(',',$runlist);


    $xform_code = 'rigid1';
    $xform_suffix = $Hf->get_value('rigid_transform_suffix');


# check for output files
    my $full_file;
    my $existing_files_message_prefix = "  Rigid transform(s) already exist for the following runno(s) and will not be recalculated:\n";
    my $existing_files_message = '';
    foreach my $runno (@array_of_runnos) {
	if ($xform_suffix ne 'NO_KEY') {
	    $full_file = "${current_path}/${runno}_${xform_suffix}";
	    if (! -e  $full_file) {
		$create_go{$runno}=1;
	#	$create_output{$runno} = $full_file; # Don't think this is really useful...
	    } else {
		$create_go{$runno}=0;
		$existing_files_message = $existing_files_message."   $runno \n";
	    }
	} else {
	    $create_go{$runno} = 1;
	}
    }
    if ($existing_files_message ne '') {
	print STDOUT "$PM\n${existing_files_message_prefix}${existing_files_message}";
    }
# check for needed input files to produce output files which need to be produced in this step

    my $missing_files_message_prefix = " Unable to locate input images for the following runno(s):\n";
    my $missing_files_message = '';
    my $missing_files_message_postfix = " Process stopped during $PM. Please check input runnos and try again.\n";
    foreach my $runno (@array_of_runnos) {
	if ($create_go{$runno}) {
	    my $file_path = get_nii_from_inputs($inputs_dir,$runno,$contrast);
	    if ($file_path eq '0') {
		$missing_files_message = $missing_files_message."   $runno \n";
	    }
	}
    }
    if ($missing_files_message ne '') {
	error_out("$PM:\n${missing_files_message_prefix}${missing_files_message}${missing_files_message_postfix}",0);
    }
}
1;