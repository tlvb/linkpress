use warnings;
use strict;

my $compressor = 'lbzip2';
my $suffix = '.bz2';

sub scan_dir { #{{{
	my $root = shift;
	my $data = shift;

	opendir my $dh, $root or return;
	for my $entry (readdir $dh) {
		my $path = $root.'/'.$entry;
		if (-f $path and !-l $path) {
			next unless -r $path;
			next unless -w $path;
			my @props = stat $path;
			my $devno = $props[0];
			my $inode = $props[1];
			$data->{$devno} = {} unless exists $data->{$devno};
			$data->{$devno}->{$inode} = [] unless exists $data->{$devno}->{$inode};
			push @{$data->{$devno}->{$inode}}, $path;
		}
		elsif (-d $path and !-l $path) {
			next if $entry eq '.' or $entry eq '..';
			scan_dir($path, $data);
		}
	}
	closedir $dh;
} #}}}

my $pattern = shift @ARGV;
my $re = qr/$pattern/;

my $data = {}; # { deviceno => { inode => [ path, path, ... ], ... }, ... }

print "scanning directories...\n";
for (@ARGV) {
	scan_dir($_, $data);
}

print "compressing files...\n";
for my $devno (keys %{$data}) {
	my $groups = $data->{$devno};
	for my $inode (keys %{$groups}) {
		my @paths = @{$groups->{$inode}};
		next unless (grep(/$re/, @paths) >= 1);
		print "inode: $inode\n";

		my $kept = shift @paths;
		print "keeping\n\t$kept\n";

		if (@paths) {
			print "removing\n\t".join("\n\t", @paths)."\n";
			unlink @paths;
		}

		print "compressing\n\t$kept\n";
		system $compressor, $kept;

		print "linking\n\t$kept$suffix\n";
		for my $path (@paths) {
			print "\tto $path$suffix\n";
			system 'ln', $kept.$suffix, $path.$suffix;
		}
		print "---\n";
	}
}
