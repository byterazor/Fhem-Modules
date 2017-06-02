package main;

use strict;
use warnings;
use POSIX;
use Color;
use HTTP::Request::Common;
use LWP::UserAgent;
use File::Temp qw/ tempfile /;
use File::Find;

my $module_name="FireTVnotify";
my $VERSION    = '0.0.1';

sub FireTVnotify_Define;
sub FireTVnotify_Delete;
sub FireTVnotify_Set;

sub not_defined_yet
{
  my ($hash) = @_;
  Log3 undef, 3, "[$module_name] undefined function called";
}

sub get_icons {
  my $path=shift;
  my @files;

  my @entries=glob $path . "/*";
  for my $e (@entries)
  {
    if (-d $e)
    {
      push(@files, get_icons($e));
    }
    else
    {
      if ($e =~/.*\.(png|jpg)$/)
      {
        push(@files,$e);
      }
    }
  }

  return @files;
}

sub ShowNotify
{
  my ($hash) = @_;

  my $filename = $FW_icondir . "/" . $hash->{MSG_ICON};
  my $ua      = LWP::UserAgent->new();
  my $notify_data = [
    type          => $hash->{helper}->{MSG_TYPE},
    app           => $hash->{MSG_APP},
    title         => $hash->{MSG_TITLE},
    msg           => $hash->{MSG_MSG},
    duration      => $hash->{MSG_DURATION},
    position      => $hash->{helper}->{MSG_POSITION},
    bkgcolor      => $hash->{MSG_BKGCOLOR},
    transparency  => $hash->{MSG_TRANSPARENCY},
    offset        => $hash->{MSG_OFFSET},
    offsety       => $hash->{MSG_OFFSETy},
    force         => $hash->{MSG_FORCE},
    filename      => [$filename, "icon.png", Content_Type=>"application/octet-stream"]
  ];

  my $response = $ua->post( $hash->{helper}->{URL}, Content_Type => 'form-data', Content=>$notify_data );

  Log3 undef, 3, $response->request->as_string;
  Log3 undef, 3, $response->as_string;

  #readpipe("rm " . $filename);

  if ($response->is_success)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}


#
# FireTVnotify_Initialize
#
# initialize the FireTVnotify Module
#
sub FireTVnotify_Initialize
{
  my ($hash) = @_;

  $hash->{DefFn}      = 'FireTVnotify_Define';
  $hash->{UndefFn}    = 'FireTVnotify_Delete';
  $hash->{SetFn}      = 'FireTVnotify_Set';
  $hash->{GetFn}      = 'not_defined_yet';
  $hash->{AttrFn}     = 'not_defined_yet';
  $hash->{AttrList}   = $readingFnAttributes;

}

#
# FireTVnotify_Define
#
# called when a FireTVnotify instance is defined in FHEM
#
sub FireTVnotify_Define
{
  my ($hash, $def) = @_;
  my @param = split('[ \t]+', $def);
  my $name = $param[0];

  if(int(@param) < 3)
  {
    return "too few parameters: define <name> FireTVnotify <HOST>";
  }

  if(defined($param[2]) && $param[2]!~/^[a-z0-9-.]+(:\d{1,5})?$/i)
  {
        return "IP '".$param[2]."' is no valid ip address or hostname";
  }

  $hash->{NAME}           = $name;
  $hash->{IP}             = $param[2];
  $hash->{helper}->{URL}  = 'http://' . $hash->{IP} . ':7676/';
  $hash->{STATE}          = 'defined';
  $hash->{VERSION}        = $VERSION;
  $hash->{MSG_TYPE}       = "Normal";
  $hash->{helper}->{MSG_TYPE} = 0;
  $hash->{MSG_APP}        = $module_name;
  $hash->{MSG_TITLE}      = "FireTVnotify FHEM";
  $hash->{MSG_MSG}        = "FireTVnotify Instance defined";
  $hash->{MSG_DURATION}   = 9;
  $hash->{MSG_POSITION}   = "Bottom Right";
  $hash->{helper}->{MSG_POSITION}=0;
  $hash->{MSG_BKGCOLOR}   = '#607D8B';
  $hash->{MSG_TRANSPARENCY} = 0;
  $hash->{MSG_OFFSET}     = 0;
  $hash->{MSG_OFFSETy}    = 0;
  $hash->{MSG_FORCE}      = "true";
  $hash->{MSG_ICON}       = "openautomation/message_attention.svg";

  return;
}

#
# FireTVnotify_Delete
#
# called when a FireTVnotify instance is deleted in FHEM
#
sub FireTVnotify_Delete
{
  my ( $hash, $name) = @_;

  return;
}

