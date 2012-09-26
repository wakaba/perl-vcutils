package AnyEvent::Git::Repository;
use strict;
use warnings;
use File::Temp;
use Path::Class;
use AnyEvent;
use AnyEvent::Util;
use Encode;
use Digest::SHA1 qw(sha1_hex);

my $DEBUG = $ENV{AEGR_DEBUG};

sub new_from_url_and_cached_repo_set_d {
    return bless {url => $_[1], cached_repo_set_d => $_[2]}, $_[0];
}

sub url {
    return $_[0]->{url};
}

sub url_as_hash {
    return $_[0]->{url_as_hash} ||= sha1_hex encode 'utf-8', $_[0]->url;
}

sub branch {
    if (@_ > 1) {
        $_[0]->{branch} = $_[1];
    }
    return $_[0]->{branch};
}

sub revision {
    if (@_ > 1) {
        $_[0]->{revision} = $_[1];
    }
    return $_[0]->{revision};
}

sub onmessage {
    if (@_ > 1) {
        $_[0]->{onmessage} = $_[1];
    }
    return $_[0]->{onmessage} ||= sub { };
}

sub print_message {
    my ($self, $msg) = @_;
    $self->onmessage->($msg);
}

sub die_message {
    my ($self, $msg) = @_;
    $self->onmessage->($msg, die => 1);
    die $msg;
}

sub cached_repo_set_d {
    return $_[0]->{cached_repo_set_d};
}

sub cached_repo_d {
    return $_[0]->{cached_repo_d} ||= $_[0]->cached_repo_set_d->subdir($_[0]->url_as_hash);
}

sub has_cached_repo_d_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    my $d = $self->cached_repo_d;
    if (not -d $d) {
        $cv->send(0);
    } elsif (not -f $d->file('config')) {
        $cv->send(0);
    } else {
        my $rev;
        run_cmd(
            qq{cd \Q$d\E && git rev-parse HEAD},
            '>' => \$rev,
        )->cb(sub {
            $cv->send($rev && $rev =~ /[0-9a-z]/);
        });
    }
    return $cv;
}

sub temp_repo_temp {
    my $self = shift;
    return $self->{temp_repo_temp} ||= File::Temp->newdir('AEGR-XXXXXX', TMPDIR => 1, CLEANUP => !$DEBUG);
}

sub temp_repo_d {
    my $self = shift;
    return $self->{temp_repo_d} ||= dir($self->temp_repo_temp->dirname);
}

sub git_as_cv {
    my ($self, $cmd, %args) = @_;
    $self->print_message('$ ' . join ' ', 'git', @$cmd);
    my $onmessage = $self->onmessage;
    my $d = $args{d} || $self->temp_repo_d;
    $cmd = ['sh', '-c', 'cd ' . (quotemeta $d) . ' && git ' . join ' ', map { quotemeta } @$cmd];
    warn join ' ', @$cmd, "\n" if $DEBUG;
    return run_cmd $cmd, 
        '>' => $args{onstdout} || sub {
            $onmessage->($_[0]) if defined $_[0];
        },
        '2>' => sub {
            $onmessage->($_[0]) if defined $_[0];
        },
    ;
}

sub prepare_cached_repo_d_as_cv {
    my $self = shift;
    my $cv1 = AE::cv;
    $self->has_cached_repo_d_as_cv->cb(sub {
        if ($_[0]->recv) {
            $self->git_as_cv(['fetch', 'origin'], d => $self->cached_repo_d)->cb(sub {
                $cv1->send;
            });
        } else {
            $self->git_as_cv(['clone', '--mirror', $self->url => $self->cached_repo_d])->cb(sub {
                $cv1->send;
            });
        }
    });
    return $cv1;
}

sub clone_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $clone_cv = $self->git_as_cv(['clone', $self->cached_repo_d => $self->temp_repo_d->stringify], d => $self->cached_repo_d)->cb(sub {
            my $rev = $self->revision;
            $rev = $self->branch unless defined $rev;
            $rev = 'master' unless defined $rev;
            $self->git_as_cv(['checkout', $rev])->cb(sub {
                $self->git_as_cv(['remote', 'set-url', 'origin', $self->url])->cb(sub {
                    $self->git_as_cv(['submodule', 'update', '--init'])->cb(sub {
                        $cv->send;
                    });
                });
            });
        });
    });
    return $cv;
}

sub get_branches_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show-ref', '--dereference', '--heads'],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            $cv->send([map { $_->[1] =~ s{^refs/heads/}{}; $_ } map { [split /\s+/, $_] } split /\n/, $result]);
        });
    });
    return $cv;
}

sub get_tags_as_cv {
    my $self = shift;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show-ref', '--dereference', '--tags'],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            $cv->send([map { $_->[1] =~ s{^refs/tags/}{}; $_ } map { [split /\s+/, $_] } split /\n/, $result]);
        });
    });
    return $cv;
}

sub get_commit_info_as_cv {
    my ($self, $sha) = @_;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['show', '--raw', '--format=raw', $sha],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            require Git::Parser::Log;
            my $parsed = (defined $result and length $result)
                ? Git::Parser::Log->parse_format_raw(decode 'utf-8', $result)->{commits}->[0]
                : undef;
            $cv->send($parsed);
        });
    });
    return $cv;
}

sub get_commit_info_list_as_cv {
    my ($self, $sha) = @_;
    my $cv = AE::cv;
    $self->prepare_cached_repo_d_as_cv->cb(sub {
        my $result = '';
        $self->git_as_cv(
            ['log', '--raw', '--format=raw', $sha],
            d => $self->cached_repo_d,
            onstdout => \$result,
        )->cb(sub {
            require Git::Parser::Log;
            my $parsed = (defined $result and length $result)
                ? Git::Parser::Log->parse_format_raw(decode 'utf-8', $result)->{commits}
                : undef;
            $cv->send($parsed);
        });
    });
    return $cv;
}

1;