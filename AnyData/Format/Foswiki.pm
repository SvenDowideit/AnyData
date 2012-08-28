######################################################################
package AnyData::Format::Foswiki;
######################################################################
#
# copyright 2012 by Sven Dowideit <SvenDowideit@fosiki.com>
# all rights reserved
#
######################################################################

=head1 NAME

AnyData::Format::Foswiki - tied hash and DBI access to Foswiki topics (latest version only)

=head1 SYNOPSIS

 my @webs = (
 '/var/lib/foswiki/data/Main', 
 '/var/lib/foswiki/data/System', 
 '/var/lib/foswiki/data/Sandbox');
 
 use AnyData;
 
 my $web = adTie( 'Foswiki', \@webs );
 while (my $topic = each %$web){
    print $topic->{web}.' , '.$topic->{name}.' ('.$topic->{author}.') => '.$topic->{formname}."\n";
 }

 OR

 use DBI
 my $dbh = DBI->connect('dbi:AnyData:');
 $dbh->func('topics','Foswiki,['/var/lib/foswiki/data/Tasks'],'ad_catalog');
 my $topics = $dbh->selectall_arrayref( qq{
     SELECT name, author FROM topics WHERE date >= '23-Aug-2012'
 });
 # ... other DBI/SQL operations

=head1 DESCRIPTION

This module provides a tied hash interface and a DBI/SQL interface to Foswiki topic files.  It creates an in-memory database or hash from the topics themselves without actually creating a separate database file.  This means that the database is automatically updated just by moving files in or out of the directories.

Choose 'Foswiki' as the format and give a reference to an array of directories containing foswiki webs.  Each txt file in those directories will become a record containing the fields:

 name
 author
 date
 rev
 text
 formname

This module is used via the AnyData.pm and DBD::AnyData.pm modules.  Refer to their documentation for further details.

=head1 Future ideas

I suspect that the better way to implement this, is to make a AnyData::Format::FoswikiTopic that dynamically works out that topic's tml column names
and then to collate all the topic 'tables' into one FoswikiWeb table that contains all those columns.

that way we get huge flat table - the way that the foswiki query engine works.. (ie, users expect)

=head1 AUTHOR & COPYRIGHT

copyright 2012, Sven Dowideit L<mailto:SvenDowideit@fosiki.com>
all rights reserved

=cut

use strict;
use AnyData::Format::Base;
use AnyData::Storage::FileSys;
use AnyData::Storage::File;
use vars qw( @ISA $VERSION);
@AnyData::Format::Foswiki::ISA = qw( AnyData::Format::Base );

$VERSION = '0.01';
my @columns =
  qw/web name author date version parent text formname filename filesize/;

sub new {
    my $class = shift;
    my $self  = shift || {};
    my $dirs  = $self->{dirs} || $self->{file_name} || $self->{recs};
    $self->{col_names} = join( ',', @columns );

    #use Data::Dumper; die Dumper $self;
    $self->{recs} = $self->{records} = get_data($dirs);
    return bless $self, $class;
}

sub storage_type { 'RAM'; }

sub read_fields {
    my $self  = shift;
    my $thing = shift;
    return @$thing if ref $thing eq 'ARRAY';
    return split ',', $thing;
}

#can't make it writeable until this module is not lossy - perhaps I should include a raw column :()
sub write_fields { die "WRITING NOT IMPLEMENTED FOR FORMAT Foswiki"; }

sub get_data {
    my $dirs  = shift;
    my $table = [];

    my @files = AnyData::Storage::FileSys::get_filename_parts(
        {},
        part => 'ext',
        re   => 'txt',
        dirs => $dirs
    );
    for my $file_info (@files) {
        my $file = $file_info->[0];
        my $cols = load_foswiki_topic($file) || next;
        push @$table, $cols;
    }
    return $table;
}

sub load_foswiki_topic {
    my ($file) = shift;
    my $adf = AnyData::Storage::File->new;
    my ( undef, $fh, undef ) = $adf->open_local_file( $file, 'r' );
    local undef $/;
    my $complete_file = <$fh> || '';
    $fh->close;

    my @str = split( /\n/, $complete_file );

    my %meta;
    @meta{@columns} = '';    #I think the columns all need to be there :/
    my $filesize = -s $file;
    $meta{filesize} = sprintf "%1.fmb", $filesize / 1000000;
    $meta{file} = $file;
    $file =~ /.*data\/(.*?)\/(.*?).txt/;
    $meta{web}  = $1;
    $meta{name} = $2;

    # first get rid of the leading META
    if ( $str[0] =~ /\%META:TOPICINFO{(.*?)}\%$/ ) {
        my $params = $1;
        parse_params( 'TOPICINFO', $1, \%meta, qw/author date version format/ );
        $meta{rev} =
          $meta{version};    #legacy to match up with foswiki query syntax
        shift(@str);
    }
    if ( $str[0] =~ /\%META:TOPICPARENT{(.*?)}\%$/ ) {
        my $params = $1;
        my %temp;
        parse_params( 'TOPICPARENT', $1, \%temp, qw/name/ );
        $meta{parent} = $temp{name};
        shift(@str);
    }

    #then the trailing META
    while ( $str[$#str] =~ /\%META:(.*?){(.*?)}\%$/ ) {
        my $params = $2;
        if ( $1 eq 'FORM' ) {

            #TODO: this should be the top META - there are order restrictions...
            my %temp;
            parse_params( 'FORM', $params, \%temp, qw/name/ );
            $meta{formname} = $temp{name};
        }
        else {
            my %temp;
            parse_params( $1, $params, \%temp, qw/name/ );
        }
        pop(@str);
    }

    #and thus we're left with the topic text
    $meta{text} = join( "\n", @str );

    my @cols = @meta{@columns};
    return \@cols;
}

sub parse_params {
    my ( $metaname, $str, $meta, @attrs ) = @_;
    my $args = _readKeyValues($str);
    map { $meta->{$_} = $args->{$_} if ( exists( $args->{$_} ) ); } @attrs;
}

#from Foswiki::Meta
# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of Foswiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my ($args) = @_;
    my %res;

    # Format of data is name='value' name1='value1' [...]
    $args =~ s/\s*([^=]+)="([^"]*)"/
      $res{$1} = dataDecode( $2 ), ''/ge;

    return \%res;
}

=begin TML

---++ StaticMethod dataDecode( $encoded ) -> $decoded

Decode escapes in a string that was encoded using dataEncode

The encoding has to be exported because Foswiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

1;