#
# FireTVnotify_Set
#
# called when a value should be set on a FireTVnotify instace
#
sub FireTVnotify_Set
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $available="";

  if ($cmd eq "?")
  {
    $available .= "send:noArg ";
    $available .= "MSG_TYPE:Normal,Small ";
    $available .= "MSG_TITLE:textField ";
    $available .= "MSG_MSG:textField ";
    $available .= "MSG_OFFSET:textField ";
    $available .= "MSG_OFFSETY:textField ";
    $available .= "MSG_POSITION:Top_Left,Top_Right,Bottom_Left,Bottom_Right,Center ";
    $available .= "MSG_DURATION:slider,1,1,60 ";
    #$available .= "MSG_BKGCOLOR:colorpicker,RGB";              # not working on the FireTV App Side yet !

    $available .= "MSG_ICON:";
    my @icons = get_icons($FW_icondir);

    for my $i (@icons)
    {
      $i =~ s/$FW_icondir\///;
      $available .="$i,";
    }
    $available =~ s/,$//;
    $available .= " ";
  }

  return "Unknown argument $cmd, choose one of " . $available unless length($cmd)>3;


  # trigger notification
  if ($cmd eq "send")
  {
    ShowNotify($hash);
    return;
  }

  # set the background color, at the moment nothing happens
  if ($cmd eq "MSG_BKGCOLOR")
  {
    $hash->{MSG_BKGCOLOR}="#" . $args[0];
    return;
  }

  # set the title
  if ($cmd eq "MSG_TITLE")
  {
    $hash->{MSG_TITLE}=$args[0];
    return;
  }

  # set the message
  if ($cmd eq "MSG_MSG")
  {
    $hash->{MSG_MSG}=$args[0];
    return;
  }

  # set the X Offset
  if ($cmd eq "MSG_OFFSET")
  {
    $hash->{MSG_OFFSET}=$args[0];
    return;
  }

  # set the Y Offset
  if ($cmd eq "MSG_OFFSETY")
  {
    $hash->{MSG_OFFSETy}=$args[0];
    return;
  }

  # set the icon
  if ($cmd eq "MSG_ICON")
  {
    $hash->{MSG_ICON}=$args[0];
    return;
  }

  # set the background color, at the moment nothing happens
  if ($cmd eq "MSG_TYPE")
  {
    if (lc($args[0]) eq "normal")
    {
      $hash->{helper}->{MSG_TYPE}=0;
      $hash->{MSG_TYPE} = "Normal";
    }
    elsif (lc($args[0]) eq "small")
    {
      $hash->{helper}->{MSG_TYPE}=1;
      $hash->{MSG_TYPE} = "Small";
    }
    else
    {
      return "unknown type " . $args[0];
    }
    return;
  }

  #set notification box position
  if ($cmd eq "MSG_POSITION")
  {
    if (lc($args[0]) eq "top_left")
    {
      $hash->{helper}->{MSG_POSITION}=3;
      $hash->{MSG_POSITION} = "Top Left";
    }
    elsif (lc($args[0]) eq "top_right")
    {
      $hash->{helper}->{MSG_POSITION}=2;
      $hash->{MSG_POSITION} = "Top Right";
    }
    elsif (lc($args[0]) eq "bottom_left")
    {
      $hash->{helper}->{MSG_POSITION}=1;
      $hash->{MSG_POSITION} = "Bottom Left";
    }
    elsif (lc($args[0]) eq "bottom_right")
    {
      $hash->{helper}->{MSG_POSITION}=0;
      $hash->{MSG_POSITION} = "Bottom Right";
    }
    elsif (lc($args[0]) eq "center")
    {
      $hash->{helper}->{MSG_POSITION}=4;
      $hash->{MSG_POSITION} = "Center";
    }
    else
    {
      return "unknown position " . $args[0];
    }
    return;
  }


  Log3 undef, 3, $cmd . " " . $args[0];

  return;
}

1;

=pod
=begin html

