BEGIN { $| = 1; print "1..1\n"; }

use Business::OnlinePayment;

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
    print "ok 1\n";
} else {
    print "not ok 1\n";
}
