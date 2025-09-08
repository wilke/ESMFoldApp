#!/usr/bin/env perl
#
# The ESMFold application - protein structure prediction service
#

use strict;
use warnings;
use Bio::KBase::AppService::AppScript;
use Bio::KBase::AppService::AppConfig;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Temp;
use FindBin;
use JSON;
use Data::Dumper;

my $script = Bio::KBase::AppService::AppScript->new(\&process_esmfold, \&preflight);
$script->run(\@ARGV);

# Preflight function to define resource requirements
sub preflight {
    my($app, $app_def, $raw_params, $params) = @_;
    
    print STDERR "Preflight ESMFold with params:\n", Dumper($params);
    
    # Calculate resource requirements based on input
    my $memory = "32G";  # Default memory
    my $cpu = 8;         # Default CPUs
    my $runtime = 3600;  # Default 1 hour
    
    # Adjust based on parameters
    if ($params->{max_sequence_length}) {
        if ($params->{max_sequence_length} > 1024) {
            $memory = "64G";
            $runtime = 10800;  # 3 hours for very long sequences
        } elsif ($params->{max_sequence_length} > 512) {
            $memory = "48G";
            $runtime = 7200;   # 2 hours for longer sequences
        }
    }
    
    if ($params->{use_gpu} && $params->{use_gpu} eq 'false') {
        $cpu = 16;
        $memory = "64G";
        $runtime = 14400;  # 4 hours for CPU-only
    }
    
    my $pf = {
        cpu => $cpu,
        memory => $memory,
        runtime => $runtime,
        storage => "10G",
        is_control_task => 0,
    };
    
    print STDERR "Preflight requirements: ", Dumper($pf);
    return $pf;
}

# Main processing function
sub process_esmfold {
    my($app, $app_def, $raw_params, $params) = @_;
    
    print "Starting ESMFold structure prediction\n";
    print STDERR "Parameters: ", Dumper($params);
    
    # Validate required parameters
    my $sequences = $params->{sequences} or die "Missing required parameter: sequences\n";
    my $output_path = $params->{output_path} or die "Missing required parameter: output_path\n";
    my $output_file_basename = $params->{output_file_basename} || "esmfold_results";
    
    # Set up workspace paths
    my $ws = $app->workspace();
    
    # Create temporary working directory
    my $tmpdir = File::Temp->newdir();
    my $work_dir = "$tmpdir/work";
    make_path($work_dir);
    
    print "Working directory: $work_dir\n";
    
    # Download input FASTA file from workspace
    my $input_file = "$work_dir/input.fasta";
    print "Downloading input sequences from workspace...\n";
    
    eval {
        $ws->download_file($sequences, $input_file, 1);
    };
    if ($@) {
        die "Error downloading input file: $@\n";
    }
    
    # Validate FASTA format
    validate_fasta($input_file);
    
    # Prepare output directory
    my $output_dir = "$work_dir/output";
    make_path($output_dir);
    
    # Build ESMFold command
    my @cmd = build_esmfold_command($params, $input_file, $output_dir);
    
    print "Running ESMFold with command: @cmd\n";
    
    # Execute ESMFold
    my $start_time = time;
    my $rc = system(@cmd);
    my $elapsed = time - $start_time;
    
    if ($rc != 0) {
        die "ESMFold execution failed with return code: $rc\n";
    }
    
    print "ESMFold completed in $elapsed seconds\n";
    
    # Process results
    my $results = process_results($output_dir, $output_file_basename);
    
    # Create summary report
    my $summary_file = "$work_dir/${output_file_basename}_summary.json";
    create_summary_report($summary_file, $results, $params, $elapsed);
    
    # Upload results to workspace
    print "Uploading results to workspace...\n";
    upload_results($app, $ws, $work_dir, $output_dir, $output_path, $output_file_basename);
    
    print "ESMFold structure prediction completed successfully\n";
    print "Results saved to: $output_path\n";
    
    # Clean up temporary files
    remove_tree($tmpdir);
}

# Validate FASTA file format
sub validate_fasta {
    my ($file) = @_;
    
    open(my $fh, '<', $file) or die "Cannot open FASTA file: $!\n";
    my $header_count = 0;
    my $seq_count = 0;
    
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^>/) {
            $header_count++;
        } elsif ($line =~ /^[A-Za-z]+$/) {
            $seq_count++;
        } elsif ($line !~ /^\s*$/) {
            die "Invalid FASTA format: unexpected characters in line: $line\n";
        }
    }
    close($fh);
    
    if ($header_count == 0) {
        die "Invalid FASTA format: no sequence headers found\n";
    }
    if ($seq_count == 0) {
        die "Invalid FASTA format: no sequences found\n";
    }
    
    print "Validated FASTA file: $header_count sequences\n";
}

