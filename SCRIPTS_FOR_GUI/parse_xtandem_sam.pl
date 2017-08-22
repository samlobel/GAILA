#!c:/perl/bin/perl.exe
#
use strict;
use File::Basename;
use experimental 'smartmatch';

my $error=0;
my $xmlfile=0;
my $xmldir=0;
my $threshold=0;
my $proton_mass=1.007276;
my $label_mass_int=0;
my $genefile=0;

my $unacceptable_mass_array_string="";
my $unacceptable_mod_array_string="";
my $unacceptable_label_mod_string="";

my @unacceptable_mass_array=();
my @unacceptable_mod_array=();
my @unacceptable_label_mod_array=();

if (defined $ARGV[0]) { $xmlfile=$ARGV[0];} else { exit 1; }
if (defined $ARGV[1]) { $xmldir=$ARGV[1];} else { exit 2; }
if (defined $ARGV[2]) { $threshold=$ARGV[2];} else { exit 3; }
if (defined $ARGV[3]) { $label_mass_int=$ARGV[3];} else { exit 4; }
if (defined $ARGV[4]) { $genefile=$ARGV[4];} else { exit 5; }
if (defined $ARGV[5]) { $unacceptable_mass_array_string=$ARGV[5];} else { exit 6; }
if (defined $ARGV[6]) { $unacceptable_mod_array_string=$ARGV[6];} else { exit 7; }
if (defined $ARGV[7]) { $unacceptable_label_mod_string=$ARGV[7];} else { exit 8; }


@unacceptable_mass_array=split /,/,$unacceptable_mass_array_string;
@unacceptable_mod_array=split /,/,$unacceptable_mod_array_string;
@unacceptable_label_mod_array=split /,/,$unacceptable_mod_array_string;

my $length_of_unacceptable_mass=scalar @unacceptable_mass_array;
my $length_of_unacceptable_mod=scalar @unacceptable_mod_array;

unless ($length_of_unacceptable_mass == $length_of_unacceptable_mod)
{
	print "The two unacceptable mass and unacceptable mod arrays should have equal value, instead they have value $length_of_unacceptable_mass and $length_of_unacceptable_mod , respectively";
	exit 9;
}

