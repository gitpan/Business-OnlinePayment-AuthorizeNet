package Business::OnlinePayment::AuthorizeNet;

# $Id: AuthorizeNet.pm,v 1.10 2002/04/24 05:02:54 ivan Exp $

use strict;
use Business::OnlinePayment;
use Net::SSLeay qw/make_form post_https/;
use Text::CSV_XS;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader Business::OnlinePayment);
@EXPORT = qw();
@EXPORT_OK = qw();
$VERSION = '3.11';

sub set_defaults {
    my $self = shift;

    $self->server('secure.authorize.net');
    $self->port('443');
    $self->path('/gateway/transact.dll');

    $self->build_subs('order_number'); #no idea how it worked for jason w/o this
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
	order_number   => 'x_Trans_ID',
    );

    if($self->transaction_type() eq "ECHECK") {
        $self->required_fields(qw/type login password action amount last_name
                                  first_name account_number routing_code
                                  bank_name/);
    } elsif($self->transaction_type() eq 'CC' ) {
      if ( $self->{_content}->{action} eq 'PRIOR_AUTH_CAPTURE' ) {
        $self->required_fields(qw/type login password action amount
                                  card_number expiration/);
      } else {
        $self->required_fields(qw/type login password action amount last_name
                                  first_name card_number expiration/);
      }
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
                                         x_Company x_Country x_Trans_ID/); 
    $post_data{'x_Test_Request'} = $self->test_transaction()?"TRUE":"FALSE";
    $post_data{'x_ADC_Delim_Data'} = 'TRUE';
    $post_data{'x_ADC_URL'} = 'FALSE';
    $post_data{'x_Version'} = '3.1';

    my $pd = make_form(%post_data);
    my $s = $self->server();
    my $p = $self->port();
    my $t = $self->path();
    my($page,$server_response,%headers) = post_https($s,$p,$t,'',$pd);
    #escape NULL (binary 0x00) values
    $page =~ s/\x00/\^0/g;

    my $csv = new Text::CSV_XS();
    $csv->parse($page);
    my @col = $csv->fields();

    $self->server_response($page);
    if($col[0] eq "1" ) { # Authorized/Pending/Test
        $self->is_success(1);
        $self->result_code($col[0]);
        $self->authorization($col[4]);
	$self->order_number($col[6]);
    } else {
        $self->is_success(0);
        $self->result_code($col[2]);
        $self->error_message($col[3]);
        unless ( $self->result_code() ) { #additional logging information
          #$page =~ s/\x00/\^0/g;
          $self->error_message($col[3].
            " DEBUG: No x_response_code from server, ".
            "(HTTPS response: $server_response) ".
            "(HTTPS headers: ".
              join(", ", map { "$_ => ". $headers{$_} } keys %headers ). ") ".
            "(Raw HTTPS content: $page)"
          );
        }
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
      expiration     => '09/02',
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

Unlike Business::OnlinePayment or pre-3.0 verisons of
Business::OnlinePayment::AuthorizeNet, 3.1 requires separate first_name and
last_name fields.

To settle an authorization-only transaction (where you set action to
'Authorization Only'), submit the nine-digit transaction id code in
the field "order_number" with the action set to "Post Authorization".
You can get the transaction id from the authorization by calling the
order_number method on the object returned from the authorization.
You must also submit the amount field with a value less than or equal
to the amount specified in the original authorization.

Recently (February 2002), Authorize.Net has turned address
verification on by default for all merchants.  If you do not have
valid address information for your customer (such as in an IVR
application), you must disable address verification in the Merchant
Menu page at https://secure.authorize.net/ so that the transactions
aren't denied due to a lack of address information.

=head1 COMPATIBILITY

This module implements Authorize.Net's API verison 3.1 using the ADC
Direct Response method.  See
https://secure.authorize.net/docs/developersguide.pml for details.

=head1 AUTHOR

Jason Kohles, jason@mediabang.com

Ivan Kohler <ivan-authorizenet@420.am> updated it for Authorize.Net protocol
3.0/3.1 and is the current maintainer.

Jason Spence <jspence@lightconsulting.com> contributed support for separate
Authorization Only and Post Authorization steps and wrote some docs.
OST <services@ostel.com> paid for it.

=head1 SEE ALSO

perl(1). L<Business::OnlinePayment>.

=cut

