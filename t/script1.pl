
sub handler {
	my $param = shift;
	return {
		students => [
			[ 'Peter', 'Wolf' ],
			[ 'Brian', 'Fox' ],
			[ 'Leslie', 'Child' ],
			[ 'Barbara', 'Bailey' ],
			[ 'Russell', 'King' ],
			[ 'Michael', 'Johnson' ],
			[ 'Michael', 'Shell' ],
			[ 'Tim', 'Jasmine' ],


		],
		program => {
			id => 1523,
			name => 'Biology',
			code => '8234B',
			}
	};
}

1;