<a name="FireTVnotify"></a>
<h3>FireTVnotify</h3>
<ul>
  <i>FireTVnotify</i> is used to transmit short notification messages to the <i>Notification for FireTV App</i>
  running on an Amazon FireTV device. It can not receive anything in return!
  <br><br>
    <b>Requirements</b>
    <ul>
        <li>Install Notification for FireTV App on your FireTV</li>
        <li>Install File::Find on your FHEM Server</li>
    </ul>
    <br><br>
    <a name="FireTVnotifydefine"></a>
    <b>Define</b><br>
    <code>define &lt;name&gt; FireTVnotify &lt;HOST&gt;</code>
    <br><br>
    Example: <code>define FTV0 FireTVnotify 192.168.14.1</code><br>
    <br>

    <a name="FireTVnotifyget"></a>
    <b>Get</b><br>
    Nothing to get because device does not receive anything!
    <br><br>

    <a name="FireTVnotifyset"></a>
    <b>Set</b><br>
    <ul>
        <li>
            <i>MSG_DURATION &lt;seconds&gt;</i><br>
            Set the duration a notification is displayed on the FireTV.
        </li>
        <li>
            <i>MSG_ICON &lt;IMAGE_PATH&gt;</i><br>
            Set icon for the notification. The path is relative to the FHEM ICON_DIR.
        </li>
        <li>
            <i>MSG_MSG &lt;text&gt;</i><br>
            Set the text which shall be displayed in the notification.
        </li>
        <li>
            <i>MSG_TITLE &lt;text&gt;</i><br>
            Set the title of the notification.
        </li>
        <li>
            <i>MSG_TYPE &lt;type&gt;</i><br>
            Set the notification type.
            <ul>
              <li>0 - Normal notification, Title + Message + Icon </li>
              <li>1 - Small notification, only Title + Icon</li>
            </ul>
        </li>
        <li>
            <i>MSG_POSITION &lt;position_nr&gt;</i><br>
            Set the position of the notification on the TV.
            <ul>
              <li>0 - Bottom Right </li>
              <li>1 - Bottom Left </li>
              <li>2 - Top Right</li>
              <li>3 - Top Left</li>
              <li>4 - Center</li>
            </ul>
        </li>
        <li>
            <i>send</i><br>
            Trigger display of the notification.
        </li>
    </ul>
  </ul>
=end html

=begin html_DE

<a name="FireTVnotify"></a>
<h3>FireTVnotify</h3>
<ul>
  <i>FireTVnotify</i> wird dazu benutzt kurze Benachrichtigungen an die APP <i>Notification for FireTV </i>
  zu senden, die auf einem Amazon FireTV läuft.
  <br><br>
    <b>Abhängigkeiten</b>
    <ul>
        <li>Installiere Notification for FireTV App auf Deinem FireTV</li>
        <li>Installiere File::Find auf Deinem FHEM Server</li>
    </ul>
    <br><br>
    <a name="FireTVnotifydefine"></a>
    <b>Define</b><br>
    <code>define &lt;name&gt; FireTVnotify &lt;HOST&gt;</code>
    <br><br>
    Beispiel: <code>define FTV0 FireTVnotify 192.168.14.1</code><br>
    <br>

    <a name="FireTVnotifyget"></a>
    <b>Get</b><br>
    Nichts zum Auslesen, da das Gerät nichts empfangen kann!
    <br><br>

    <a name="FireTVnotifyset"></a>
    <b>Set</b><br>
    <ul>
        <li>
            <i>MSG_DURATION &lt;Sekunden&gt;</i><br>
            Setzt die Anzeigedauer einer Benachrichtigung aug dem FireTV.
        </li>
        <li>
            <i>MSG_ICON &lt;IMAGE_PFAD&gt;</i><br>
            Setzt das Icon für eine Benachrichtigung. Der Pfad is relativ zum FHEM ICON_DIR.
        </li>
        <li>
            <i>MSG_MSG &lt;Text&gt;</i><br>
            Setzt den Banchrichtungstext.
        </li>
        <li>
            <i>MSG_TITLE &lt;Text&gt;</i><br>
            Setzt den Benachrichtungstitel.
        </li>
        <li>
            <i>MSG_TYPE &lt;Typ&gt;</i><br>
            Setzt den Typ der Benachrichtigung.
            <ul>
              <li>0 - Normale Benachrichtigung, Titel + Benachrichtungstext + Icon </li>
              <li>1 - Kleine Benachrichtigung, nur Titel + Icon</li>
            </ul>
        </li>
        <li>
            <i>MSG_POSITION &lt;position_nr&gt;</i><br>
            Setzt die Position der Benachrichtigung auf dem Fernseher.
            <ul>
              <li>0 - Rechts unten </li>
              <li>1 - Links unten </li>
              <li>2 - Rechts oben</li>
              <li>3 - Links oben</li>
              <li>4 - Mitte</li>
            </ul>
        </li>
        <li>
            <i>send</i><br>
            Löst das Anzeigen der Benachrichtigung aus.
        </li>
    </ul>
</ul>
=end html_DE
# Ende der Commandref
=cut
