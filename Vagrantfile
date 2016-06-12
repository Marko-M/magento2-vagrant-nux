# -*- mode: ruby -*-
# vi: set ft=ruby :

# https://github.com/Marko-M/magento2-vagrant-nux
# Marko Martinović (http://www.techytalk.info)

overrides = "#{__FILE__}.local"
if File.exist?(overrides)
    eval File.read(overrides)
end

# Defaults
DOMAIN ||= 'vagrant.loc'
IP ||= '192.168.56.6'
RAM ||= '2048'
CPU ||= '2'
MYSQL_DBNAME ||= 'vagrant'
MYSQL_USER ||= 'vagrant'
MYSQL_PASSWORD ||= 'vagrant'
MAGENTO_INSTALL ||= 'Y'
MAGENTO_LANGUAGE ||= 'en_US'
MAGENTO_CURRENCY ||= 'USD'
MAGENTO_SAMPLE_DATA ||= 'Y'
AUTH_NAME ||= ''
AUTH_PASS ||= ''
TIMEZONE ||= 'America/Los_Angeles'
VARNISH ||= 'N'

Vagrant.configure(2) do |config|
    config.vm.box = "ubuntu/trusty64"
    config.vm.box_check_update = true

    # Set hostname
    config.vm.hostname = DOMAIN

    # Private network due to NFS
    config.vm.network "private_network", ip: IP

    nfs_mount_options = [
        "auto",
        "noatime",      # Performance
        "nodiratime",   # Performance
        "noacl",        # Performance
        "hard",
        "intr",
        "vers=4"
    ]

    nfs_exports_args = [
        "rw",
        "async",
        "no_subtree_check",
    ]

    # Home directory share
    # fsid=0 - in order to use NFSv4, shares parent must be shared as well
    # fsc - enable fc-cache.
    config.vm.synced_folder "~",
        "/home/vagrant/host",
        nfs: true,
        :mount_options => nfs_mount_options+['fsc'],
        :linux__nfs_options => nfs_exports_args+['fsid=0'],
        :map_uid => Process.uid,
        :map_gid => Process.gid

    # Document root share
    config.vm.synced_folder ".",
        "/home/vagrant/public_html",
        nfs: true,
        :mount_options => nfs_mount_options,
        :linux__nfs_options => nfs_exports_args,
        :map_uid => Process.uid,
        :map_gid => Process.gid

    config.vm.provider "virtualbox" do |vb|

    #   # Display the VirtualBox GUI when booting the machine
    #   vb.gui = true
    #

    # Customize the amount of memory on the VM:
    vb.customize ["modifyvm", :id, "--memory", RAM]
    # Customize the number of CPUs on the VM:
    vb.customize ["modifyvm", :id, "--cpus", CPU]

    # Required for 64 bit guest
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    end

    # Setup Vagrant Cachier (saves bandwidth when re-provisioning)
    if Vagrant.has_plugin?("vagrant-cachier")
        # Configure cached packages to be shared between instances of the same base box.
        config.cache.scope = :box
    end


    # Setup Vagrant Hosts Updater (updates /etc/hosts and hostname)
    if Vagrant.has_plugin?("vagrant-hostsupdater")
        config.hostsupdater.aliases = ["#{DOMAIN}", "phpmyadmin.#{DOMAIN}"]
    end

    # Install stack
    config.vm.provision "shell" do |s|
        s.path = "vagrant/provision.sh"
        s.args = [
            DOMAIN,             #1
            MYSQL_DBNAME,       #2
            MYSQL_USER,         #3
            MYSQL_PASSWORD,     #4
            TIMEZONE,           #5
            VARNISH,            #6
        ]
    end

    # Install Magento if requested and if possible
    if MAGENTO_INSTALL == 'Y' && AUTH_NAME != '' && AUTH_PASS != ''
        config.vm.provision "shell" do |s|
            s.path = "vagrant/install_magento.sh"
            s.args = [
                TIMEZONE,           #1
                MAGENTO_LANGUAGE,   #2
                MAGENTO_CURRENCY,   #3
                MAGENTO_SAMPLE_DATA,#4
                AUTH_NAME,          #5
                AUTH_PASS,          #6
                DOMAIN,             #7
                VARNISH,            #8
                MYSQL_DBNAME,       #9
                MYSQL_USER,         #10
                MYSQL_PASSWORD,     #11
            ]
            s.privileged = false
        end
    end
end

