package App::lcpan::CmdBundle::core_or_pp;

# DATE
# VERSION

1;
# ABSTRACT: Check whether a module + its prereqs are core/PP

=head1 SYNOPSIS

Install this distribution, then the lcpan subcommands below will be available:

 # Check that a module is core/PP (without checking its prereqs)
 % lcpan core-or-pp JSON::MaybeXS

 # Check that a module and its prereqs are all core/PP
 % lcpan core-or-pp --with-deps JSON::MaybeXS

 # Check that a module and its recursive prereqs are all core/PP
 % lcpan core-or-pp --with-recursive-deps JSON::MaybeXS

 # Check that a module and its prereqs are all core
 % lcpan core-or-pp --with-deps --core JSON::MaybeXS

 # Check that a module and its prereqs are all PP
 % lcpan core-or-pp --with-deps --pp JSON::MaybeXS


=head1 DESCRIPTION

Checking that a module with its (recursive) (runtime requires) prereqs are all
core/PP. Doing this check is useful when we want to fatpack said module along
with its prereqs.


=head1 SEE ALSO

L<lcpan>
