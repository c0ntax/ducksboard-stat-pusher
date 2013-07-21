ducksboard-stat-pusher
======================

A simple script to push arbitrary stats into Ducksboard

Required CPAN Modules
=====================

Getopt::Long
File::Touch
Config::Any
LWP::UserAgent
JSON::XS

Required git repos
==================

https://github.com/c0ntax/office-hacks-helpers

Install
=======

```bash
git clone https://github.com/c0ntax/office-hacks-helpers.git

perl -MCPAN -e 'install DBI'
perl -MCPAN -e 'install DBD::Mysql'

git clone https://github.com/c0ntax/ducksboard-stat-pusher.git

perl -MCPAN -e 'install Getopt::Long'
perl -MCPAN -e 'install File::Touch'
perl -MCPAN -e 'install Config::Any'
perl -MCPAN -e 'install LWP::UserAgent'
perl -MCPAN -e 'install JSON::XS'

cd ducksboard-stat-pusher/conf
cp stats.xml.dist stats.xml
vi stats.xml # Now edit that stats file
```

Config file
===========

Below is the config sections explained

```xml
    <ducksboard>
        <key>...</key>
    </ducksboard>
```

The API key supplied by Ducksbaord. *Mandatory*

```xml
    <paths>
        <memory>../data/memory</memory>
    </paths>
```

When files are written to record what's been sent, this is where it'll be written to (local to the exec)

```xml
        <database id="databaseId1">
            <type>mysql</type>
            <host>localhost</host>
            <port>3306</port>
            <name>databasename</name>
            <user>username</user>
            <password>password</password>
        </database>
```

You can specify more that one database that can be used to pull your stats from. The id that's specified is reference in the stat using the 'database-id'. Currently only mysql is supported.

```xml
        <stat id="ducksboardWidgetId1">
            <!-- The name must be unique -->
            <name>The name of the stat</name>
            <type>database</type>
            <!-- references database id in sources -->
            <database-id>databaseId1</database-id>
            <!-- Run the stat once a day or every time -->
            <schedule>instant|daily</schedule>
            <!-- See http://dev.ducksboard.com/apidoc/slot-kinds/ -->
            <slot-kind>counter|gauge|graph|bar|box|pin|image|status|text|timeline|leaderboard|funnel|completion</slot-kind>
            <!-- Database query *must use value/timestamp column names -->
            <query>select count(*) as value from tmp</query>
        </stat>
```

The stat id references the id given by ducksboard for a specific stat.

Usage
=====

```bash
perl ducksboard-stat-pusher.pl -v
```
