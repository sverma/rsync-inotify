package ReadConfig; 
use strict ; 

use IO::Handle;
use XML::Simple qw(:strict) ; 
use Data::Dumper ; 
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter) ; 

sub new { 
    my $class = shift ; 
    my $self = {
        '_config_loc' => shift , 
        '_xml_ob' => XML::Simple->new(ForceArray => 1 , KeyAttr => { 'servsync' => 'name' } ) , 
    }; 
    bless $self , $class ; 
    return $self ; 
}
sub debug { 
    my $self = shift ; 
    $self->{"debug"} = "true" ; 
}
sub read_config { 
    my $self = shift ;
    $self->dump_ob() if ( exists $self->{"debug"} ) ; 
    my $ref = $self->{"_xml_ob"}->XMLin($self->{"_config_loc"}) ;
    return $ref ; 
}
sub dump_ob { 
    my $self = shift ; 
    print Dumper($self) ; 
}


1; 
