package Medac::Misc::TV::Series;

use Moose;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Cookies;
use Data::Dumper;
use Text::Levenshtein;

my $ua_string = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4";
my $cookie_jar = HTTP::Cookies->new(); 
my $mech = WWW::Mechanize->new();

my $home_url = 'http://www.tv.com';

my $search_cache = {};
my $show_cache = {};


sub get {
  my $self = shift;
  my $result = shift;

  my $show_info = {
    'title' => '[missing]',
    'score' => '[missing]',
    'image' => '[missing]',
    'synopsis' => '[missing]'
  };
  
  if (defined $result->{url}) {
    if (defined $show_cache->{$result->{url}}) {
      $show_info = $show_cache->{$result->{url}};
    } else {
      $mech->get($home_url . $result->{url});
      die unless ($mech->success);
      my $content = $mech->{content};
      my $details_scraper = scraper {
	process '.show_head h1', 'title' => 'TEXT';
	process 'div.score', 'score' => 'TEXT';
	process '.image_box img', 'image' => '@src';
	process '.description span._more_less', 'synopsis' => 'TEXT';
	process 'form._rate_it input[name=targetid]', 'tv_dot_com_id' => '@value';
      };
	  
      my $results = $details_scraper->scrape($content);
      
      my $synopsis = $results->{synopsis};
      $synopsis =~ s/moreless\s*$//gi;
      
      $show_info->{title} = $results->{title} || '[missing]';
      $show_info->{score} = $results->{score} || '[missing]';
      $show_info->{image} = $results->{image} || '[missing]';
      $show_info->{tv_dot_com_id} = $results->{tv_dot_com_id} || '[missing]';
      $show_info->{synopsis} = $synopsis || '[missing]';
      $show_cache->{$result->{url}} = $show_info;
    } 
  }
  
  
  return $show_info;
}


sub search {
  my $self = shift;
  my $title = shift;

  my @s_results;
  
  if (defined $search_cache->{$title}) {
    @s_results = $search_cache->{title};
  } else {
  
    $mech->get($home_url);
    $mech->submit_form(
      form_id => 'site-search',
      fields      => {
	'q' => $title
      },
    );
    die unless ($mech->success);
    
    my $content = $mech->{content};
    
    my $no_results_search_scraper = scraper {
      process 'h1.no_results_header', 'no_results' => 'TEXT';
    };
    
    my $res = $no_results_search_scraper->scrape($content);
    
    
    if (defined $res->{no_results} && $res->{no_results} =~ m/did\s+not\s+return/gi) {
      
    } else {
      my $result_scraper = scraper {
	process 'ul.results li.show', 'shows[]' => scraper {
	  process 'a._image_container img', 'thumb_url' , => '@src';
	  process 'div.info h4 a', 'title' => 'TEXT',
	  process 'div.info h4 a', 'url' => '@href'
	};
      };
      
      $res = $result_scraper->scrape($content);
  
      for my $result (@{$res->{shows}}) {
	if (defined $result->{title}) {
	  push @s_results, $result;
	}
      }
    }
    $search_cache->{$title} = @s_results;
  }
  
  return \@s_results;
} # search()


no Moose;
__PACKAGE__->meta->make_immutable;


1;