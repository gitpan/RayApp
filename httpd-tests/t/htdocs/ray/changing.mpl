use strict;
use warnings;
sub handler {
	return {
		pid => $$,
		multiplied_pid => $$ * 3,
	};
}
1;
