package HTML::Element::Library;

use 5.006001;
use strict;
use warnings;


#our $DEBUG = 0;
our $DEBUG = 1;

use Carp qw(confess);
use Data::Dumper;
use HTML::Element;
use List::MoreUtils qw/:all/;
use Scalar::Listify;
use Tie::Cycle;
use List::Rotation::Cycle;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();

our $VERSION = '0.01';

# Preloaded methods go here.

sub HTML::Element::siblings {
  my $element = shift;
  my $p = $element->parent;
  return () unless $p;
  $p->content_list;
}

sub HTML::Element::sibdex {

  my $element = shift;
  firstidx { $_ eq $element } $element->siblings

}

sub HTML::Element::addr { goto &HTML::Element::sibdex }

sub HTML::Element::replace_content {
  my $elem = shift;
  $elem->delete_content;
  $elem->push_content(@_);
}

sub HTML::Element::wrap_content {
  my($self, $wrap) = @_;
  my $content = $self->content;
  if (ref $content) {
    $wrap->push_content(@$content);
    @$content = ($wrap);
  }
  else {
    $self->push_content($wrap);
  }
  $wrap;
}


sub HTML::Element::position {
  # Report coordinates by chasing addr's up the
  # HTML::ElementSuper tree.  We know we've reached
  # the top when a) there is no parent, or b) the
  # parent is some HTML::Element unable to report
  # it's position.
  my $p = shift;
  my @pos;
  while ($p) {
    my $a = $p->addr;
    unshift(@pos, $a) if defined $a;
    $p = $p->parent;
  }
  @pos;
}


sub HTML::Element::content_handler {
  my ($tree, $id_name, $content) = @_;

  $tree->set_child_content(id => $id_name, $content);

}

sub HTML::Element::set_child_content {
  my $tree      = shift;
  my $content   = pop;
  my @look_down = @_;

  my $content_tag = $tree->look_down(@look_down);

  unless ($content_tag) {
    warn "criteria [@look_down] not found";
    return;
  }

  $content_tag->replace_content($content);

}

sub HTML::Element::highlander {
  my ($tree, $local_root_id, $aref, @arg) = @_;

  ref $aref eq 'ARRAY' or confess 
    "must supply array reference";
    
  my @aref = @$aref;
  @aref % 2 == 0 or confess 
    "supplied array ref must have an even number of entries";

  warn __PACKAGE__ if $DEBUG;

  my $survivor;
  while (my ($id, $test) = splice @aref, 0, 2) {
    warn $id if $DEBUG;
    if ($test->(@arg)) {
      $survivor = $id;
      last;
    }
  }


  my @id_survivor = (id => $survivor);
  my $survivor_node = $tree->look_down(@id_survivor);
#  warn $survivor;
#  warn $local_root_id;
#  warn $node;

  warn "survivor: $survivor" if $DEBUG;
  warn "tree: "  . $tree->as_HTML if $DEBUG;

  $survivor_node or die "search for @id_survivor failed in tree($tree): " . $tree->as_HTML;

  my $survivor_node_parent = $survivor_node->parent;
  $survivor_node = $survivor_node->clone;
  $survivor_node_parent->replace_content($survivor_node);

  warn "new tree: " . $tree->as_HTML if $DEBUG;

}


sub HTML::Element::table {

  my ($s, %table) = @_;

  my $table = {};

  $table->{table_node} = $s->look_down(id => $table{gi_table});
  $table->{table_node} or confess
    "table tag not found via (id => $table{gi_table}";

  my @table_gi_tr = listify $table{gi_tr} ;
  my @iter_node = map 
    {
      my $tr = $table->{table_node}->look_down(id => $_);
      $tr or confess "tr with id => $_ not found";
      $tr;
    } @table_gi_tr;

  warn "found " . @iter_node . " iter nodes " if $DEBUG;
#  tie my $iter_node, 'Tie::Cycle', \@iter_node;
  my $iter_node =  List::Rotation::Cycle->new(@iter_node);

  warn $iter_node;

  warn Dumper ($iter_node, \@iter_node) if $DEBUG;

  $table->{content}    = $table{content};
  $table->{parent}     = $table->{table_node}->parent;


  $table->{table_node}->detach;
  $_->detach for @iter_node;

  my $add_table;

  while (my $row = $table{tr_data}->($table, $table{table_data})) 
    {
      ++$add_table;

      warn "add_table: $add_table" if $DEBUG;


      # wont work:      my $new_iter_node = $table->{iter_node}->clone;
      my $I = $iter_node->next;
      warn  "I: $I" if $DEBUG;
      my $new_iter_node = $I->clone;


      $table{td_data}->($new_iter_node, $row);
      $table->{table_node}->push_content($new_iter_node);
    }

  $table->{parent}->push_content($table->{table_node}) if $add_table;

}


sub HTML::Element::set_sibling_content {
  my ($elt, $content) = @_;

  $elt->parent->splice_content($elt->pindex + 1, 1, $content);

}