if ($error==0)
{
	my $short_filename = basename($xmlfile);
	print "Processing: $short_filename\n";
	my $line="";
	my %genes=();
	my %gene_ids=();
	my %protein_descriptions=();
	if (open (IN,qq!$genefile!))
	{
		my $no_newline="";
		while($line=<IN>)
		{
			chomp($line);
			if ($line=~/^([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$/)
			{
			$genes{$1}=$4;
			$gene_ids{$1}=$3;
			$no_newline=$5;
			$no_newline=~s/(\n|\r)//; #because chomp doesn't delete it on mac.
			$protein_descriptions{$1}=$no_newline;
			}
		}
		close(IN);
	}
	else
	{
		exit 10;
	}
	open (IN,qq!$xmlfile!) || die "Could not open $xmlfile\n";
	open (OUT,qq!>$xmlfile.txt!) || die "Could not open $xmlfile\n";
	print OUT qq!filename\tscan\tcharge\tpre\tpeptide\tpost\tmodifications\tstart\tpeptide expectation\tlabeling\tunique peptides\ttryptic\tmissed\tunacceptable modifications\tprotein log(e)\tprotein\tdescription\tgene\tgene_id\tother proteins\tother descriptions\tother genes\tother gene ids\tdifferent genes\n!;
	my $xmlfile_=$xmldir;

	my %filenames=();
	my $mh="";
	my $mz="";
	my $charge="";
	my $filename="";
	my $f_name_sans_mgf="";
	my @f_name_array_to_hold_stuff=();
	my $scan="";
	my $proteins="";
	my $start="";
	my $end="";
	my $expect="";
	my $pre="";
	my $post="";
	my $peptide="";
	my $first_peptide="";
	my @protein_array=();
	my %protein_dict;
	my %peptide_dict;
	my %new_peptide_dict;
	my $multi_peptides="N";
	my $title="";
	my $modifications="";
	my $tryptic="";
	my $missed="";
	my $unacceptable="N";
	my %protein_expect=();
	my $index_protein_start="";
	my $bioml_mgf="";
	my $bioml_mgf_sans_mgf="";

	while ($line=<IN>)
	{
		if ($line=~/^\<protein\s+.*expect="([^\"]+)"\s+.*label="([^\".\s]+).*"/)
		{
			my $protein_expect=$1;
			my $protein_name=$2;
			$protein_expect{$protein_name}=$protein_expect;
			if($protein_name!~/\:reversed$/) { $proteins.="#$protein_name#"; }
			#if the protein is not in the protein array, push it and the protein expect
			if ($protein_name !~~ @protein_array)
			{
				#print "pushing to protein array: " + $protein_name;
				push(@protein_array, $protein_name);
			}
				
			$start="";
			$end="";
			$expect=1;
			$pre="";
			$post="";
			$peptide="";
			$title="";
			$modifications="";
			$tryptic="";
			$missed="";
			$unacceptable="N";
		}

		#this line checks if the mgf was from a single file search
		if($line=~/<bioml xmlns:GAML=.*label=\"(.*mgf)'\">/)
		{
			$bioml_mgf=$1;
			$bioml_mgf=~s/^.*[\/\\]([^\/\\]+)$/$1/;
			@f_name_array_to_hold_stuff=split(".mgf",$bioml_mgf);
			$bioml_mgf_sans_mgf=$f_name_array_to_hold_stuff[0];
		}

		if ($line=~/\<domain\s+id="([0-9\.edED\+\-]+)".*start="([0-9]+)".*end="([0-9]+)".*expect="([0-9\.edED\+\-]+)".*mh="([0-9\.edED\+\-]+)".*delta="([0-9\.edED\+\-]+)".*pre="(.*)".*post="(.*)".*seq="([A-Z]+)".*missed_cleavages="([0-9]+)"/)
		{
			my $start_=$2;
			if (!$index_protein_start) { $index_protein_start=$start_; }
			my $end_=$3;
			my $expect_=$4;
			my $pre_=$7;
			my $post_=$8;
			my $peptide_=$9;
			if ($expect_<$expect)
			{
				$start=$start_;
				$end=$end_;
				$expect=$expect_;
				$pre=$pre_;
				$post=$post_;
				$peptide=$peptide_;
				$modifications="";
				$missed=0;
				my $temp=$peptide;

				if ($first_peptide eq "")
				{
					$first_peptide=$peptide;
				}

				if ($peptide ne $first_peptide)
				{
					$multi_peptides="Y";
				}

				while ($temp=~s/^[^KR]*[KR](.)/$1/)
				{
					my $aa=$1;
					if ($aa!~/P/) { $missed++; }
				}
				
				$tryptic="Y";
				
				if ($pre!~/[KR]$/)
				{
					if ($pre!~/\[M$/ and $pre!~/\[$/)
					{
						$tryptic="N";
					}
				}
				else
				{
					if ($peptide=~/^P/)
					{
						$tryptic="N";
					}
				}
				
				if ($peptide!~/[KR]$/)
				{
					if ($post!~/^\]/)
					{
						$tryptic="N";
					}
				}
				else
				{
					if ($post=~/^P/)
					{
						$tryptic="N";
					} 
				}
				
				$unacceptable="N";

				if ($line!~/\<domain[^\>]+\/\>/)
				{
					my $labeled_Y_Nterm=0;
					while ($line!~/\<\/domain\>/)
					{
						$line=<IN>;
						while($line=~s/^\s*\<aa\s+type=\"([A-Z])\"\s+at=\"([0-9]+)\"\s+modified=\"([0-9\.\-\+edED]+)\"\s*//)
						{
							my $mod_aa=$1;
							my $mod_pos=$2;
							my $mod_mass=$3;
							my $mod_pm="";
							my $mod_id="";
							if ($line=~s/^\s*pm=\"([A-Z])\"\s*id="([^\"]+)"\s*//)
							{
								$mod_pm=$1;
								$mod_id=$2;
							}
							$line=~s/^\s*\/\>\s*//;
							my $mod_pos_=$mod_pos-$start+1;

							$modifications.="$mod_mass\@$mod_aa$mod_pos_->$mod_pm,";

							my $current_unacc_mass="";
							my $current_unacc_mod="";
							for(my $mods=0;$mods<$length_of_unacceptable_mod;$mods++)
							{
								$current_unacc_mass=$unacceptable_mass_array[$mods];
								$current_unacc_mod=$unacceptable_mod_array[$mods];
								if ($mod_aa eq $current_unacc_mod and int((1*$current_unacc_mass) + 0.5)==int((1*$mod_mass) + 0.5))
								{
									$unacceptable="Y";
									last;
								}
							}
							unless ($unacceptable eq "Y")
							{
								my $bad_label="";
								foreach $bad_label (@unacceptable_label_mod_array)
								{
									if ($mod_aa eq $bad_label and $mod_pos_!=1 and int($mod_mass+0.5)==$label_mass_int)
									{
										$unacceptable="Y";
										last;
									}
									if ($mod_aa eq $bad_label and $mod_pos_==1)
									{
										if(int($mod_mass + 0.5)==$label_mass_int){$labeled_Y_Nterm+=1;}
										if(int($mod_mass + 0.5)==2*$label_mass_int){$labeled_Y_Nterm+=2;}
									}
								}
							}
						}
					}
					if ($labeled_Y_Nterm>1) { $unacceptable="Y"; } 
				}

				#If we're at the end of a peptide, save the unique peptide information in case a second matching sequence is found
				if (exists($peptide_dict{$peptide}))
				{
					#skip
				}
				else
				{
					#Set the key to the peptide and the value to a list of the things we need to make a new entry 
					#scalar protein array lets us keep track of what the index in the protein list is
					my $array_length = scalar @protein_array;
					my $array_index = $array_length - 1;
					my @peptide_details = ($start, $end, $expect, $pre, $post, $peptide, $modifications, $tryptic, $unacceptable, $array_index, $missed);
					$peptide_dict{$peptide} = \@peptide_details;
				}
			}
		}

		if($line=~/<note label=\"Description\">(.+?)<\/note>/)  
		{
			$title=$1;
			if($title=~/scans: (\S+)/)
			{
				$scan=$1;
				$scan=~s/,.*$//;
				$scan=~s/&quot;//g;
			}
			#this only appears in a multiple file mudpit style search
			if($title=~/source=(.*\.mgf)/)
			{
				$filename=$1;
				$filename=~s/^.*[\/\\]([^\/\\]+)$/$1/;
				@f_name_array_to_hold_stuff=split(".mgf",$filename);
				$f_name_sans_mgf=$f_name_array_to_hold_stuff[0];
			}
		}

		if($line=~/<GAML\:attribute type=\"M\+H\">(.*)<\/GAML\:attribute>/)
		{
			$mh=$1;   
		}

		if($line=~/<GAML:attribute type="charge">([0-9]+)<\/GAML:attribute>/)
		{
			$charge=$1;
			$mz=($mh+(($charge-1)*$proton_mass))/$charge; 
			if($expect<$threshold)
			{
				my $protein_="";
				my $protein_expect="";
				my $temp=$proteins;
				while($temp=~s/^#([^#]+)#//)
				{
					my $temp_=$1;
					if ($protein_expect{$temp_}<$protein_expect)
					{
						$protein_=$temp_;
						$protein_expect=$protein_expect{$temp_};
					}
				}
				my $protein_other="";
				my $other_genes="";
				my $other_gene_ids="";
				my $other_protein_descriptions="";
				my $different_genes="N";
				my $different_gene_fam="N";
				my $temp=$proteins;

				my %other_protein_dict_genes;
				my %other_protein_dict_gene_ids;
				my %other_protein_dict_descriptions;
				my %other_protein_dict;
				my %diff_gene_dict;

				#for each protein
				foreach my $current_protein (@protein_array)
				{
					my @nested_genes_list = ();
					my @nested_gene_ids_list = ();
					my @nested_protein_descriptions_list = ();
					my @nested_other_proteins = ();

					#go through all of the other proteins and get their info
					foreach my $nested_protein (@protein_array){
						#but skip the one we're currently on so that each is unique
						if ($nested_protein ne $current_protein){

							push (@nested_other_proteins, $nested_protein);

							if (!($genes{$nested_protein} ~~ @nested_genes_list))
							{
								my $result = $genes{$nested_protein};
								if ($result!~/\w/) { $result="NotFound"; }
								push(@nested_genes_list, $result);
							}

							if (!($gene_ids{$nested_protein} ~~ @nested_gene_ids_list))
							{
								my $result = $gene_ids{$nested_protein};
								if ($result!~/\w/) { $result="NotFound"; }
								push(@nested_gene_ids_list, $result);
							}

							if (!($protein_descriptions{$nested_protein} ~~ @nested_protein_descriptions_list))
							{
								my $result = $protein_descriptions{$nested_protein};
								if ($result!~/\w/) { $result="NotFound"; }
								push(@nested_protein_descriptions_list, $result);
							}
						}
					}

					my $other_gene_length = scalar @nested_genes_list;
					if ((!($genes{$current_protein} ~~ @nested_genes_list) && $other_gene_length > 0)|| $other_gene_length > 1){
						$different_genes = "Y";
					}

					$other_protein_dict_genes{$current_protein} = \@nested_genes_list;
					$other_protein_dict_gene_ids{$current_protein} = \@nested_gene_ids_list;
					$other_protein_dict_descriptions{$current_protein} = \@nested_protein_descriptions_list;
					$other_protein_dict{$current_protein} = \@nested_other_proteins;
					$diff_gene_dict{$current_protein} = $different_genes;
				}

				foreach my $key (keys %peptide_dict)
				{
					my %itraq_labels=();
					#$temp=$modifications;
					my $temp = $peptide_dict{$key}[6];
					my $modifications="";
					my $complete_labeling=0;	
					while($temp=~s/^([^\@]+)\@([A-Z])([0-9]+)\-?\>?([A-Z]?),//)
					{
						my $mod_mass=$1;
						my $mod_aa=$2;
						my $mod_res=$3;
						my $mod_pm=$4;
						$modifications.="$mod_mass\@$mod_aa$mod_res";
						if ($mod_pm=~/\w/){ $modifications.="->$mod_pm"; }
						$modifications.=",";
						if ($mod_pm=~/^K$/)
						{
							$complete_labeling++;
						}
						if ($mod_res==1 or $mod_aa=~/^K$/)
						{
							if (int($mod_mass)==$label_mass_int)
							{
								$itraq_labels{$mod_res}++;
							}
							if (int($mod_mass)==-$label_mass_int)
							{
								$itraq_labels{$mod_res}--;
							}
							if (int($mod_mass)==2*$label_mass_int)
							{
								$itraq_labels{$mod_res}+=2;
							}
						}
					}

					my $labeling=0;
					my $reactive_residue_count=0;
					#my $temp=$peptide;
					my $temp=$key;
					while($temp=~s/^([A-Z])//)
					{
						my $aa=$1;
						$reactive_residue_count++;
						if ($itraq_labels{$reactive_residue_count}>0)
						{
							$labeling+=$itraq_labels{$reactive_residue_count};
						}
						if ($reactive_residue_count==1)
						{
							$complete_labeling++;
						}
						if ($aa=~/^K$/)
						{
							$complete_labeling++;
						}
					}
					$labeling/=1.0*$complete_labeling;

					#($start, $end, $expect, $pre, $post, $peptide, $modifications, $tryptic, $unacceptable, ((scalar @protein_array)-1), $missed);
					#save this newly computed info back to the hash
					my $start_ = $peptide_dict{$key}[0];
					my $end_ = $peptide_dict{$key}[1];
					my $expect_ = $peptide_dict{$key}[2];
					my $pre_ = $peptide_dict{$key}[3];
					my $post_ = $peptide_dict{$key}[4];
					my $peptide_ = $peptide_dict{$key}[5];
					#[6] = modifications
					my $typtic_ = $peptide_dict{$key}[7];
					my $unacceptable_ = $peptide_dict{$key}[8];
					my $missed_ = $peptide_dict{$key}[10];

					#pull the protein expect index from the hash and grab the name and expect from the 2 arrays set up in the beginning
					my $protein_index = $peptide_dict{$key}[9];
					my $protein_name_ = $protein_array[$protein_index];
					my $protein_expect_ = $protein_expect{$protein_name_};

					$protein_other = join "," , @{$other_protein_dict{$protein_name_}};
					if ($protein_other!~/\w/) { $protein_other="N"; }

					$other_protein_descriptions = join ",",@{$other_protein_dict_descriptions{$protein_name_}};
					if ($other_protein_descriptions!~/\w/) { $other_protein_descriptions="None"; }

					$other_genes = join "," , @{$other_protein_dict_genes{$protein_name_}};
					if ($other_genes!~/\w/) { $other_genes="None"; }

					$other_gene_ids = join "," , @{$other_protein_dict_gene_ids{$protein_name_}};
					if ($other_gene_ids!~/\w/) { $other_gene_ids="None"; }

					$different_genes = $diff_gene_dict{$protein_name_};

					if ($modifications!~/\w/) { $modifications="N"; }

					#using protein_name_ so that each protein gets its own unique details
					my $gene=$genes{$protein_name_};
					if ($gene!~/\w/) { $gene="None - ".$protein_name_; }

					my $gene_id=$gene_ids{$protein_name_};
					if ($gene_id!~/\w/) { $gene_id="None - ".$protein_name_; }
					
					my $protein_description=$protein_descriptions{$protein_name_};
					if ($protein_description!~/\w/) { $protein_description="None"; }

					my @new_peptide_details = ($pre_, $peptide_, $post_, $modifications, $start_, $expect_, $labeling, $tryptic, $missed_, $unacceptable_, $protein_expect_, $protein_name_, $protein_description, $gene, $gene_id, $protein_other, $other_protein_descriptions, $other_genes, $other_gene_ids, $different_genes);

					$new_peptide_dict{$key} = \@new_peptide_details;
				}

				#this only happens if the mgf file is a single search and not from mudpit
				if ($filename eq "")
				{
					$filename=$bioml_mgf;
					$f_name_sans_mgf = $bioml_mgf_sans_mgf;
				}

				open (OUT_,qq!>>$xmlfile_/$f_name_sans_mgf.reporter!) || die "Could not open $xmlfile_/$filename.reporter\n";

				if ($filenames{$filename}!~/\w/)
				{
					$filenames{$filename}=1;
					print OUT_ qq!filename\tscan\tcharge\tunique peptides\tpre\tpeptide\tpost\tmodifications\tstart\tpeptide expectation\tlabeling\ttryptic\tmissed\tflagged modifications\tprotein log(e)\tprotein\tdescription\tgene\tgene_id\tother proteins\tother descriptions\tother genes\tother gene ids\tdifferent genes\n!;
				}

				my $number_unique_peptides = scalar keys %new_peptide_dict;
				foreach my $key (keys %new_peptide_dict)
				{
					my $pep_filename = $filename;
					my $pep_scan = $scan;
					my $pep_charge = $charge;
					my $pep_pre = $new_peptide_dict{$key}[0];
					my $pep_peptide = $new_peptide_dict{$key}[1];
					my $pep_post = $new_peptide_dict{$key}[2];
					my $pep_modifications = $new_peptide_dict{$key}[3];
					my $pep_start = $new_peptide_dict{$key}[4];
					my $pep_peptide_expectation = $new_peptide_dict{$key}[5];
					my $pep_labeling = $new_peptide_dict{$key}[6];
					my $pep_tryptic = $new_peptide_dict{$key}[7];
					my $pep_missed = $new_peptide_dict{$key}[8];
					my $pep_unacceptable_modifications = $new_peptide_dict{$key}[9];
					my $pep_protein_log_e = $new_peptide_dict{$key}[10];
					my $pep_protein = $new_peptide_dict{$key}[11];
					my $pep_description = $new_peptide_dict{$key}[12];
					my $pep_gene = $new_peptide_dict{$key}[13];
					my $pep_gene_id = $new_peptide_dict{$key}[14];
					my $pep_other_proteins = $new_peptide_dict{$key}[15];
					my $pep_other_descriptions = $new_peptide_dict{$key}[16];
					my $pep_other_genes = $new_peptide_dict{$key}[17];
					my $pep_other_gene_ids = $new_peptide_dict{$key}[18];
					my $pep_different_genes = $new_peptide_dict{$key}[19];
					
					print OUT qq!$pep_filename\t$pep_scan\t$pep_charge\t$number_unique_peptides\t$pep_pre\t$pep_peptide\t$pep_post\t$pep_modifications\t$pep_start\t$pep_peptide_expectation\t$pep_labeling\t$pep_tryptic\t$pep_missed\t$pep_unacceptable_modifications\t$pep_protein_log_e\t$pep_protein\t$pep_description\t$pep_gene\t$pep_gene_id\t$pep_other_proteins\t$pep_other_descriptions\t$pep_other_genes\t$pep_other_gene_ids\t$pep_different_genes\n!;
					print OUT_ qq!$pep_filename\t$pep_scan\t$pep_charge\t$number_unique_peptides\t$pep_pre\t$pep_peptide\t$pep_post\t$pep_modifications\t$pep_start\t$pep_peptide_expectation\t$pep_labeling\t$pep_tryptic\t$pep_missed\t$pep_unacceptable_modifications\t$pep_protein_log_e\t$pep_protein\t$pep_description\t$pep_gene\t$pep_gene_id\t$pep_other_proteins\t$pep_other_descriptions\t$pep_other_genes\t$pep_other_gene_ids\t$pep_different_genes\n!;
				}

				close(OUT_);
			}

			$mh="";
			$mz="";
			$filename="";
			$f_name_sans_mgf="";
			$charge="";
			$scan="";
			$proteins="";
			$start="";
			$end="";
			$expect="";
			$pre="";
			$post="";
			$peptide="";
			%peptide_dict=();
			%new_peptide_dict=();
			@protein_array=();
			$first_peptide="";
			$multi_peptides="N";
			$title="";
			$modifications="";
			$tryptic="";
			$missed="";
			$unacceptable="N";
			$index_protein_start="";
		}
	}
	close(IN);
	close(OUT);
	print "Processing Complete: $short_filename\n";
}