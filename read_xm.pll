#!/usr/bin/perl -w 
use lib "." ; 
use Carp; 
use ReadConfig; 
use Data::Dumper; 
use Getopt::Long ; 
use Linux::Inotify2; 
use triggers::rsync;
use File::Find; 

my $config_loc = "servsync_cfon.xml"; 
my $log_file_loc ; 
my $log_fh ; 
open $log_fh , ">>$log_file_loc" ; 
my $config = new ReadConfig("$config_loc") ; 

#$config->debug() ; 
my $xml_hash = $config->read_config; 
my $inotify_hash = {} ; 
sub create_inotify_objects; 
sub log_messages ; 
my $inotify_to_rsync_map = {} ; 
#$config->dump_ob; 
#print Dumper($xml_hash) ; 
create_inotify_objects($xml_hash , $inotify_hash) ; 
create_watches($xml_hash , $inotify_hash ) ; 
find_watch_points($inotify_hash) ; 
my $event_map = {} ; # to store current events and execute them after timeout  
#print Dumper($inotify_hash) ;
my $global_timer = {} ; 
my $max_global_time = 0 ; 
foreach my $event_ob ( keys %{$inotify_to_rsync_map} ) {
    $global_timer->{"$event_ob"} = $inotify_to_rsync_map->{"$inotify_ob"}->{"timeperiod"} if ( defined $inotify_to_rsync_map->{"$inotify_ob"}->{"timeperiod"} ) ;
    if ( $global_timer->{"$event_ob"} >= $max_global_time ) { 
        $max_global_time = $global_timer->{"$event_ob"} ; 
    }
}
my $global_time = 0 ; 
my $sync_time = 10 ; 
while () 
{
    execute_steps() ; 
    foreach my $job ( keys %{$inotify_hash} ) { 
        my @events = $inotify_hash->{"$job"}->{"inotify_ob"}->read ; 
    }
    sleep $sync_time ; 
    $global_time += $sync_time ; 
    foreach my $event_ob ( keys %{$inotify_to_rsync_map} ) { 

        my $event_time_period = $inotify_to_rsync_map->{"$event_ob"}->{"timeperiod"} ; 
        my $remender = $global_time %  $event_time_period ; 
        if ( ( $remender >= 0 ) && ( $remender < $sync_time ) ) { 
             print " \$global_time = $global_time \$event_time_period = $event_time_period \n" ; 
             my $rsync_ob = $inotify_to_rsync_map->{"$event_ob"}  ;
             $rsync_ob->run_rsync ; 
         }
     }
}
#print Dumper($inotify_hash) ; 
sub create_inotify_objects {  
    my $xml_hash = shift ; 
    my $inotify_hash = shift ; 
    # iterate through the xml through the different backup names 
    foreach my $backup_name ( keys %{$xml_hash->{"servsync"}}) { 
        $inotify_hash->{"$backup_name"} = {} if ( not defined $inotify_hash->{"$backup_name"} ) ; 
        if ( $inotify_hash->{"$backup_name"}->{"inotify_ob"}  = new Linux::Inotify2 ) { 
             
              $inotify_hash->{"$backup_name"}->{"inotify_ob"}->blocking("false") ; 
              log_messages( "INFO" , " inotify object created for $backup_name " ) ;
          } else { 
              log_messages( "SEVERE" , "$!" ) ;
              next ; # ERROR 
          }
       if ( $inotify_hash->{"$backup_name"}->{"rsync_ob"} = new triggers::rsync )  { 
              log_messages( "INFO" , " rsync object created for $backup_name " ) ;
              #print Dumper($xml_hash->{"servsync"}->{"$backup_name"}) ; 
              $inotify_hash->{"$backup_name"}->{"rsync_ob"}->setattribute( $xml_hash->{"servsync"}->{"$backup_name"} ) ; 

          } else {
              log_messages("SEVERE" , "$!" ) ; 
              next ; # ERROR 
          }
        my $rsync_ob = $inotify_hash->{"$backup_name"}->{"rsync_ob"} ; 
        my $inotify_ob = $inotify_hash->{"$backup_name"}->{"inotify_ob"} ; 
        $inotify_to_rsync_map->{"$inotify_ob"} = $rsync_ob ; 
        $inotify_to_rsync_map->{"$inotify_ob"}->{"timeperiod"} = $xml_hash->{"servsync"}->{"$backup_name"}->{"trigger"}->[0]->{"period"} if ( exists $xml_hash->{"servsync"}->{"$backup_name"}->{"trigger"}->[0]->{"period"} && ( $xml_hash->{"servsync"}->{"$backup_name"}->{"trigger"}->[0]->{"period"} > $sync_time ) ) ; # hard coded value 

    }
}

sub create_watches { 
    my $xml_hash = shift ; 
    my $inotify_hash = shift ;  
}

sub handle_kernel_event { 
    my $event_ob = shift ; 
    local $| = 1;
    # Got event of a particular function call a execute steps func 
    my $inotify_ob = $event_ob->{"w"}->{"inotify"} ; 
    #print Dumper($inotify_to_rsync_map) ;  
    #print Dumper($event_ob) ; 
    # Add events to push 
    push_steps("$inotify_ob") ; 
    #print "Event occured on : " , $event_ob->w ,  "\n"  ; 
   #print " Event name : " ,  $event_ob->name ; 
}

sub push_steps{ 
    my $inotify_ob = shift ; 
    $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} = 0 if ( not defined $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} ) ; 
    $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} = 1  if ( $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} == 0 ) ; 
}


sub execute_steps { 
    local $| = 1 ; 
    foreach my $inotify_ob ( keys %{$inotify_to_rsync_map} ) { 
        my $rsync_ob = $inotify_to_rsync_map->{"$inotify_ob"}  ;
        $rsync_ob->run_rsync if ( exists $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} && $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} == 1 ) ; 
        $inotify_to_rsync_map->{"$inotify_ob"}->{"run"} = 0 ; # reset it 
    }
}



sub find_watch_points {
    my $inotify_hash = shift ; 
    foreach my $backup_name ( keys %{$inotify_hash} ) { 
        our $rsync_ob =  $inotify_hash->{"$backup_name"}->{"rsync_ob"} ; 
        my $sub_ref = $rsync_ob->run_rsync();
        our $inotify_ob = $inotify_hash->{"$backup_name"}->{"inotify_ob"} ; 
        #print Dumper($sub_ref) ; 
        my $localpath = $rsync_ob->getlocalpath() ; 
        if ( -d "$localpath" ) { 
            print " $localpath is a directory : Will have to add watchers for each subdirecory \n" ; 
             find(\&add_watches , "$localpath") ; 
            #  find( \&test_cb("hi") , "$localpath") ; 
        } else { 
            $inotify_hash->{"$backup_name"}->{"inotify_ob"}->watch( $localpath , IN_MOVED_FROM|IN_MOVED_TO|IN_DELETE|IN_CREATE , \&handle_kernel_event ) 
        }
    }
}


sub test_cb {
    print "$File::Find::name \n "; 
}
sub add_watches { 
        my $file = $File::Find::name ; 
        return if ( -f $file ) ;  
        if ( $inotify_ob->watch( $file , IN_MOVED_FROM|IN_MOVED_TO|IN_DELETE|IN_CREATE , \&handle_kernel_event ) ) { 
            print "watch added for $file \n"; 
        }else {
            carp "watch on $file failed: $!" ; 
        }
    }
sub log_messages { 
    my $type = shift ; 
    my $msg = shift ;
    $log_fh = "STDOUT" if ( not defined $log_fh ) ; 
    print $log_fh  "$type: $msg \n "; 
}