1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

HTML::Element::Library - HTML::Element convenience functions

=head1 SYNOPSIS

  use HTML::Element::Library;
  use HTML::TreeBuilder;

=head1 DESCRIPTION

This method provides API calls for common actions on trees when using 
L<HTML::Tree>.

=head1 METHODS

The test suite contains examples of each of these methods in a
file C<t/$method.t>  

=head2 Positional Querying Methods

=head3 $elem->siblings

Return a list of all nodes under the same parent.

=head3 $elem->sibdex

Return the index of C<$elem> into the array of siblings of which it is 
a part. L<HTML::ElementSuper> calls this method C<addr> but I don't think
that is a descriptive name. And such naming is deceptively close to the
C<address> function of C<HTML::Element>. HOWEVER, in the interest of 
backwards compatibility, both methods are available.

=head3 $elem->addr

Same as sibdex

=head3 $elem->position()

Returns the coordinates of this element in the tree it inhabits.
This is accomplished by succesively calling addr() on ancestor
elements until either a) an element that does not support these
methods is found, or b) there are no more parents.  The resulting
list is the n-dimensional coordinates of the element in the tree.

=head2 Tree Rewriting Methods

=head3 $elem->replace_content($new_elem)

Replaces all of C<$elem>'s content with C<$new_elem>. 

=head3 $elem->wrap_content($wrapper_element)

Wraps the existing content in the provided element. If the provided element
happens to be a non-element, a push_content is performed instead.

=head3 $elem->set_child_content(@look_down, $content)

  This method looks down $tree using the criteria specified in @look_down using the the HTML::Element look_down() method.

After finding the node, it detaches the node's content and pushes $content as the node's content.

=head3 $tree->content_handler($sid_value , $content)

This is a convenience method. Because the look_down criteria will often simply be:

   id => 'fixme'

to find things like:

   <a id=fixme href=http://www.somesite.org>replace_content</a>

You can call this method to shorten your typing a bit. You can simply type

   $elem->content_handler( fixme => 'new text' )

Instead of typing:

  $elem->set_child_content(sid => 'fixme', 'new text') 

=head3 $tree->highlander($subtree_span_id, $conditionals, @conditionals_args)

This allows for "if-then-else" style processing. Highlander was a movie in
which only one would survive. Well, in terms of a tree when looking at a 
structure that you want to process in C<if-then-else> style, only one child
will survive. For example, given this HTML template:

 <span klass="highlander" id="age_dialog"> 
    <span id="under10"> 
       Hello, does your mother know you're  
       using her AOL account? 
    </span> 
    <span id="under18"> 
       Sorry, you're not old enough to enter  
       (and too dumb to lie about your age) 
    </span> 
    <span id="welcome"> 
       Welcome 
    </span> 
 </span> 
 
We only want one child of the C<span> tag with id C<age_dialog> to remain
based on the age of the person visiting the page.

