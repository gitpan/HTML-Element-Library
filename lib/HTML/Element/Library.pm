package HTML::Element::Library;

use 5.006001;
use strict;
use warnings;


our $DEBUG = 0;
#our $DEBUG = 1;

use Carp qw(confess);
use Data::Dumper;
use HTML::Element;
use List::MoreUtils qw/:all/;
use Scalar::Listify;
#use Tie::Cycle;
use List::Rotation::Cycle;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw();

our ($VERSION) = ('$Revision: 1.2 $' =~ m/([\.\d]+)/) ;


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

sub make_counter {
  my $i = 1;
  sub {
    shift() . ':' . $i++
  }
}


sub HTML::Element::iter {
  my ($tree, $p, @data) = @_;

  #  warn 'P: ' , $p->attr('id') ;
  #  warn 'H: ' , $p->as_HTML;

  my $id_incr = make_counter;
  my @item = map {
    my $new_item = clone $p;
    $new_item->replace_content($_);
    $new_item->attr('id', $id_incr->( $p->attr('id') ));
    $new_item;
  } @data;

  $p->replace_with(@item);

}


sub HTML::Element::dual_iter {
  my ($parent, $data) = @_;

  my ($prototype_a, $prototype_b) = $parent->content_list;

  my $id_incr = make_counter;

  my $i;

  @$data %2 == 0 or 
    confess 'dataset does not contain an even number of members';

  my @iterable_data = reform (2, @$data);

  my @item = map {
    my ($new_a, $new_b) = map { clone $_ } ($prototype_a, $prototype_b) ;
    $new_a->splice_content(0,1, $_->[0]);
    $new_b->splice_content(0,1, $_->[1]);
    $_->attr('id', $id_incr->($_->attr('id'))) for ($new_a, $new_b) ;
    ($new_a, $new_b)
  } @iterable_data;

  $parent->delete_content;
  $parent->push_content(@item);

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

  $survivor_node;
}


sub overwrite_action {
  my ($mute_node, %X) = @_;

  $mute_node->attr($X{local_attr}{name} => $X{local_attr}{value}{new});
}


sub HTML::Element::overwrite_attr {
  my $tree = shift;
  
  $tree->mute_elem(@_, \&overwrite_action);
}



sub HTML::Element::mute_elem {
  my ($tree, $mute_attr, $closures, $post_hook) = @_;

  warn "my mute_node = $tree->look_down($mute_attr => qr/.*/) ;";
  my @mute_node = $tree->look_down($mute_attr => qr/.*/) ;

  for my $mute_node (@mute_node) {
    my ($local_attr,$mute_key)        = split /\s+/, $mute_node->attr($mute_attr);
    my $local_attr_value_current      = $mute_node->attr($local_attr);
    my $local_attr_value_new          = $closures->{$mute_key}->($tree, $mute_node, $local_attr_value_current);
    $post_hook->(
      $mute_node,
      tree => $tree,
      local_attr => {
	name => $local_attr,
	value => {
	  current => $local_attr_value_current,
	  new     => $local_attr_value_new
	 }
       }
     ) if ($post_hook) ;
  }
}


sub HTML::Element::table {

  my ($s, %table) = @_;

  my $table = {};

#  use Data::Dumper; warn Dumper \%table;

#  ++$DEBUG if $table{debug} ;

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

#  warn $iter_node;

  warn Dumper ($iter_node, \@iter_node) if $DEBUG;

  $table->{content}    = $table{content};
  $table->{parent}     = $table->{table_node}->parent;


#  $table->{table_node}->detach;
#  $_->detach for @iter_node;

  my @table_rows;

  {
    my $row = $table{tr_data}->($table, $table{table_data});
    last unless defined $row;

      # wont work:      my $new_iter_node = $table->{iter_node}->clone;
      my $I = $iter_node->next;
      warn  "I: $I" if $DEBUG;
      my $new_iter_node = $I->clone;


      $table{td_data}->($new_iter_node, $row);
      push @table_rows, $new_iter_node;

    redo;
  }

  if (@table_rows) {

    my $replace_with_elem = $s->look_down(id => shift @table_gi_tr) ;
    for (@table_gi_tr) {
      $s->look_down(id => $_)->detach;
    }

    $replace_with_elem->replace_with(@table_rows);

  }

}

