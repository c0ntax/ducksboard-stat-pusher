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

my $rDatabases = getDataFromConfig('database', $rConfig);
my $rStats = getDataFromConfig('stat', $rConfig);
print Dumper($rConfig);
print Dumper($rDatabases);
print Dumper($rStats);


exit();

sub getDataFromConfig {
    my ($type, $rConfig) = @_;
    my $rOut;
    my $rConfigChunk = undef;
    if ($type eq 'database') {
        $rConfigChunk = $rConfig->{sources}->{database};
    } elsif ($type eq 'stat') {
        $rConfigChunk = $rConfig->{stats}->{stat};
    }

    if (defined($rConfigChunk)) {
        if (defined($rConfigChunk->{id})) {
            # Only one database to parse
            if ($type eq 'database') {
                return getDatabaseFromConfig($rConfigChunk);
            } elsif ($type eq 'stat') {
                return getDatabaseFromConfig($rConfigChunk);
            }
        } else {
            foreach my $databaseConfigKey (keys(%{$rConfigChunk})) {
                my $tmp = undef;
                if ($type eq 'database') {
                    $tmp = getStatFromConfig($rConfigChunk->{$databaseConfigKey});
                } elsif ($type eq 'stat') {
                    $tmp = getStatFromConfig($rConfigChunk->{$databaseConfigKey});
                }
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

sub getStatFromConfig {
    my ($rConfig) = @_;
    my $rOut;
    $rOut->{$rConfig->{id}} = $rConfig;
    return $rOut;
}