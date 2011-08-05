
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Convenience methods for HTML::TreeBuilder and HTML::Element',
  'AUTHOR' => 'Terrence Brannon <metaperl@gmail.com>',
  'BUILD_REQUIRES' => {
    'Cwd' => '0',
    'Exporter' => '0',
    'File::Slurp' => '0',
    'FileHandle' => '0',
    'HTML::PrettyPrinter' => '0',
    'HTML::TreeBuilder' => '0',
    'Test' => '0',
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.30'
  },
  'DISTNAME' => 'HTML-Element-Library',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'HTML::Element::Library',
  'PREREQ_PM' => {
    'Array::Group' => '0',
    'Carp' => '0',
    'Data::Dumper' => '0',
    'Data::Rmap' => '0',
    'HTML::Element' => '0',
    'HTML::FillInForm' => '0',
    'List::MoreUtils' => '0',
    'List::Rotation::Cycle' => '0',
    'List::Util' => '0',
    'Params::Validate' => '0',
    'Scalar::Listify' => '0'
  },
  'VERSION' => '5.112170',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



