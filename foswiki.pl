

use Carp;
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

 my @webs = (
 '/var/lib/foswiki/data/Main', 
 '/var/lib/foswiki/data/System', 
 '/var/lib/foswiki/data/Sandbox');
 
 use AnyData;
 
 my $web = adTie( 'Foswiki', \@webs );
 while (my $topic = each %$web){
    print $topic->{web}.' , '.$topic->{name}.' ('.$topic->{author}.') => '.$topic->{formname}."\n";
 }
 
 
 use DBI;
 my $dbh = DBI->connect('dbi:AnyData:');
 $dbh->func('topics','Foswiki',\@webs,'ad_catalog');
 my $topics = $dbh->selectall_arrayref( qq{
     SELECT web, name, author, formname, parent FROM topics WHERE parent IS NULL
 });
 
print "---- no parent\n";
foreach my $topic (@$topics) {
  print join(', ', @$topic)."\n";
}
