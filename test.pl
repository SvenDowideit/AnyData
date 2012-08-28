#!/usr/local/bin/perl -w
use strict;
use AnyData;
print "\nUsing AnyData $AnyData::VERSION\n\n";
my @formats = qw(CSV Pipe Tab Fixed Paragraph ARRAY);

for my $format (@formats) {
    printf "  %10s ... %s\n", $format, test_ad($format);
}

sub test_ad {
    my $file   = [];
    my $format = shift;
    my $mode   = 'o';
    my $flags  = { cols => 'name,country,sex', pattern => 'A5 A8 A3' };
    my $table = adTie( $format, $file, $mode, $flags );    # create a table
    $table->{Sue} = { country => 'fr', sex => 'f' };       # insert rows
    $table->{Tom} = { country => 'fr', sex => 'f' };
    $table->{Bev} = { country => 'en', sex => 'f' };
    $table->{ { name => 'Tom' } } = { sex => 'm' };        # update a row
    delete $table->{Bev};                                  # delete a row
    $flags = { pattern => 'A5 A8 A3' };
    return "Failed single select"
      unless 'f' eq $table->{Sue}->{sex};    # select a single value
    my $tstr;

    while ( my $person = each %$table ) {    # select mulitple rows
        $tstr .= $person->{name} if $person->{country} eq 'fr';
    }
    return "Failed multiple select" unless 'SueTom' eq $tstr;
    return "Failed names" unless 'namecountrysex' eq join '', adNames($table);
    return "Failed rows" unless 2 == adRows($table);
    return 'ok';
}

__END__
