# This might look like shell script, but it's actually -*- perl -*-
use strict;
use lib qw(t/ t/m/);

use File::Slurp;
use Test::More qw(no_plan);

use TestUtils;
use HTML::TreeBuilder;
use HTML::Element::Library;

my $root = 't/html/dual_iter';

my $tree = HTML::TreeBuilder->new_from_file("$root.html");

my $dl = $tree->look_down(id => 'service_plan');


my @items = 
  ('the pros' => 'never have to worry about service again',
   'the cons' => 'upfront extra charge on purchase',
   'our choice' => 'go with the extended service plan');


$tree->iter($dl, @items);

  my $generated_html = ptree($tree, "$root.gen");

  is ($generated_html, File::Slurp::read_file("$root.exp"), 
      "HTML for generated li");
