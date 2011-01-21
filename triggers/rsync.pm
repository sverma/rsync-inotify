package triggers::rsync;
use strict ; 
use Carp ; 
my $Debugging = 0 ; 


sub new { 
    my $self = shift ; 
    my $class = ref($self) || $self ; 
    my $ref = {} ; 
    bless $ref , $class ; 
    return $ref ;
}

sub setattribute { 
    my $self = shift ; 
    confess "usage thing->setattribute(\$hash_ref)" unless @_ == 1 ; 
    my $h = shift ; 
    $self->{"options"} = $h->{"rsync"}->[0]->{"options"} ; 
    $self->{"user"} = $h->{"rsync"}->[0]->{"user"} ; 
    $self->{"remote_module"} = $h->{"remote"}->[0]->{"name"} ; 
    $self->{"remote_ips"} = [ split /,/ , $h->{"remote"}->[0]->{"ip"} ]; 
    $self->{"local_path"} = $h->{"localpath"}->[0]->{"watch"} ;
    if ( $h->{"localpath"}->[0]->{"exclude"} ) { 
        $self->{"exclude"} = [ split /,/ , $h->{"localpath"}->[0]->{"exclude"} ];
    }
    return $self ; 
}

sub debug  { 
    my $self = shift ; 
    confess "usage thing->debug(level) " unless @_ == 1 ;
    my $level = shift ; 
    if ( ref ($self) ) { 
        $self->{"_DEBUG"} = $level ; 
    }else { 
        $Debugging = $level ; 
    }
}
sub run_rsync { 
    my $self = shift ;
    my $local_path = $self->{"local_path"}; 
    my $remote_module = $self->{"remote_module"}; 
    my $user = $self->{"user"} ; 
    my $options = $self->{"options"} ; 
    my $exclude_cmd = "" ; 
    if ( $self->{"exclude"} ) { 
        foreach my $dir ( @{$self->{"exclude"}} ) { 
            $exclude_cmd .= ' --exclude ' ;
            $exclude_cmd .= "\"$dir\"";
        }   
    }   
    foreach my $server (   @{$self->{"remote_ips"}} ) { 
            print  " Rsyncing from $local_path to ${user}\@${server}::$remote_module \n "; 
            system ( "/usr/bin/rsync $options $exclude_cmd $local_path ${user}\@${server}::$remote_module" );
            if ( $? != 0 ) { 
                print " FAILED: Rsync from $local_path to ${user}\@${server}::$remote_module \n "; 
            }
    }
}
sub getlocalpath { 
    my $self = shift ; 
    return ( $self->{"local_path"} ) ;
}


sub DESTORY { 
    my $self = shift ; 
    if ( $Debugging || $self->{"_DEBUG"} ) { 
        carp "DESTROYING SELF " , $self ; 
    }
}
1;
