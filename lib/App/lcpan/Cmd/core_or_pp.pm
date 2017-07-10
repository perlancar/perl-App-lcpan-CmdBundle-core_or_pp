package App::lcpan::Cmd::core_or_pp;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'Check that a module (with its prereqs) are all core/PP',
    args => {
        %App::lcpan::common_args,
        %App::lcpan::mods_args,
        with_prereqs => {
            schema => ['bool*', is=>1],
        },
        with_recursive_prereqs => {
            schema => ['bool*', is=>1],
        },
        core => {
            schema => ['bool*', is=>1],
        },
        pp => {
            schema => ['bool*', is=>1],
        },
        core_or_pp => {
            schema => ['bool*', is=>1],
        },
    },
    args_rels => {
        'choose_one&' => [
            [qw/with_prereqs with_recursive_prereqs/],
            [qw/core pp core_or_pp/],
        ],
    },
};
sub handle_cmd {
    require Module::CoreList::More;
    require Module::Path::More;
    require Module::XSOrPP;

    my %args = @_;

    my $with_prereqs = delete $args{with_prereqs};
    my $with_recursive_prereqs = delete $args{with_recursive_prereqs};
    my $core       = delete $args{core};
    my $pp         = delete $args{pp};
    my $core_or_pp = delete($args{core_or_pp}) // 1;

    my $mods = {};
    if ($with_prereqs || $with_recursive_prereqs) {
        my $res = App::lcpan::deps(
            %args,
            (level => -1) x !!$with_recursive_prereqs,
        );
        return $res unless $res->[0] == 200;
        for my $e (@{ $res->[2] }) {
            $e->{module} =~ s/^\s+//;
            $mods->{$e->{module}} = $e->{version};
        }
        $mods->{$_} //= 0 for @{ $args{modules} };
    } else {
        $mods->{$_} = 0 for @{ $args{modules} };
    }

    my $what;
    my @errs;
  MOD:
    for my $mod (sort keys %$mods) {
        next if $mod eq 'perl'; # XXX check perl version
        my $v = $mods->{version};
        my $subject = "$mod".($v ? " (version $v)" : "");
        log_trace("Checking %s ...", $subject);
        if ($core) {
            $what //= "core";
            if (!Module::CoreList::More->is_still_core($mod, $v)) {
                push @errs, "$subject is not core";
            }
        } elsif ($pp) {
            $what //= "PP";
            if (!Module::Path::More::module_path(module => $mod)) {
                push @errs, "$subject is not installed, so can't check XS/PP";
                # XXX check installed module version
            } elsif (!Module::XSOrPP::is_pp($mod)) {
                push @errs, "$subject is not $what";
            }
        } else {
            $what //= "core/PP";
            if (Module::CoreList::More->is_still_core($mod, $v)) {
                next MOD;
            } elsif (!Module::Path::More::module_path(module => $mod)) {
                push @errs, "$subject is not installed, so can't check XS/PP";
                # XXX check installed module version
            } elsif (!Module::XSOrPP::is_pp($mod)) {
                push @errs, "$subject is not $what";
            }
        }
    }

    if (@errs) {
        return [200, "OK", 0, {
            'func.errors' => \@errs,
            "cmdline.result" => join("\n", @errs),
            "cmdline.exit_code" => 1,
        }];
    } else {
        return [200, "OK", 1, {
            "cmdline.result" => "All modules".
                ($with_recursive_prereqs ? " with their recursive prereqs" :
                     $with_prereqs ? " with their prereqs" : "")." are $what",
        }];
    }
}

1;
# ABSTRACT:
