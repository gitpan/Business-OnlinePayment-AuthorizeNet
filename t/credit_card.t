BEGIN { $| = 1; print "1..1\n"; }

#testing/testing is valid and seems to work...
#print "ok 1 # Skipped: need a valid Authorize.Net login/password to test\n"; exit;

use Business::OnlinePayment;

my $tx = new Business::OnlinePayment("AuthorizeNet");
$tx->content(
    type           => 'VISA',
    login          => 'testing',
    password       => 'testing',
    action         => 'Normal Authorization',
    description    => 'Business::OnlinePayment visa test',
    amount         => '49.95',
    invoice_number => '100100',
    customer_id    => 'jsk',
    first_name     => 'Tofu',
    last_name      => 'Beast',
    address        => '123 Anystreet',
    city           => 'Anywhere',
    state          => 'UT',
    zip            => '84058',
    card_number    => '4007000000027',
    expiration     => '08/06',
);
$tx->test_transaction(1); # test, dont really charge
$tx->submit();

if($tx->is_success()) {
    print "ok 1\n";
} else {
    #warn $tx->error_message;
    print "not ok 1\n";
}
