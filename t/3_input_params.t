
#!perl -d:ptkdb

use Test::More 'no_plan';

BEGIN { use_ok( 'RayApp' ); }

my $rayapp = new RayApp;
isa_ok($rayapp, 'RayApp');

my $dsd;

ok($dsd = $rayapp->load_dsd_string('<?xml version="1.0"?>
<application>
	<id type="int"/>
	<_param name="jezek" />
	<_param prefix="xx" />
	<_param name="id" multiple="yes"/>
	<_param name="int" type="int"/>
	<_param name="num" type="num"/>
</application>
'), 'Load DSD with parameters');
is($rayapp->errstr, undef, 'Errstr should not be set');

is($dsd->validate_parameters(
	'jezek' => 'krtek',
	'xx-1' => '14',
	'xx-2' => 34,
	'int' => -56,
	'num' => '+13.6',
	'id' => 14,
	'id' => 'fourteen',
	), 1,
	'Check valid parameters, should not fail.');
is($dsd->errstr, undef, 'Errstr should not be set');

is($dsd->validate_parameters(
	'jezek1' => 'krtek',
	'xx-1' => '14',
	'xx-1' => 34,
	'int' => 'x-56',
	'num' => 'four',
	), undef,
	'Check valid parameters, should not fail.');
is($dsd->errstr,
	qq!Parameter 'int' has non-integer value ['x-56']\nUnknown parameter 'jezek1'='krtek'\nParameter 'num' has non-numeric value ['four']\nParameter 'xx-1' has multiple values ['14', '34']\n!,
	'Errstr should not be set');

