- the 7zip version in CentOS does include all features.
  You can install the version from sf.net

  wget "https://sourceforge.net/projects/p7zip/files/p7zip/9.20.1/p7zip_9.20.1_x86_linux_bin.tar.bz2/download"
  tar xfvj p7zip_9.20.1_x86_linux_bin.tar.bz2 
  cd p7zip_9.20.1*

  sh install.sh
  emacs -nw /etc/profile
          PATH=/usr/local/bin:$PATH
          export PATH
  source /etc/profile
