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
    my $mods0      = delete $args{modules};

    my $mods = {};
    if ($with_prereqs || $with_recursive_prereqs) {
        require App::lcpan::Cmd::mod2dist;

        my $res;
        $res = App::lcpan::Cmd::mod2dist::handle_cmd(%args, modules=>$mods0);
        #log_trace "mod2dist result: %s", $res;
        return [500, "Can't mod2dist: $res->[0] - $res->[1]"]
            unless $res->[0] == 200;
        my $dists = ref($res->[2]) eq 'HASH' ? [sort keys %{$res->[2]}] : [$res->[2]];
        #log_trace "dists=%s", $dists;

        $res = App::lcpan::deps(
            %args,
            dists => $dists,
            (level => -1) x !!$with_recursive_prereqs,
        );
        return [500, "Can't deps: $res->[0] - $res->[1]"]
            unless $res->[0] == 200;

        for my $e (@{ $res->[2] }) {
            $e->{module} =~ s/^\s+//;
            $mods->{$e->{module}} = $e->{version};
            #log_trace "Added %s (%s) to list of modules to check",
            #    $e->{module}, $e->{version};
        }
        $mods->{$_} //= 0 for @$mods0;
    } else {
        $mods->{$_} = 0 for @$mods0;
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
