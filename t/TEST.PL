
use lib qw(lib);

use warnings FATAL => 'all';

use Apache::TestRun ();

Apache::TestRun->new->run(
	'-maxclients' => 5,
	@ARGV
);

