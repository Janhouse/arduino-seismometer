use Glib qw/TRUE FALSE/;
use Gtk2 '-init';

my $image = Gtk2::Image->new();

use Device::SerialPort;
my $port = Device::SerialPort->new("/dev/ttyACM0");
# 19200, 81N on the USB ftdi driver
$port->baudrate(9600);
$port->databits(8);
$port->parity("none");
$port->stopbits(1);

print "Go\n";
use SVG::TT::Graph::Line;

my @fields;
my @data_x;
my @data_y;
my @data_z;

for($i=0;$i<60;$i++){
    $fields[$i]=$i;
    $data_x[$i]=0;
    $data_y[$i]=0;
    $data_z[$i]=0;
}

my $graph = SVG::TT::Graph::Line->new({
    'fields' => \@fields,
    'height' => 500, 'width' => 200,
    'compress' => 0,
    'expand_greatest' => 1,
    'show_data_points'       => 1,
    'show_data_values'       => 0,
    'stacked'                => 0,

    'min_scale_value'        => '0',
    'area_fill'              => 0,
    'show_x_labels'          => 0,
    'stagger_x_labels'       => 0,
    'rotate_x_labels'        => 0,
    'show_y_labels'          => 0,
    'scale_integers'         => 0,
    'scale_divisions'        => '20',

    'show_x_title'           => 0,
    'x_title'                => 'Time',

    'show_y_title'           => 0,
    'y_title_text_direction' => 'bt',
    'y_title'                => 'Value',

    'show_graph_title'       => 0,
    'graph_title'            => 'Accelerometer readings',
    'show_graph_subtitle'    => 0,
    'graph_subtitle'         => 'ADXL345 3-axis accelerometer data readings',
    'key'                    => 1,
    'key_position'           => 'right',

    # Stylesheet defaults
    'style_sheet'             => 'graph.css', # internal stylesheet
    #~ 'random_colors'           => 0,
});

sub check_data{
    my ($port, $data_x, $data_y, $data_z)=@_;
    my $char=$port->lookfor();
    if ($char) {
        print "$char\n";
        #$port->lookclear;
        
        my @val = split(',', &trim($char));
        my $rv_x=&add_value($val[0], $data_x);
        my $rv_y=&add_value($val[1], $data_y);
        my $rv_z=&add_value($val[2], $data_z);

        #print "Values set: X - $rv_x; Y - $rv_y; Z - $rv_z\n";

    }else{
        &add_value('', $data_x);
        &add_value('', $data_y);
        &add_value('', $data_z);
        
        #print "No data...\n";
        
    }
    
}

sub add_value
{
    my ($value, $target)=@_;
    my $retval=1024;

    if($value =~ /^[+-]?\d+$/){
        my $positive = int($value)+1024;

    if($positive > 0){
        if($positive > 2048){
            push (@$target, 2048);
            $retval=2048;
        }else{
            push (@$target, $positive);
            $retval=$positive;
        }
    }else{
        push (@$target, 1024);
    }
    
    }else{
        push (@$target, 1024);
    }
    print "**** $value - $retval ****";
    
    shift @$target;
    return $retval;
}

 
sub draw_graph{
    my ($image, $port, $graph, $data_x, $data_y, $data_z)=@_;
    &check_data($port, $data_x, $data_y, $data_z);

    $graph->clear_data();

    $graph->add_data({
    'data'  => \@$data_x,
    'title' => 'X-axis',
    });

    $graph->add_data({
    'data' => \@$data_y,
    'title' => 'Y-axis',
    });

    $graph->add_data({
    'data' => \@$data_z,
    'title' => 'Z-axis',
    });

    my $pixbuf = do {
        my $loader = Gtk2::Gdk::PixbufLoader->new();
        $loader->write( $graph->burn );
        $loader->close();
        $loader->get_pixbuf();
    };

    $image->clear;
    $image->set_from_pixbuf($pixbuf);
    return $image;

}


sub trim()
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

my $window = Gtk2::Window->new('toplevel');
$window->resize(630, 330);
$window->signal_connect(destroy => sub { Gtk2->main_quit; });
#~ $window->set_border_width(10);

$image=&draw_graph($image, $port, $graph, \@data_x, \@data_y, \@data_z);

$window->add($image);
$image->show;
$window->show;

use IO::Async::Timer::Periodic;

use IO::Async::Loop::Glib;
my $loop = IO::Async::Loop::Glib->new();

 my $timer = IO::Async::Timer::Periodic->new(
    interval => 0.3,
    on_tick => sub {
        #print "You've had a minute\n";

        $image=&draw_graph($image, $port, $graph, \@data_x, \@data_y, \@data_z);
    },
 );

$timer->start;
$loop->add($timer);
$loop->loop_forever;
0;
