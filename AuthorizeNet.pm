package Business::OnlinePayment::AuthorizeNet;

# $Id: AuthorizeNet.pm,v 1.1.1.1 2001/09/01 21:47:31 ivan Exp $

use strict;
use Business::OnlinePayment;
use Net::SSLeay qw/make_form post_https/;
use Text::CSV;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader Business::OnlinePayment);
@EXPORT = qw();
@EXPORT_OK = qw();
$VERSION = '3.00';

sub set_defaults {
    my $self = shift;

    $self->server('secure.authorize.net');
    $self->port('443');
    $self->path('/gateway/transact.dll');
}

sub map_fields {
    my($self) = @_;

    my %content = $self->content();

    # ACTION MAP
    my %actions = ('normal authorization' => 'AUTH_CAPTURE',
                   'authorization only'   => 'AUTH_ONLY',
                   'credit'               => 'CREDIT',
                   'post authorization'   => 'PRIOR_AUTH_CAPTURE',
                  );
    $content{'action'} = $actions{lc($content{'action'})} || $content{'action'};

    # TYPE MAP
    my %types = ('visa'               => 'CC',
                 'mastercard'         => 'CC',
                 'american express'   => 'CC',
                 'discover'           => 'CC',
                 'check'              => 'ECHECK',
                );
    $content{'type'} = $types{lc($content{'type'})} || $content{'type'};
    $self->transaction_type($content{'type'});

    # stuff it back into %content
    $self->content(%content);
}

sub remap_fields {
    my($self,%map) = @_;

    my %content = $self->content();
    foreach(keys %map) {
        $content{$map{$_}} = $content{$_};
    }
    $self->content(%content);
}

sub get_fields {
    my($self,@fields) = @_;

    my %content = $self->content();
    my %new = ();
    foreach( grep defined $content{$_}, @fields) { $new{$_} = $content{$_}; }
    return %new;
}

sub submit {
    my($self) = @_;

    $self->map_fields();
    $self->remap_fields(
        type           => 'x_Method',
        login          => 'x_Login',
        password       => 'x_Password',
        action         => 'x_Type',
        description    => 'x_Description',
        amount         => 'x_Amount',
        invoice_number => 'x_Invoice_Num',
        customer_id    => 'x_Cust_ID',
        last_name      => 'x_Last_Name',
        first_name     => 'x_First_Name',
        address        => 'x_Address',
        city           => 'x_City',
        state          => 'x_State',
        zip            => 'x_Zip',
        card_number    => 'x_Card_Num',
        expiration     => 'x_Exp_Date',
        account_number => 'x_Bank_Acct_Num',
        routing_code   => 'x_Bank_ABA_Code',
        bank_name      => 'x_Bank_Name',
        country        => 'x_Country',
        phone          => 'x_Phone',
        fax            => 'x_Fax',
        email          => 'x_Email',
        company        => 'x_Company',
    );

    if($self->transaction_type() eq "ECHECK") {
        $self->required_fields(qw/type login password action amount last_name
                                  first_name account_number routing_code
                                  bank_name/);
    } elsif($self->transaction_type() eq 'CC' ) {
        $self->required_fields(qw/type login password action amount last_name
                                  first_name card_number expiration/);
    } else {
        Carp::croak("AuthorizeNet can't handle transaction type: ".
                    $self->transaction_type());
    }

    my %post_data = $self->get_fields(qw/x_Login x_Password x_Invoice_Num
                                         x_Description x_Amount x_Cust_ID
                                         x_Method x_Type x_Card_Num x_Exp_Date
                                         x_Auth_Code x_Bank_Acct_Num
                                         x_Bank_ABA_Code x_Bank_Name
                                         x_Last_Name x_First_Name x_Address
                                         x_City x_State x_Zip x_Country x_Phone
                                         x_Fax x_Email x_Email_Customer
                                         x_Company x_Country/); 
    $post_data{'x_Test_Request'} = $self->test_transaction()?"TRUE":"FALSE";
    $post_data{'x_ADC_Delim_Data'} = 'TRUE';
    $post_data{'x_ADC_URL'} = 'FALSE';
    $post_data{'x_Version'} = '3.0';

    my $pd = make_form(%post_data);
    my $s = $self->server();
    my $p = $self->port();
    my $t = $self->path();
    my($page,$server_response,%headers) = post_https($s,$p,$t,'',$pd);

    my $csv = new Text::CSV();
    $csv->parse($page);
    my @col = $csv->fields();

    $self->server_response($page);
    if($col[0] eq "1" ) { # Authorized/Pending/Test
        $self->is_success(1);
        $self->result_code($col[0]);
        $self->authorization($col[4]);
    } else {
        $self->is_success(0);
        $self->result_code($col[2]);
        $self->error_message($col[3]);
    }
}

1;
__END__

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
      first_name     => 'Jason',
      last_name      => 'Kohles',
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

=head1 SUPPORTED TRANSACTION TYPES

=head2 Visa, MasterCard, American Express, Discover

Content required: type, login, password, action, amount, first_name, last_name, card_number, expiration.

=head2 Check

Content required: type, login, password, action, amount, first_name, last_name, account_number, routing_code, bank_name.

=head1 DESCRIPTION

For detailed information see L<Business::OnlinePayment>.

=head1 NOTE

Unlike Business::OnlinePayment or previous verisons of
Business::OnlinePayment::AuthorizeNet, 3.0 requires separate first_name and
last_name fields.

=head1 COMPATIBILITY

This module implements Authorize.Net's API verison 3.0.

=head1 AUTHOR

Jason Kohles, jason@mediabang.com

Ivan Kohler <ivan-authorizenet@420.am> updated it for Authorize.Net protocol
3.0 and is the current maintainer.

=head1 SEE ALSO

perl(1). L<Business::OnlinePayment>.

=cut

