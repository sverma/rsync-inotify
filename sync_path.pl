#!/usr/bin/perl -w 
use Carp; 
use Data::Dumper; 
use Getopt::Long ; 
use Linux::Inotify2; 
use File::Find; 
use File::Basename;
use POSIX qw(setsid) ;

my %o ; 
GetOptions (\%h, 'daemonize' , 'config_loc=s' , 'log_loc=s' , 'sleep_period=i' , 'help');
my ($config_loc , $log_loc , $app_root , $sync_time ) ; 
$config_loc = "/opt/rsync-inotify/servsync_conf.xml" ;
$log_loc = "/var/log/rsync-inotify/sync.log" ; 
$app_root = "/opt/rsync-inotify"  ; 

use constant APPROOT => "/opt/rsync-inotify" ; 
use lib "/opt/rsync-inotify"; 
use ReadConfig; 
use triggers::rsync;

$sync_time = 10; 

parse_options() ;  
sub parse_options { 
    if ( $h{"help"} ) { 
        help() ; 
    }
    if ( $h{"config_loc"} ) { 
        print "using $h{'config_loc'} as the configuration location \n" ; 
        $config_loc = $h{"config_loc"} ; 
    } else { 
        print " using $config_loc as configuration location \n " ; 
    } 
    if ( $h{"log_loc"} )  { 
        print "using $h{'log_loc'} as the logging file \n" ; 
        $log_loc = $h{'log_loc'} ;  
    }else { 
        print " using $log_loc as the logging file \n" ; 
    }
    if ( $h{"sleep_period"} ) { 
        print " using $h{'sleep_period'}  as the sleep time , the deaemon will sleep for this period and check the change in the folder \n" ; 
        $sync_time = $h{'sleep_period'} ; 
    } else { 
        print " using $sync_time  as the sleep time , the deaemon will sleep for this period and check the change in the folder \n" ; 
    }
}

sub help { 
    print <<'EOT'; 
    Rsync script based on inotify , It syncs up local directories to multiple servers based on two time periods , sleep_period and trigger period . sleep period determines the time interval in which the script wakes up the check the monitored directory for any changes , if it gets any changes it issues a rsync command based on the configuration . trigger_period defines the global time period in which rsync runs irrespective of the changes in the monitored directory. 
    EXAMPLE CONFIGURATION : 
    <head>
         <servsync name="test_shared">
             <localpath watch='/u/shared-data/' exclude='access-logs,cache,check_avail_abuse,pgfoundationapi/logs'/>
              <remote ip='bigrock-in-2.myorderbox.com' name='test_shared' />
              <rsync options='-avz -u --delete -e ssh' user='root' />
              <trigger options="mail,rsync" period="20"/>
         </servsync>
    </head>
    
    You can have different servsync sections in a particular configuration depending on how many local directories you want to sync up with the remote rsync location . 
    Each servsync path can have multiple comma separated remote IPs/Hostname . Rsync will run every "period" in trigger parameter . 
    trigger parameter in moduable , so you can put up your module ( perl module ) to include things like mail , scp , jabber client , notification etc . By default it ships with only rsync. Next release might have mail module. 
    so every 10 secs  ( sleep_period ) scripts wakes up to check '/u/shared-data/' and if it finds any changes it sync it to bigrock-in-2.myorderbox.com::test_shared , here test_shared in a rsync module on the remote server . you need to define this on your remote servers in /etc/rsyncd.conf  , For example : 
    
    [test_shared]
    path= /u/shared-data/
    comment = test shared bigrock html contents
    ignore errors
    read only = no
    
    Irrespecive of changes , the script will rsync based on period attribute of trigger parameter . 
    It will issue the following command 
    /usr/bin/rsync -avz -u --delete -e ssh --exclude access-logs --exclude cache --exclude check_avail_abuse --exclude pgfoundationapi/logs /u/shared-data/ root@bigrock-in-2.myorderbox.com::test_shared
    
    Things to do in next draft: 
    
    A.) Support for async triggers based on epoll 
    B.) Mail trrigger , 
    C.) Better logging and debugging.
    D.) init startup and syslog scripts  
    
    How to run the script: 
    
    Things to be checked : 
    A.) Password less ssh to the remote servers 
    B.) User should have the permission on remote servers to accept updates or to the loging file you provied 
    C.) rsyncd.conf should be updated 

    Install the RPM rsync-inotify , rum the following command with the user you desire to rsync 
    perl sync_path.pl [--daemonize] [--config_loc] [--log_loc] [--sleep_period] [--help]
    
    --daemonize : Will daemonize the script 
    --config_loc : default location of the config file is /opt/rsync-inotify/servsync_conf.xml 
    --log_loc : defaults to /var/log/rsync-inotify/sync.log , verfiy that the user has write permission to log file 
    --slep_period: interval in which script wakes to check for the local directory changes 
    --help : print this help 
    
    CONTROLING THE DAEMON 
    A.) edit servsync_conf.xml with the proper entries 
    B.) /etc/init.d/rsync-inotify start|stop 
    
    CHECKING THE PROCESS 
    # pgrep -fl sync_path.pl 
    
    CHECKING THE STATUS 
    # tail -f /var/log/rsync-inotify/sync.log
EOT
exit(0); 
}

        
if ( $h{"daemonize"} ) {
     my $log_file = $log_loc ; 
# Fork off a process  
     my $pid = fork() ; 
     die "couldn't create a child process : $!" if ( $pid < 0 ) ; 
     if ( $pid > 0 ) { 
# parent processs exit 
       exit () ;
     } 
     print " Daemon now goes in background with process id : $$ \n log File : $log_file \n " ; 
     setsid() ; 
     chdir ("/") ; 
     umask("0") ; 
     $| = 1;
     my $log_dir = dirname($log_file) ; 
     if ( ! -d $log_dir ) { 
        print STDOUT "$log_dir doesn't exist , creating it \n" ; 
        system ("mkdir -p $log_dir") ; 
     } 
     open STDIN , "/dev/null" or die " Can't open /dev/null for reading : $! " ; 
     open STDOUT , ">>$log_file" or die "Can't open $log_file for writing : $! " ; 
     open STDERR , ">>$log_file"  or die "Can't open $log_file for writing : $! " ; 
}
my $config = new ReadConfig("$config_loc") ; 

#$config->debug() ; 
my $xml_hash = $config->read_config; 
my $inotify_hash = {} ; 
sub create_inotify_objects; 
sub log_messages ; 
my $inotify_to_rsync_map = {} ; 
#$config->dump_ob; 
create_inotify_objects($xml_hash , $inotify_hash) ; 
create_watches($xml_hash , $inotify_hash ) ; 
find_watch_points($inotify_hash) ; 
my $event_map = {} ; # to store current events and execute them after timeout  
my $global_timer = {} ; 
my $max_global_time = 0 ; 
foreach my $event_ob ( keys %{$inotify_to_rsync_map} ) {
    $global_timer->{"$event_ob"} = $inotify_to_rsync_map->{"$inotify_ob"}->{"timeperiod"} if ( defined $inotify_to_rsync_map->{"$inotify_ob"}->{"timeperiod"} ) ;
    if ( $global_timer->{"$event_ob"} >= $max_global_time ) { 
        $max_global_time = $global_timer->{"$event_ob"} ; 
    }
}
my $global_time = 0 ; 
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
    push_steps("$inotify_ob") ; 
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
    print "$type: $msg \n "; 
}
