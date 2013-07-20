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
use LWP::UserAgent;
use JSON::XS;

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
my $apiKey = $rConfig->{ducksboard}->{key};

# Fire up our database connections

while (my ($id, $rDatabase) = each(%$rDatabases)) {
    if ($rDatabase->{type} eq 'mysql') {
        my $dsn = 'DBI:mysql:database=' . $rDatabase->{name} . ';host=' . $rDatabase->{host} . ';port=' . $rDatabase->{port};
        $rDatabase->{dbh} = $util->dbConnect($dsn, $rDatabase->{user}, $rDatabase->{password});
    } else {
        die ('Cuurently unsupported database type: [' . $rDatabase->{type} . ']');
    }
}

# Now that we have the config, we can start to do the hard work

my $rStatsToProcess = undef;
if (defined($pushId)) {
    if (defined($rStats->{$pushId})) {
        $rStatsToProcess->{$pushId} = $rStats->{$pushId};
    } else {
        die('Unknown stat id [' . $pushId . ']');
    }
} else {
    $rStatsToProcess = $rStats;
}


	while (my ($key, $rJob) = each(%$rStatsToProcess)) {
		$util->vPrint('Processing ' . $key . ':' . $rJob->{name} . '...');
		if (&isTimeForJob($key, $rJob)) {
			if (&processJob($key, $rJob)) {
				$util->vPrint("Done\n");
			} else {
				$util->vPrint("Fail\n");
			}
		} else {
			$util->vPrint("Skipped\n");
		}
	}    

exit();

sub processJob {
    my ($key, $rJob) = @_;

    my %typeMap = (
        'counter' => 'intValue',
        'gauge' => 'percentValue',
        'graph' => 'timedValue',
        'bar' => 'intValue',
        'box' => 'intValue',
        'pin' => 'intValue',
        'image' => 'image',
        'status' => 'status',
        'text' => 'text',
        'timeline' => 'timeline',
        'leaderboard' => 'leaderboard',
        'funnel' => 'funnel',
        'completion' => 'completion'
    );

    my $jobType = undef;
    if (defined($typeMap{$rJob->{'slot-kind'}})) {
        $jobType = $typeMap{$rJob->{'slot-kind'}};
    } else {
        die ('Unknown slot kind ' . $rJob->{'slot-kind'});
    }

    my $data = undef;
    if ($jobType eq 'intValue') {
        $data = &processIntValue($key, $rJob);
    } else {
        die ('Slot kind of ' . $rJob->{'slot-kind'} . ' unsupported at this time');
    }

    if ($verbose) {
        if (!defined($data)) {
            print '[NULL]...';
            return 1;
        } elsif (ref($data) eq 'ARRAY') {
            my @values = ();
            foreach my $valueRef (@$data) {
                push(@values, $valueRef->{value});
            }

            print '[' . join(', ', @values) . ']...';
        } elsif (defined($data->{value})) {
            if (ref($data->{value}) eq '') {
                print '[' . $data->{value} . ']...';
            } elsif (ref($data->{value}) eq 'HASH' && $data->{value}->{board}) {
                my @lines = ();
                foreach my $stat (@{$data->{value}->{board}}) {
                    my $line = $stat->{name} . '/' . join(', ', @{$stat->{values}});
                    push(@lines, $line);
                }
                print '[' . join(' | ', @lines)  . ']...';
            }
        }
    }

	return &sendData($key, $data);
}

sub processIntValue {
    my ($key, $rJob) = @_;

	my %data;
	my $query = $rDatabases->{$rJob->{'database-id'}}->{dbh}->prepare($rJob->{query});
	$query->execute() || die("Cannot execute query [" . $rJob->{query} . ']');
	while (my $row = $query->fetchrow_hashref()) {
		$data{value} = $row->{value};
	}

	return \%data;
}

sub sendData {
	my ($key, $data) = @_;

	if (!defined($data)) {
	    # We don't send nulls!
	    return 0;
	}

	my $uri = 'https://push.ducksboard.com/v/' . $key;

	my $ua = LWP::UserAgent->new;
	$ua->credentials("push.ducksboard.com:443","Ducksboard push API",$apiKey=>'x');

	my $request = HTTP::Request->new( 'POST', $uri );
	$request->header( 'Content-Type' => 'application/json' );
	$request->content(encode_json($data));

	my $response = $ua->request($request);
	if ($response->is_success) {
		return 1;
	} else {
		return 0;
	}
}

sub isTimeForJob {
	my ($key, $rJob) = @_;

	if (!defined($rJob->{'schedule'}) || $rJob->{'schedule'} eq 'instant') {
		return 1;
	} elsif ($rJob->{'schedule'} eq 'daily') {
		my ($year, $month, $day) = (gmtime())[5,4,3];
		$year+=1900;
		$month++;
		my $path = $rConfig->{paths}->{memory} . '/daily-' . $key . '-' . sprintf('%04d-%02d-%02d', $year, $month, $day);
		if (-e $path) {
			return 0;
		} else {
			my $ft = new File::Touch();
        	$ft->touch($path);
        	return 1;
		}
	} else {
		die('Unknown schedule: ' . $rJob->{'schedule'});
	}
}

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
                return getStatFromConfig($rConfigChunk);
            }
        } else {
            foreach my $databaseConfigKey (keys(%{$rConfigChunk})) {
                my $tmp = undef;
                if ($type eq 'database') {
                    $rConfigChunk->{$databaseConfigKey}->{name} = $databaseConfigKey;
                    $tmp = getDatabaseFromConfig($rConfigChunk->{$databaseConfigKey});
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