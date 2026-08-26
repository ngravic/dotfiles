#!/usr/bin/perl
# Claude Code status line: base folder + context usage, right-aligned.
# Reads the status JSON on stdin, prints one line.
use strict;
use warnings;
use utf8;                      # the · separator is multibyte; count it as one column
use JSON::PP ();
binmode STDOUT, ':encoding(UTF-8)';

my $raw = do { local $/; <STDIN> };
my $d = eval { JSON::PP::decode_json($raw) } || {};

# --- feed the tmux usage meter -------------------------------------------
# ~/.dotfiles/tmux/scripts/claude-usage.sh renders this file. Claude Code
# hands us the 5-hour window for free on every render, so the tmux bar never
# has to call the API. Wrapped in eval: a cache problem must never take the
# status line down with it.
eval {
    my $rl = ($d->{rate_limits} || {})->{five_hour} || {};
    if (defined $rl->{used_percentage}) {
        my $dir = ($ENV{XDG_CACHE_HOME} || "$ENV{HOME}/.cache") . '/claude-usage';
        mkdir $dir unless -d $dir;
        my $tmp = "$dir/data.$$";
        open my $fh, '>', $tmp or die "open: $!";
        printf {$fh} "%d\t%s", $rl->{used_percentage} + 0.5, $rl->{resets_at} // '';
        close $fh or die "close: $!";
        rename $tmp, "$dir/data" or do { unlink $tmp; die "rename: $!" };
    }
    1;
};

my $RESET = "\033[0m";
my $DIM   = "\033[2m";
my $BLUE  = "\033[01;34m";

sub human {
    my ($n) = @_;
    return $n unless defined $n && $n =~ /^\d+$/;
    return sprintf('%.1fM', $n / 1_000_000) =~ s/\.0M$/M/r if $n >= 1_000_000;
    return int($n / 1_000) . 'k' if $n >= 1_000;
    return $n;
}

my @parts;

# --- base folder only (no path, no user@host)
my $dir = $d->{workspace}{current_dir} // $d->{cwd};
if (defined $dir && length $dir) {
    $dir =~ s{/+$}{};
    my $home = $ENV{HOME};
    # $HOME itself reads better as ~ than as its basename
    my $base = (defined $home && $dir eq $home) ? '~'
             : ($dir =~ m{([^/]+)$}) ? $1
             : $dir;
    push @parts, $BLUE . $base . $RESET if length $base;
}

# --- context used
my $cw   = $d->{context_window} || {};
my $pct  = $cw->{used_percentage};
my $used = $cw->{total_input_tokens};
my $size = $cw->{context_window_size};
if (defined $pct) {
    # green under 60%, yellow past 60%, red past 80%
    my $color = $pct >= 80 ? "\033[01;31m" : $pct >= 60 ? "\033[01;33m" : "\033[01;32m";
    my $ctx = sprintf('%s%d%%%s', $color, $pct, $RESET);
    $ctx .= sprintf('%s %s/%s%s', $DIM, human($used), human($size), $RESET)
        if defined $used && defined $size;
    push @parts, $ctx;
}

exit 0 unless @parts;    # nothing to show: print nothing, not a line of padding

my $line = join("$DIM  ·  $RESET", @parts);

# --- right-align within the terminal width Claude Code exports as COLUMNS.
# Pad on the left only; leave a 1-column gutter so the line can never wrap
# onto a second row. If COLUMNS is missing or too narrow, print as-is.
my $cols = $ENV{COLUMNS};
if (defined $cols && $cols =~ /^\d+$/ && $cols > 0) {
    (my $visible = $line) =~ s/\033\[[0-9;]*m//g;
    my $pad = $cols - 1 - length($visible);
    $line = (' ' x $pad) . $line if $pad > 0;
}

print $line;