# Build ESMFold command based on parameters
sub build_esmfold_command {
    my ($params, $input_file, $output_dir) = @_;
    
    my @cmd;
    
    # Check if we're using container or native installation
    my $container_path = $ENV{ESMFOLD_CONTAINER} || '/nfs/ml_lab/projects/ml_lab/cepi/alphafold/images/esmfold.v0.1.sif';
    
    if (-f $container_path) {
        # Use apptainer/singularity container
        my $container_cmd = 'apptainer';
        unless (system("which apptainer > /dev/null 2>&1") == 0) {
            $container_cmd = 'singularity';
            unless (system("which singularity > /dev/null 2>&1") == 0) {
                die "Neither apptainer nor singularity found in PATH\n";
            }
        }
        
        @cmd = ($container_cmd, 'run');
        
        # Add GPU support if available and requested
        if ($params->{use_gpu} && $params->{use_gpu} ne 'false') {
            if (system("nvidia-smi > /dev/null 2>&1") == 0) {
                push @cmd, '--nv';
            }
        }
        
        # Add bind mounts
        push @cmd, '--bind', "$input_file:/input.fasta";
        push @cmd, '--bind', "$output_dir:/output";
        push @cmd, $container_path;
        
        # Check if wrapper exists in container, otherwise use esm-fold directly
        my $wrapper_check = `apptainer exec $container_path test -x /scripts/esm-fold-wrapper && echo "exists"`;
        if ($wrapper_check =~ /exists/) {
            push @cmd, '/scripts/esm-fold-wrapper';  # Use wrapper to ensure correct Python
        } else {
            push @cmd, 'esm-fold';  # Use built-in esm-fold command
        }
        
        # Adjust paths for container
        $input_file = '/input.fasta';
        $output_dir = '/output';
    } else {
        # Use native installation via scripts
        my $script_path = "$FindBin::Bin/../scripts/esmfold";
        if (-x $script_path) {
            @cmd = ($script_path);
        } else {
            die "ESMFold executable not found. Please set ESMFOLD_CONTAINER or install ESMFold\n";
        }
    }
    
    # Add required arguments
    push @cmd, '-i', $input_file;
    push @cmd, '-o', $output_dir;
    
    # Add optional parameters
    if (defined $params->{num_recycles}) {
        push @cmd, '--num-recycles', $params->{num_recycles};
    }
    
    if (defined $params->{chunk_size}) {
        push @cmd, '--chunk-size', $params->{chunk_size};
    }
    
    if ($params->{batch_sequences} && $params->{batch_sequences} eq 'true') {
        if (defined $params->{max_tokens_per_batch}) {
            push @cmd, '--max-tokens-per-batch', $params->{max_tokens_per_batch};
        }
    }
    
    if ($params->{use_gpu} && $params->{use_gpu} eq 'false') {
        push @cmd, '--cpu-only';
    }
    
    if ($params->{cpu_offload} && $params->{cpu_offload} eq 'true') {
        push @cmd, '--cpu-offload';
    }
    
    return @cmd;
}

# Process ESMFold output files
sub process_results {
    my ($output_dir, $basename) = @_;
    
    my @results;
    
    # Find all PDB files in output directory
    opendir(my $dh, $output_dir) or die "Cannot open output directory: $!\n";
    my @pdb_files = grep { /\.pdb$/ } readdir($dh);
    closedir($dh);
    
    foreach my $pdb_file (@pdb_files) {
        my $seq_id = basename($pdb_file, '.pdb');
        
        # Get file size
        my $file_path = "$output_dir/$pdb_file";
        my $file_size = -s $file_path;
        
        # Count atoms in PDB file (basic validation)
        my $atom_count = count_pdb_atoms($file_path);
        
        push @results, {
            sequence_id => $seq_id,
            pdb_file => $pdb_file,
            file_size => $file_size,
            atom_count => $atom_count
        };
    }
    
    return \@results;
}

# Count atoms in PDB file
sub count_pdb_atoms {
    my ($file) = @_;
    
    my $count = 0;
    open(my $fh, '<', $file) or return 0;
    
    while (my $line = <$fh>) {
        if ($line =~ /^ATOM\s+/ || $line =~ /^HETATM\s+/) {
            $count++;
        }
    }
    close($fh);
    
    return $count;
}

# Create JSON summary report
sub create_summary_report {
    my ($file, $results, $params, $elapsed) = @_;
    
    my $summary = {
        timestamp => scalar(localtime),
        parameters => $params,
        execution_time => $elapsed,
        structures_generated => scalar(@$results),
        results => $results
    };
    
    open(my $fh, '>', $file) or die "Cannot create summary file: $!\n";
    print $fh encode_json($summary);
    close($fh);
    
    print "Created summary report: $file\n";
}

# Upload results to workspace
sub upload_results {
    my ($app, $ws, $work_dir, $output_dir, $output_path, $basename) = @_;
    
    # Create a folder for all results
    my $result_folder = "$work_dir/results";
    make_path($result_folder);
    
    # Copy PDB files
    system("cp -r $output_dir/* $result_folder/");
    
    # Copy summary file
    system("cp $work_dir/${basename}_summary.json $result_folder/");
    
    # Create archive for upload
    my $archive = "$work_dir/${basename}.tar.gz";
    system("tar -czf $archive -C $work_dir results");
    
    # Upload to workspace
    eval {
        $ws->save_file_to_file($archive, {}, "$output_path/${basename}.tar.gz");
        
        # Also upload individual PDB files for easy access
        opendir(my $dh, $output_dir);
        my @pdb_files = grep { /\.pdb$/ } readdir($dh);
        closedir($dh);
        
        foreach my $pdb (@pdb_files) {
            $ws->save_file_to_file("$output_dir/$pdb", {}, "$output_path/$pdb");
        }
        
        # Upload summary
        $ws->save_file_to_file("$result_folder/${basename}_summary.json", {}, 
                               "$output_path/${basename}_summary.json");
    };
    if ($@) {
        die "Error uploading results to workspace: $@\n";
    }
}

1;