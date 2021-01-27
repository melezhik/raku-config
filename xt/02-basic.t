use Test;
use RakuConfig;
use Test::Deeply::Relaxed;
use File::Directory::Tree;

plan 11;
my %config;
my $tmp = 'tmp';
my $cwd = $*CWD;
rmtree $tmp if $tmp.IO.e;
mktree $tmp;
chdir $tmp;

my $path = 'config.raku';

throws-like { &get-config( :no-cache ) }, X::RakuConfig::NoFiles,
        message => / 'config.raku' .+ 'is not a file or' /, 'fails with no config file';

%config = <one two three > Z=> 1 ..*;
$path.IO.spurt: %config.raku;
is-deeply-relaxed get-config(:no-cache), %config, 'simple get works';

write-config(%config);
my $rv = $path.IO.slurp;
like $rv, /
['one => 1' \,? .+?
| 'two => 2' \,? .+?
| 'three => 3' \,? .+?
] ** 3
/, 'written human readable';

is-deeply-relaxed get-config(:no-cache), %config, 'round about correct';

$path.IO.unlink;
$path = 'configs';
mktree $path;

write-config(%config, :$path);
is-deeply-relaxed get-config(:path("$path/config.raku")), %config, 'different filename round about correct';

empty-directory $path;
my %big-conf;
for <xfig yfig zfig> {
    my %config = (<a b c>  X~ $_) Z=> 1 ..*;
    write-config(%config, :$path, :fn($_ ~ '.raku'));
    %big-conf,=%config;
}

is-deeply-relaxed get-config(:$path), %big-conf, "config from multiple files";

throws-like { get-config(:$path, :required<mode supply>) },
        X::RakuConfig::MissingKeys,
        message => / 'The following keys were expected' /,
        'died without required keys', ;
# with caching
lives-ok { get-config(:$path, :required<axfig byfig czfig azfig>) }, 'happy with keys';
# prevent caching by changing path
rmtree $path;
$path = 'plugs';
mktree $path;
%big-conf = Empty;
for <xfig yfig zfig> {
    my %config = (<a b c>  X~ $_) Z=> 1 ..*;
    write-config(%config, :$path, :fn($_ ~ '.raku'));
    %big-conf,= %config;
}
is-deeply-relaxed get-config(:$path, :required<axfig byfig czfig azfig>),
        %big-conf, "config from multiple files with required keys";

rmtree $path;
throws-like { $rv = write-config(%config, :$path, :fn<xxx.raku>) },
    X::RakuConfig::BadDirectory,
    'captures non-existent directory',
    message => / 'Cannot write' .+ 'to' /;

%config = %(
    cache => 'cache',
    sources => 'sources',
    :!no-status,
    source-obtain => '',
    source-refresh => '',
    mode => 'test',
    extensions => <rakudoc pod6 pm6 pl6 >
);

'config.raku'.IO.spurt(q:to/DATA/);
    %(
        cache => 'cache',
        sources => 'sources',
        :!no-status,
        source-obtain => '',
        source-refresh => '',
        mode => 'test',
        extensions => <rakudoc pod6 pm6 pl6 >
    )
    DATA
is-deeply-relaxed get-config(:no-cache,
        :required< no-status cache sources source-obtain source-refresh mode extensions >),
        %config,
        'with keys set to empty strings required works';

#restore
chdir $cwd;
rmtree $tmp;

done-testing;
