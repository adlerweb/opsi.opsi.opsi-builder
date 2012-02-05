- the 7zip version in CentOS does include all features.
  You can install the version from sf.net

  # 32 bit  - binary package
  wget "https://sourceforge.net/projects/p7zip/files/p7zip/9.20.1/p7zip_9.20.1_x86_linux_bin.tar.bz2/download"
  tar xfvj p7zip_9.20.1_x86_linux_bin.tar.bz2 
  cd p7zip_9.20.1*
  sh install.sh

  # 64bit - build from scratch
  wget "http://downloads.sourceforge.net/project/p7zip/p7zip/9.20.1/p7zip_9.20.1_src_all.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fp7zip%2Ffiles%2Fp7zip%2F9.20.1%2F&ts=1328454155&use_mirror=kent"
  yum install gcc-c++ 
  make all_test
  make install

  emacs -nw /etc/profile
          PATH=/usr/local/bin:$PATH
          export PATH
  source /etc/profile
