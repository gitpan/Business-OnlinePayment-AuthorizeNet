# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: test.pl,v 1.3 1999/10/01 18:29:05 robobob Exp $

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..3\n"; }
END {print "not ok 1\n" unless $loaded;}
use Business::OnlinePayment::AuthorizeNet;
$loaded = 1;
print "ok 1\n";

my $tx = new Business::OnlinePayment("AuthorizeNet");
$tx->content(
    type           => 'VISA',
    login          => 'testdrive',
    password       => '',
    action         => 'Normal Authorization',
    description    => 'Business::OnlinePayment visa test',
    amount         => '49.95',
    invoice_number => '100100',
    customer_id    => 'jsk',
    name           => 'Jason Kohles',
    address        => '123 Anystreet',
    city           => 'Anywhere',
    state          => 'UT',
    zip            => '84058',
    card_number    => '4007000000027',
    expiration     => '12/00',
);
$tx->test_transaction(1); # test, dont really charge
$tx->submit();

if($tx->is_success()) {
    print "ok 2\n";
} else {
    print "not ok 2\n";
}

# checks are broken it seems
#my $ctx = new Business::OnlinePayment("AuthorizeNet");
#$ctx->content(
#    type           => 'CHECK',
#    login          => 'testdrive',
#    password       => '',
#    action         => 'Normal Authorization',
#    amount         => '49.95',
#    invoice_number => '100100',
#    customer_id    => 'jsk',
#    name           => 'Jason Kohles',
#    account_number => '12345',
#    routing_code   => '123456789',
#    bank_name      => 'First National Test Bank',
#);
#$ctx->test_transaction(1); # test, dont really charge
#$ctx->submit();
#
#if($ctx->is_success()) {
#    print "ok 3\n";
#} else {
#    print "not ok 3 (".$ctx->error_message().")\n";
#}
