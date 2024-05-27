#!./perl

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
    require Config;
}

use v5.36;
use feature 'class';
no warnings 'experimental::class';

{
    role TestRoleA {
        method one { return 1 }
    }

    class TestClassA : does(TestRoleA) {
        method two   { return 2 }
        method three { return $self->one + $self->two }
    }

    {
        my $obj = TestClassA->new;
        isa_ok( $obj, ["TestClassA"], '$obj' );
        ok( $obj->DOES('TestRoleA'), 'TestClassA does TestRoleA' );
        ok( $obj->DOES('TestClassA'), 'TestClassA does TestClassA' );
        ok( TestClassA->DOES('TestRoleA'), 'DOES works as a class method' );

        is( $obj->one,   1, 'TestClassA has a ->one method' );
        is( $obj->two,   2, 'TestClassA has a ->two method' );
        is( $obj->three, 3, 'TestClassA has a ->three method' );
    }
}

{
    role TestRoleB :does(TestRoleA) {
        method four { return 4 }
    }

    class TestClassB :does(TestRoleB) {
        method five  { return $self->one + $self->four }
    }

    {
        my $obj = TestClassB->new;
        isa_ok( $obj, ["TestClassB"], '$obj' );
        ok( $obj->DOES('TestRoleA'), 'TestClassB does TestRoleA' );
        is( $obj->one, 1, 'TestClassB has a ->one method' );
        ok( !$obj->can('two'), 'TestClassB does not have a ->two method' );
        is( $obj->four, 4, 'TestClassB has a ->four method' );
        is( $obj->five, 5, 'TestClassB has a ->five method' );
        is( $obj->six, 6, 'TestClassB has a ->six method' );
    }
}

{
    role TestRoleC { }
    class TestClassC :isa(TestClassB) :does(TestRoleC) { }

    {
        ok(TestClassC->DOES('TestClassB'), 'TestClassC does TestClassB');
        ok(TestClassC->DOES('TestRoleB'), 'TestClassC does TestRoleB');
        ok(TestClassC->DOES('TestRoleA'), 'TestClassC does TestRoleA');
    }

}

{
    # Perl #19676
    #   https://github.com/Perl/perl5/issues/19676

    role TestRoleG {
        method a { pack "C", 65 }
    }

    class TestClassG : does(TestRoleG) { }

    {
        is( TestClassG->new->a, "A", 'TestClassG->a method has constant' );
    }
}

{
    role StatefulRoleA {
        field $one = 1;
        field $param :param(two);
        field $also :reader = 3;
        method one { $one }
    }

    class StatefulClassA :does(StatefulRoleA) {
        field $two = 2;
        method two { $two }
    }

    my $obj = StatefulClassA->new( param => 'param' );
    isa_ok( $obj, ['StatefulClassA'], '$obj' );

    is( $obj->one,   1,       'StatefulClassA has a ->one method' );
    is( $obj->two,   2,       'StatefulClassA has a ->two method' );
    is( $obj->param, 'param', 'StatefulClassA has a ->param method' );
    is( $obj->also,  3,       'StatefulClassA has a ->also method' );
}

{
    role StatefulClassB :isa(StatefulClassA) {
        field $three = 3;
        method three { $three }
    }

    my $obj = StatefulClassB->new;
    isa_ok( $obj, ['StatefulClassB'], '$obj' );

    is( $obj->one,   1, 'StatefulClassB has a ->one method' );
    is( $obj->two,   2, 'StatefulClassB has a ->two method' );
    is( $obj->three, 3, 'StatefulClassB has a ->three method' );
}

{
    role StatefulRoleC :does(StatefulRoleA) {
        field $four = 4;
        method four { $four }
    }

    class StatefulClassC :does(StatefulRoleB) { }

    my $obj = StatefulClassC->new;
    isa_ok( $obj, ['StatefulClassC'], '$obj' );
    is( $obj->one,   1, 'StatefulClassC has a ->one method' );
    is( $obj->three, 3, 'StatefulClassC has a ->three method' );
}

# diamond composition scenario
{
   role StatefulRoleE {
        field $field = 1;
        ADJUST { $field++ }
        method field { $field }
   }

   role StatefulRoleE2 :does(StatefulRoleE) {}
   role StatefulRoleE3 :does(StatefulRoleE2) {}
   role StatefulRoleEx :does(StatefulRoleE StatefulRoleE2) {}

   class StatefulClassE :does(StatefulRoleE2 StatefulRoleE3) {}

   my $obj1 = StatefulClassE->new;
   is( $obj1->field, 2, 'StatefulClassE->field is 2 via diamond' );

   class StatefulClassEx :does(StatefulRoleEx) {}

   my $obj2 = StatefulClassEx->new;
   is( $obj2->field, 2, 'DxClass->field is 2 via diamond' );
}

# Commutative composition scenario
# A + B = B + A
{
    class StatefulClassF :does(StatefulRoleA StatefulRoleB) { }
    class StatefulClassG :does(StatefulRoleB StatefulRoleA) { }


    # TODO we probably need better tests here
    my $o1 = StatefulClassF->new;
    my $o2 = StatefulClassG->new;
    is( $o1->one, $o2->one, 'StatefulClassF->one and StatefulClassG->one are equal' );
}

# Associative composition scenario
# (A+B)+C = A+(B+C)
{
    # TODO
}

# Cumulative Associative composition scenario
# A+(B+C) = C+(B+A)
{
    # TODO
}

# required methods
{
    use feature 'try';

    role RequiresFoo {
        method foo;
    }
    class RequiresFooClass :does(RequiresFoo) {}

    try {
        RequiresFooClass->new->foo()
    }
    catch($e) {
        like($e, qr/Method "foo" is required by role "RequiresFoo" in class "RequiresFooClass"/, 'required method foo is missing');
    };

    role ComposesRequiresFoo :Does(RequiresFoo) { }
    class ComposesRequiresFooClass :does(ComposesRequiresFoo) {}

    try {
        ComposesRequiresFooClass->new->foo()
    }
    catch($e) {
        like($e, qr/Method "foo" is required by role "ComposesRequiresFoo" in class "ComposesRequiresFooClass"/, 'required method foo is missing');
    };

    class HasRequiredFoo :does(ComposesRequiresFoo) {
        method foo { 1 }
    }
    is (HasRequiredFoo->new->foo(), 1, 'HasRequiredFoo->foo is 1');
}
