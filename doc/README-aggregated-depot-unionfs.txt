--------------------------------------------------------------------------------------------------

** Our objective: Prevent mixing up custom related files with OPSI packages

   If you install OPSI packages on the OPSI-Server, they will be
   extracted to /opt/pcbin/install. For some packages it's necessary to place 
   customized files inside this area (e.g. /opt/pcbin/install/<program>/custom/myconfig.cfg)
   In this situation, OPSI-packages are mixed up with private/individual files. This
   could be a problem for maintenance, update or privacy reason.

** Solution: Separation of custom files

   To separate the OPSI-packages from the custom files, we setup a unionfs filesystem and 
   publish two directories as one, read-only aggregation filesystem.

---------------------------------------------------------------------------------------------------


** Installation of unionfs-fuse on a centos system

   # Prerequirements for compiling  unionfs
     yum install gcc
     yum install fuse
     yum install fuse-devel

   # Downloading and installing unionfs
     wget http://podgorny.cz/unionfs-fuse/releases/unionfs-fuse-0.24.tar.bz2
     tar xfvj unionfs-fuse-0.24.tar.bz2
     cd unionfs-fuse-0.24
     make
     make install

   # automatically loading the module
     /etc/modprobe.d/fuse.conf
	install fuse /sbin/modprobe fuse; /sbin/modprobe fuse
     modprobe fuse


** Configure the aggreeagated OPSI depot
   # Create a depot directory containing the customized files. 
   mkdir /srv/opsi/depot.custom

   # mount the new, aggregated depot to a new mountpoint
     mkdir /dynamic/opsi-depot.unionfs

     # Mount example1: 
     unionfs -o max_files=32768 \
	        -o allow_other,use_ino,suid,dev,nonempty \
                /srv/opsi/depot.custom=RO:/opt/pcbin/install=RO \
                /dynamic/opsi-depot.unionfs

     # Mount example2: 
     mount -t fuse  -o max_files=32768 \
               -o allow_other,use_ino,suid,dev,nonempty \
               unionfs\#/srv/opsi/depot.custom=RO:/opt/pcbin/install=RO \
               /dynamic/opsi-depot.unionfs

     # Automount aggreeagated depot by fstab
     /etc/fstab
	unionfs#/srv/opsi/depot.custom=RO:/opt/pcbin/install=RO    /dynamic/opsi-depot.unionfs     fuse    allow_other,use_ino,suid,dev,nonempty,max_files=32768    0 0


     # check, if you can access the new filesystem
     ls -la /dynamic/opsi-depot.unionfs


** check functionallay using the swdaudit project
     # create a custom file an validate the aggregated filesystem
     touch /srv/opsi/depot.custom/MY_INDIVIDUAL_FILE.txt

     # checks
     ls /opt/pcbin/install/swaudit
     ls /dynamic/opsi-depot.unionfs

     rm /srv/opsi/depot.custom/MY_INDIVIDUAL_FILE.txt
     

** setup samba to use this new filesystem
   /etc/samba/smb.conf
	[opsi_depot]
	   available = yes
	   comment = opsi depot share (ro)
	;  path = /var/lib/opsi/depot
	   path = /dynamic/opsi-depot.unionfs
	   oplocks = no
	   level2 oplocks = no
	   writeable = no
	   invalid users = root

   service smb restart


   # Testing using a OPSI client PC
   On a windows client PC. connect to the OPSI depot networkshare
   \\<opsi-server\opsi_depot and check the directory swaudit\custom. You
   should have read-only access to the test file MY_INDIVIDUAL_FILE.txt
   located in the individual/private directory on the OPSI-server.



--------------------------------------------------------------------------------------------------
