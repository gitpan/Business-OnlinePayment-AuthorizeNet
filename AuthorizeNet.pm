package Business::OnlinePayment::AuthorizeNet;

# $Id: AuthorizeNet.pm,v 1.7 1999/07/28 01:01:51 robobob Exp $

use strict;
use Business::OnlinePayment;
use Net::SSLeay;
use Text::CSV;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader Business::OnlinePayment);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();
( $VERSION ) = '$Revision: 1.7 $ ' =~ /\$Revision:\s+([^\s]+)/;

# Preloaded methods go here.

sub set_defaults {
    my $self = shift;

    $self->server('www.authorize.net');
    $self->port('443');
    $self->path('/scripts/authnet25/AuthRequest.asp');
}

sub map_fields {
    my($self) = @_;

    my %content = $self->content();

    # ACTION MAP
    my %actions = ('normal authorization' => 'NA',
                   'authorization only'   => 'AO',
                   'credit'               => 'CR',
                   'post authorization'   => 'PA',
                  );
    $content{'action'} = $actions{lc($content{'action'})} || $content{'action'};

    # TYPE MAP
    my %types = ('visa'               => 'VISA',
                 'mastercard'         => 'MASTERCARD',
                 'american express'   => 'AMEX',
                 'discover'           => 'DISCOVER',
                 'check'              => 'CHECK',
                );
    $content{'type'} = $types{lc($content{'type'})} || $content{'type'};
    $self->transaction_type($content{'type'});

    # stuff it back into %content
    $self->content(%content);
}

sub submit {
    my($self) = @_;

    $self->map_fields();
    $self->remap_fields(
        type           => 'METHOD',
        login          => 'LOGIN',
        password       => 'PASSWORD',
        action         => 'TYPE',
        description    => 'DESCRIPTION',
        amount         => 'AMOUNT',
        invoice_number => 'INVOICE',
        customer_id    => 'CUSTID',
        name           => 'NAME',
        address        => 'ADDRESS',
        city           => 'CITY',
        state          => 'STATE',
        zip            => 'ZIP',
        card_number    => 'CARDNUM',
        expiration     => 'EXPDATE',
    );

    if($self->transaction_type() eq "CHECK") {
        Carp::croak("AuthorizeNet can't (yet) handle CHECK transactions, unfinished");
    } elsif($self->transaction_type() =~ /^VISA|MASTERCARD|AMEX|DISCOVER$/) {
        $self->required_fields(qw/type login password action amount name
                                  address city state zip card_number
                                  expiration/);
    } else {
        Carp::croak("AuthorizeNet can't handle transaction type: ".
                    $self->transaction_type());
    }

    my %post_data;
    my %content = $self->content();

    foreach(qw/LOGIN PASSWORD INVOICE DESCRIPTION AMOUNT CUSTID METHOD TYPE
               CARDNUM EXPDATE AUTHCODE ACCTNO ABACODE BANKNAME NAME ADDRESS
               CITY STATE ZIP COUNTRY PHONE FAX EMAIL EMAILCUSTOMER USER1 USER2
               USER3 USER4 USER5 USER6 USER7 USER8 USER9 USER10/) {
        if(exists($content{$_})) { $post_data{$_} = $content{$_}; }
    }

    $post_data{'TESTREQUEST'} = $self->test_transaction()?"TRUE":"FALSE";
    $post_data{'REJECTAVSMISMATCH'} = $self->require_avs()?"TRUE":"FALSE";
    $post_data{'ECHODATA'} = "TRUE";
    $post_data{'ENCAPSULATE'} = "TRUE";

    my $pd = &Net::SSLeay::make_form(%post_data);
    my($page,$server_response,%headers) = &Net::SSLeay::post_https(
        $self->server(), $self->port(), $self->path(), '', $pd);

    my $csv = new Text::CSV();
    $csv->parse($page);
    my @col = $csv->fields();

    $self->server_response($page);
    if($col[0] eq "A" || $col[0] eq "P" || $col[0] eq "T") { # Authorized/Pending/Test
        $self->is_success(1);
        $self->result_code($col[0]);
        $self->authorization($col[1]);
    } else {
        $self->is_success(0);
        $self->result_code($col[0]);
        $self->error_message($col[2]);
    }
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Business::OnlinePayment::AuthorizeNet - AuthorizeNet backend for Business::OnlinePayment

=head1 SYNOPSIS

  use Business::OnlinePayment;

  my $tx = new Business::OnlinePayment("AuthorizeNet");
  $tx->content(
      type           => 'VISA',
      login          => 'testdrive',
      password       => '',
      action         => 'Normal Authorization',
      description    => 'Business::OnlinePayment test',
      amount         => '49.95',
      invoice_number => '100100',
      customer_id    => 'jsk',
      name           => 'Jason Kohles',
      address        => '123 Anystreet',
      city           => 'Anywhere',
      state          => 'UT',
      zip            => '84058',
      card_number    => '4007000000027',
      expiration     => '09/99',
  );
  $tx->submit();

  if($tx->is_success()) {
      print "Card processed successfully: ".$tx->authorization."\n";
  } else {
      print "Card was rejected: ".$tx->error_message."\n";
  }

=head1 DESCRIPTION

For detailed information see L<Business::OnlinePayment>.

=head1 AUTHOR

Jason Kohles, jason@mediabang.com

=head1 SEE ALSO

perl(1). L<Business::OnlinePayment>.

=cut
