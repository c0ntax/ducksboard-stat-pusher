#!/usr/bin/perl -w

$| = 1;

BEGIN {
    use File::Basename;
    push(@INC, dirname(__FILE__) . '/../../office-hacks-helpers/lib');
    push(@INC, dirname(__FILE__) . '/../lib');
}


use strict;
use Getopt::Long;
use OfficeHacksHelpers::Utils;
use Config::Any;
use Data::Dumper;

my $verbose = 0;
my $pushId = undef;
my $delete = 0;
my $configFile = undef;

GetOptions(
    'verbose|v' =>              \$verbose,
    'push-id|i=i' =>			\$pushId,
    'delete|d' =>               \$delete,
    'config|c=s' =>             \$configFile
);

my $util = new OfficeHacksHelpers::Utils('verbose' => $verbose);

# First up, load in the config file. We can't do anything with out it
if (!defined($configFile)) {
    $configFile = $util->getExecScriptPath() . '/../conf/stats.xml';
}
if (!-e $configFile) {
    die("Cannot find config file [" . $configFile . "]");
}

my $rConfig = undef;
for (@{Config::Any->load_files({ files => [$configFile], use_ext => 1 })}) {
    my ($filename, $tmpConfig) = %$_;
    $rConfig = $tmpConfig;
    next;
}

my $rDatabases = getDatabasesFromConfig($rConfig);
#my $rStats = getStatsFromConfig($rConfig);
print Dumper($rConfig);
print Dumper($rDatabases);
#print Dumper($rStats);


exit();

sub getDatabasesFromConfig {
    my ($rConfig) = @_;
    my $rOut;
    if (defined($rConfig->{sources}->{database})) {
        if (defined($rConfig->{sources}->{database}->{id})) {
            # Only one database to parse
            return getDatabaseFromConfig($rConfig->{sources}->{database});
        } else {
            foreach my $databaseConfigKey (keys(%{$rConfig->{sources}->{database}})) {
                my $tmp = getDatabaseFromConfig($rConfig->{sources}->{database}->{$databaseConfigKey});
                while (my ($key, $rValue) = each(%$tmp)) {
                    $rOut->{$key} = $rValue;
                }
            }
        }
    }

    return $rOut;
}

sub getDatabaseFromConfig {
    my ($rConfig) = @_;
    my $rOut;
    $rOut->{$rConfig->{id}} = $rConfig;
    return $rOut;
}