sub HTML::Element::unroll_select {

  my ($s, %select) = @_;

  my $select = {};

  my $select_node = $s->look_down(id => $select{select_label});

  my $option = $select_node->look_down('_tag' => 'option');

#  warn $option;


  $option->detach;

  while (my $row = $select{data_iter}->($select{data}))
    {
#      warn Dumper($row);
      my $o = $option->clone;
      $o->attr('value', $select{option_value}->($row));
      $o->attr('SELECTED', 1) if ($select{option_selected}->($row)) ;

      $o->replace_content($select{option_content}->($row));
      $select_node->push_content($o);
    }


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

=head3 $tree->overwrite_attr($mutation_attr => $mutating_closures)

This method is designed for taking a tree and reworking a set of nodes in a stereotyped fashion. 
For instance let's say you have 3 remote image archives, but you don't want to put long URLs in your img src
tags for reasons of abstraction, re-use and brevity. So instead you do this:

  <img src="/img/smiley-face.jpg" fixup="src lnc">
  <img src="/img/hot-babe.jpg"    fixup="src playboy">
  <img src="/img/footer.jpg"      fixup="src foobar">

and then when the tree of HTML is being processed, you make this call:

  my %closures = (
     lnc     => sub { my ($tree, $mute_node, $attr_value)= @_; "http://lnc.usc.edu$attr_value" },
     playboy => sub { my ($tree, $mute_node, $attr_value)= @_; "http://playboy.com$attr_value" }
     foobar  => sub { my ($tree, $mute_node, $attr_value)= @_; "http://foobar.info$attr_value" }
  )

  $tree->overwrite_attr(fixup => \%closures) ;

and the tags come out modified like so:

  <img src="http://lnc.usc.edu/img/smiley-face.jpg" fixup="src lnc">
  <img src="http://playboy.com/img/hot-babe.jpg"    fixup="src playboy">
  <img src="http://foobar.info/img/footer.jpg"      fixup="src foobar">

=head3 $tree->mute_elem($mutation_attr => $mutating_closures, [ $post_hook ] )

This is a generalization of C<overwrite_attr>. C<overwrite_attr> assumes the return value of the 
closure is supposed overwrite an attribute value and does it for you. 
C<mute_elem> is a more general function which does nothing but 
hand the closure the element and let it mutate it as it jolly well pleases :)

In fact, here is the implementation of C<overwrite_attr> to give you a taste of how C<mute_attr> is used:

 sub overwrite_action {
   my ($mute_node, %X) = @_;

   $mute_node->attr($X{local_attr}{name} => $X{local_attr}{value}{new});
 }


 sub HTML::Element::overwrite_attr {
   my $tree = shift;
  
   $tree->mute_elem(@_, \&overwrite_action);
 }



=head2 Tree-Building Methods: Select Unrolling

The C<unroll_select> method has this API:

   $tree->unroll_select(
      select_label    => $id_label,
      option_value    => $closure, # how to get option value from data row
      option_content  => $closure, # how to get option content from data row
      option_selected => $closure, # boolean to decide if SELECTED
      data         => $data        # the data to be put into the SELECT
      data_iter    => $closure     # the thing that will get a row of data
    );

Here's an example:

 $tree->unroll_select(
   select_label     => 'clan_list', 
   option_value     => sub { my $row = shift; $row->clan_id },
   option_content   => sub { my $row = shift; $row->clan_name },
   option_selected  => sub { my $row = shift; $row->selected },
   data             => \@query_results, 
   data_iter        => sub { my $data = shift; $data->next }
 )



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


=head4 The manual way (*NOT* recommended)

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
