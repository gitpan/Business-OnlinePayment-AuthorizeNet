use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'Business::OnlinePayment::AuthorizeNet',
    'VERSION_FROM' => 'AuthorizeNet.pm', # finds $VERSION
    'AUTHOR'       => 'Ivan Kohler <ivan-authorizenet@420.am>', #really just
                                                                #the maintainer
    #'NORECURS'     => 1, # dont descend into subdirectories
    'PREREQ_PM'    => {'Net::SSLeay' => 0, 'Text::CSV' => 0},
    #'dist'         => {CI => 'ci -l'},
);
