package PresentingPerl::Web::View::Zoom::Root;
use Moose;

use Data::Dumper;
use HTML::Zoom::FilterBuilder::Template;

sub wrap {
  my ($self, $zoom, $stash) = @_;

  my @body;
  
  $zoom->select('#main-content')->collect_content({into => \@body})->run;
  
  my $layout_zoom = HTML::Zoom->from_file($stash->{wrapper_template});
  # This does *not* modify $layout_zoom, but rather returns the modified version!
  return $layout_zoom->select('#main-content')->replace_content(\@body);
}

sub front_page {
  my ($self, $stash) = @_;
  
  my $zoom = $_;
  
  if (!$ENV{TEST_NO_DB}) {
    my $dt_formatter = sub {
        my ($dt) = @_;
        return '' unless blessed($dt) and $dt->isa('DateTime');
        return $dt->ymd('-');
    };
    my $announcements = $stash->{announcements};
    my $ann_list = [ map { 
      my $obj = $_; 
      sub {
        $_->select('.bucket-name')->replace_content($obj->bucket->name)
          ->select('.made-at')->replace_content( $dt_formatter->($obj->made_at) )
            ->select('.bucket-link')->set_attribute(
                                                    'href' => $obj->bucket->slug.'/'
                                                   )
              #               ->select('.new-videos')->replace_content($obj->video_count)
              ->select('.total-videos')->replace_content(
                                                         $obj->bucket->video_count
	      );

            }
    } $announcements->all ];
    
    $zoom = $zoom->select('#announcement-list')->repeat_content($ann_list);
  }
  
  $self->wrap($zoom, $stash);
}


sub bucket {
    my ($self, $stash) = @_;

    my $bucket = $stash->{bucket};
    my $zoom = $_;
    
    my $videos = [ map {
        my $video = $_;
        sub {
            $_->select('.video-name')->replace_content($video->name)
              ->select('.video-author')->replace_content($video->author)
              ->select('.video-link')->set_attribute(
                  href => $video->slug.'/'
                )
        }
                   } $bucket->videos->all ];


    $zoom = $zoom->select('.bucket-name')->replace_content($bucket->name)
        ->select('#video-list')->repeat_content($videos);

    $self->wrap($zoom, $stash);

}

sub video {
    my ($self, $stash) = @_;

    my $video_url = $stash->{video_file};
    my $video = $stash->{video};

    my $zoom = $_;

    # FIXME: I don't have a $c, so what should I be calling ->path_to on?
    ## Also, mr ugly code: the 1st c_z line works for the local script template
    ## the 2nd line works for the youtube iframe template
    ## they seem to happily no-op on the "wrong" ones.. !
    my $container_zoom = HTML::Zoom->from_file(PresentingPerl::Web->path_to('root/'.$stash->{video_type}));
    $container_zoom = $container_zoom->select('*')->template_text_raw( { video_file => $video_url } );
    $container_zoom = $container_zoom->select('iframe')->set_attribute( src => $video_url );
    print STDERR "Video file: $video_url\n";
#    print STDERR "CZ: ", $container_zoom->to_html, "\n";


    $zoom = $zoom->select('.video-name')->replace_content($video->name)
      ->select('.author-name')->replace_content($video->author)
      ->select('.bucket-link')->set_attribute(
          href => '../'
        )
      ->select('.bucket-name')->replace_content($video->bucket->name)
      ->select('.video-details')->replace_content($video->details)
      ->select('.videocontainer')->template_text_raw({ container => $container_zoom->to_html });
									

#      ->select('script')->template_text_raw({ video_url => $video_url });

    $self->wrap($zoom, $stash);
    
}

1;
