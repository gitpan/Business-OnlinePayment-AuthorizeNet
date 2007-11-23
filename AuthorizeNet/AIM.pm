package Business::OnlinePayment::AuthorizeNet::AIM;

use strict;
use Carp;
use Business::OnlinePayment::AuthorizeNet;
use Net::SSLeay qw/make_form post_https make_headers/;
use Text::CSV_XS;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter Business::OnlinePayment::AuthorizeNet);
@EXPORT = qw();
@EXPORT_OK = qw();
$VERSION = '3.18';

sub set_defaults {
    my $self = shift;

    $self->server('secure.authorize.net') unless $self->server;
    $self->port('443') unless $self->port;
    $self->path('/gateway/transact.dll') unless $self->path;

    $self->build_subs(qw( order_number md5 avs_code cvv2_response
                          cavv_response
                     ));
}

sub map_fields {
    my($self) = @_;

    my %content = $self->content();

    # ACTION MAP
    my %actions = ('normal authorization' => 'AUTH_CAPTURE',
                   'authorization only'   => 'AUTH_ONLY',
                   'credit'               => 'CREDIT',
                   'post authorization'   => 'PRIOR_AUTH_CAPTURE',
                   'void'                 => 'VOID',
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

    # ACCOUNT TYPE MAP
    my %account_types = ('personal checking'   => 'CHECKING',
                         'personal savings'    => 'SAVINGS',
                         'business checking'   => 'CHECKING',
                         'business savings'    => 'SAVINGS',
                        );
    $content{'account_type'} = $account_types{lc($content{'account_type'})}
                               || $content{'account_type'};

    $content{'referer'} = defined( $content{'referer'} )
                            ? make_headers( 'Referer' => $content{'referer'} )
                            : "";

    if (length $content{'password'} == 15) {
        $content{'transaction_key'} = delete $content{'password'};
    }

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
        type              => 'x_Method',
        login             => 'x_Login',
        password          => 'x_Password',
        transaction_key   => 'x_Tran_Key',
        action            => 'x_Type',
        description       => 'x_Description',
        amount            => 'x_Amount',
        currency          => 'x_Currency_Code',
        invoice_number    => 'x_Invoice_Num',
	order_number      => 'x_Trans_ID',
	auth_code         => 'x_Auth_Code',
        customer_id       => 'x_Cust_ID',
        customer_ip       => 'x_Customer_IP',
        last_name         => 'x_Last_Name',
        first_name        => 'x_First_Name',
        company           => 'x_Company',
        address           => 'x_Address',
        city              => 'x_City',
        state             => 'x_State',
        zip               => 'x_Zip',
        country           => 'x_Country',
        ship_last_name    => 'x_Ship_To_Last_Name',
        ship_first_name   => 'x_Ship_To_First_Name',
        ship_company      => 'x_Ship_To_Company',
        ship_address      => 'x_Ship_To_Address',
        ship_city         => 'x_Ship_To_City',
        ship_state        => 'x_Ship_To_State',
        ship_zip          => 'x_Ship_To_Zip',
        ship_country      => 'x_Ship_To_Country',
        phone             => 'x_Phone',
        fax               => 'x_Fax',
        email             => 'x_Email',
        email_customer    => 'x_Email_Customer',
        card_number       => 'x_Card_Num',
        expiration        => 'x_Exp_Date',
        cvv2              => 'x_Card_Code',
        check_type        => 'x_Echeck_Type',
	account_name      => 'x_Bank_Acct_Name',
        account_number    => 'x_Bank_Acct_Num',
        account_type      => 'x_Bank_Acct_Type',
        bank_name         => 'x_Bank_Name',
        routing_code      => 'x_Bank_ABA_Code',
        customer_org      => 'x_Customer_Organization_Type', 
        customer_ssn      => 'x_Customer_Tax_ID',
        license_num       => 'x_Drivers_License_Num',
        license_state     => 'x_Drivers_License_State',
        license_dob       => 'x_Drivers_License_DOB',
        recurring_billing => 'x_Recurring_Billing',
    );

    my $auth_type = $self->{_content}->{transaction_key}
                      ? 'transaction_key'
                      : 'password';

    my @required_fields = ( qw(type action login), $auth_type );

    unless ( $self->{_content}->{action} eq 'VOID' ) {

      if ($self->transaction_type() eq "ECHECK") {

        push @required_fields, qw(
          amount routing_code account_number account_type bank_name
          account_name
        );

        if (defined $self->{_content}->{customer_org} and
            length  $self->{_content}->{customer_org}
        ) {
          push @required_fields, qw( customer_org customer_ssn );
        } else {
          push @required_fields, qw(license_num license_state license_dob);
        }

      } elsif ($self->transaction_type() eq 'CC' ) {

        if ( $self->{_content}->{action} eq 'PRIOR_AUTH_CAPTURE' ) {
          if ( $self->{_content}->{order_number} ) {
            push @required_fields, qw( amount order_number );
          } else {
            push @required_fields, qw( amount card_number expiration );
          }
        } elsif ( $self->{_content}->{action} eq 'CREDIT' ) {
          push @required_fields, qw( amount order_number card_number );
        } else {
          push @required_fields, qw(
            amount last_name first_name card_number expiration
          );
        }
      } else {
        Carp::croak( "AuthorizeNet can't handle transaction type: ".
                     $self->transaction_type() );
      }

    }

    $self->required_fields(@required_fields);

    my %post_data = $self->get_fields(qw/
        x_Login x_Password x_Tran_Key x_Invoice_Num
        x_Description x_Amount x_Cust_ID x_Method x_Type x_Card_Num x_Exp_Date
        x_Card_Code x_Auth_Code x_Echeck_Type x_Bank_Acct_Num
        x_Bank_Account_Name x_Bank_ABA_Code x_Bank_Name x_Bank_Acct_Type
        x_Customer_Organization_Type x_Customer_Tax_ID x_Customer_IP
        x_Drivers_License_Num x_Drivers_License_State x_Drivers_License_DOB
        x_Last_Name x_First_Name x_Company
        x_Address x_City x_State x_Zip
        x_Country
        x_Ship_To_Last_Name x_Ship_To_First_Name x_Ship_To_Company
        x_Ship_To_Address x_Ship_To_City x_Ship_To_State x_Ship_To_Zip
        x_Ship_To_Country
        x_Phone x_Fax x_Email x_Email_Customer x_Country
        x_Currency_Code x_Trans_ID/);

    $post_data{'x_Test_Request'} = $self->test_transaction() ? 'TRUE' : 'FALSE';

    #deal with perl-style bool
    if (    $post_data{'x_Email_Customer'}
         && $post_data{'x_Email_Customer'} !~ /^FALSE$/i ) {
      $post_data{'x_Email_Customer'} = 'TRUE';
    } else {
      $post_data{'x_Email_Customer'} = 'FALSE';
    }

    $post_data{'x_ADC_Delim_Data'} = 'TRUE';
    $post_data{'x_delim_char'} = ',';
    $post_data{'x_encap_char'} = '"';
    $post_data{'x_ADC_URL'} = 'FALSE';
    $post_data{'x_Version'} = '3.1';

    my $pd = make_form(%post_data);
    my $s = $self->server();
    my $p = $self->port();
    my $t = $self->path();
    my $r = $self->{_content}->{referer};
    my($page,$server_response,%headers) = post_https($s,$p,$t,$r,$pd);
    #escape NULL (binary 0x00) values
    $page =~ s/\x00/\^0/g;

    #trim 'ip_addr="1.2.3.4"' added by eProcessingNetwork Authorize.Net compat
    $page =~ s/,ip_addr="[\d\.]+"$//;

    my $csv = new Text::CSV_XS({ binary=>1, escape_char=>'' });
    $csv->parse($page);
    my @col = $csv->fields();

    $self->server_response($page);
    $self->avs_code($col[5]);
    $self->order_number($col[6]);
    $self->md5($col[37]);
    $self->cvv2_response($col[38]);
    $self->cavv_response($col[39]);

    if($col[0] eq "1" ) { # Authorized/Pending/Test
        $self->is_success(1);
        $self->result_code($col[0]);
        if ($col[4] =~ /^(.*)\s+(\d+)$/) { #eProcessingNetwork extra bits..
          $self->authorization($2);
        } else {
          $self->authorization($col[4]);
        }
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

Business::OnlinePayment::AuthorizeNet::AIM - AuthorizeNet AIM backend for Business::OnlinePayment

=head1 AUTHOR

Jason Kohles, jason@mediabang.com

Ivan Kohler <ivan-authorizenet@420.am> updated it for Authorize.Net protocol
3.0/3.1 and is the current maintainer.  Please send patches as unified diffs
(diff -u).

Jason Spence <jspence@lightconsulting.com> contributed support for separate
Authorization Only and Post Authorization steps and wrote some docs.
OST <services@ostel.com> paid for it.

T.J. Mather <tjmather@maxmind.com> sent a number of CVV2 patches.

Mike Barry <mbarry@cos.com> sent in a patch for the referer field.

Yuri V. Mkrtumyan <yuramk@novosoft.ru> sent in a patch to add the void action.

Paul Zimmer <AuthorizeNetpm@pzimmer.box.bepress.com> sent in a patch for
card-less post authorizations.

Daemmon Hughes <daemmon@daemmonhughes.com> sent in a patch for "transaction
key" authentication as well support for the recurring_billing flag and the md5
method that returns the MD5 hash which is returned by the gateway.

Steve Simitzis contributed a patch for better compatibility with
eProcessingNetwork's AuthorizeNet compatability mode.

=head1 SEE ALSO

perl(1). L<Business::OnlinePayment> L<Business::OnlinePayment::AuthorizeNet>.

=cut