So, let's setup a call that will prune the subtree as a function of age:

 sub process_page {
  my $age = shift;
  my $tree = HTML::TreeBuilder->new_from_file('t/html/highlander.html');

  $tree->highlander
    (age_dialog =>
     [
      under10 => sub { $_[0] < 10} , 
      under18 => sub { $_[0] < 18} ,
      welcome => sub { 1 }
     ],
     $age
    );

And there we have it. If the age is less than 10, then the node with 
id C<under10> remains. For age less than 18, the node with id C<under18> 
remains.
Otherwise our "else" condition fires and the child with id C<welcome> remains.

=head2 Tree-Building Methods: Table Generation

Matthew Sisk has a much more intuitive (imperative)
way to generate tables via his module
L<HTML::ElementTable>. However, for those with callback fever, the following
method is available. First, we look at a nuts and bolts way to build a table
using only standard L<HTML::Tree> API calls. Then the C<table> method 
available here is discussed.

=head3 Sample Model

 package Simple::Class;
 
 use Set::Array;
 
 my @name   = qw(bob bill brian babette bobo bix);
 my @age    = qw(99  12   44    52      12   43);
 my @weight = qw(99  52   80   124     120  230);
 
 
 sub new {
     my $this = shift;
     bless {}, ref($this) || $this;
 }
 
 sub load_data {
     my @data;
 
     for (0 .. 5) {
 	push @data, { 
 	    age    => $age[rand $#age] + int rand 20,
 	    name   => shift @name,
 	    weight => $weight[rand $#weight] + int rand 40
 	    }
     }
 
   Set::Array->new(@data);
 }
 
 
 1;


=head4 Sample Usage:

       my $data = Simple::Class->load_data;
       ++$_->{age} for @$data

=head3 Inline Code to Unroll a Table

=head4 HTML

 <html>
 
   <table id="load_data">
 
     <tr>  <th>name</th><th>age</th><th>weight</th> </tr>
 
     <tr id="iterate">
 
         <td id="name">   NATURE BOY RIC FLAIR  </td>
         <td id="age">    35                    </td>
         <td id="weight"> 220                   </td>
 
     </tr>
 
   </table>
 
 </html>


=head4 The manual way (not recommended)

 require 'simple-class.pl';
 use HTML::Seamstress;
 
 # load the view
 my $seamstress = HTML::Seamstress->new_from_file('simple.html');
 
 # load the model
 my $o = Simple::Class->new;
 my $data = $o->load_data;
 
 # find the <table> and <tr> 
 my $table_node = $seamstress->look_down('id', 'load_data');
 my $iter_node  = $table_node->look_down('id', 'iterate');
 my $table_parent = $table_node->parent;
 
 
 # drop the sample <table> and <tr> from the HTML
 # only add them in if there is data in the model
 # this is achieved via the $add_table flag
 
 $table_node->detach;
 $iter_node->detach;
 my $add_table;
 
 # Get a row of model data
 while (my $row = shift @$data) {
 
   # We got row data. Set the flag indicating ok to hook the table into the HTML
   ++$add_table;
 
   # clone the sample <tr>
   my $new_iter_node = $iter_node->clone;
 
   # find the tags labeled name age and weight and 
   # set their content to the row data
   $new_iter_node->content_handler($_ => $row->{$_}) 
     for qw(name age weight);
 
   $table_node->push_content($new_iter_node);
 
 }
 
 # reattach the table to the HTML tree if we loaded data into some table rows
 
 $table_parent->push_content($table_node) if $add_table;
 
 print $seamstress->as_HTML;
 


=head3 Seamstress API call to Unroll a Table

 require 'simple-class.pl';
 use HTML::Seamstress;
 
 # load the view
 my $seamstress = HTML::Seamstress->new_from_file('simple.html');
 # load the model
 my $o = Simple::Class->new;
 
 $seamstress->table
   (
    # tell seamstress where to find the table, via the method call
    # ->look_down('id', $gi_table). Seamstress detaches the table from the
    # HTML tree automatically if no table rows can be built
 
      gi_table    => 'load_data',
 
    # tell seamstress where to find the tr. This is a bit useless as
    # the <tr> usually can be found as the first child of the parent
 
      gi_tr       => 'iterate',
      
    # the model data to be pushed into the table
 
      table_data  => $o->load_data,
 
    # the way to take the model data and obtain one row
    # if the table data were a hashref, we would do:
    # my $key = (keys %$data)[0]; my $val = $data->{$key}; delete $data->{$key}
 
      tr_data     => sub { my ($self, $data) = @_;
 			  shift(@{$data}) ;
 			},
 
    # the way to take a row of data and fill the <td> tags
 
      td_data     => sub { my ($tr_node, $tr_data) = @_;
 			  $tr_node->content_handler($_ => $tr_data->{$_})
 			    for qw(name age weight) }
 
   );
 
 
 print $seamstress->as_HTML;


=head3 Looping over Multiple Sample Rows

* HTML

 <html>
 
   <table id="load_data" CELLPADDING=8 BORDER=2>
 
     <tr>  <th>name</th><th>age</th><th>weight</th> </tr>
 
     <tr id="iterate1" BGCOLOR="white" >
 
         <td id="name">   NATURE BOY RIC FLAIR  </td>
         <td id="age">    35                    </td>
         <td id="weight"> 220                   </td>
 
     </tr>
     <tr id="iterate2" BGCOLOR="#CCCC99">
 
         <td id="name">   NATURE BOY RIC FLAIR  </td>
         <td id="age">    35                    </td>
         <td id="weight"> 220                   </td>
 
     </tr>
 
   </table>
 
 </html>


* Only one change to last API call. 

This:

	gi_tr       => 'iterate',

becomes this:

	gi_tr       => ['iterate1', 'iterate2']

=head3 Whither a Table with No Rows

Often when a table has no rows, we want to display a message
indicating this to the view. Use conditional processing to decide what
to display:

	<span id=no_data>
		<table><tr><td>No Data is Good Data</td></tr></table>
	</span>
	<span id=load_data>
 <html>
 
   <table id="load_data">
 
     <tr>  <th>name</th><th>age</th><th>weight</th> </tr>
 
     <tr id="iterate">
 
         <td id="name">   NATURE BOY RIC FLAIR  </td>
         <td id="age">    35                    </td>
         <td id="weight"> 220                   </td>
 
     </tr>
 
   </table>
 
 </html>

	</span>




=head1 SEE ALSO

=over

=item * L<HTML::Tree>

A perl package for creating and manipulating HTML trees

=item * L<HTML::ElementTable>

An L<HTML::Tree> - based module which allows for manipulation of HTML
trees using cartesian coordinations. 

=item * L<HTML::Seamstress>

An L<HTML::Tree> - based module inspired by XMLC:

 http://xmlc.enhydra.org

which allows for non-embedded tree-based HTML templating.

=head1 AUTHOR

Terrence Brannon, E<lt>tbone@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Terrence Brannon

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
