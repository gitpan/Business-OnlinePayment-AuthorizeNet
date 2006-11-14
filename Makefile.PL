use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'Business::OnlinePayment::AuthorizeNet',
    'VERSION_FROM' => 'AuthorizeNet.pm', # finds $VERSION
    'AUTHOR'       => 'Ivan Kohler <ivan-authorizenet@420.am>', #really just
                                                                #the maintainer
    'PREREQ_PM'    => { 'Net::SSLeay' => 0,
                        'Text::CSV_XS' => 0,
                        'Business::OnlinePayment' => 0,
			'Test::More' => 0.42,
                      },
);
