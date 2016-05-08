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
MYSQL_DBNAME ||= 'vagrant'
MYSQL_USER ||= 'vagrant'
MYSQL_PASSWORD ||= 'vagrant'
MAGENTO_INSTALL ||= true
MAGENTO_TIMEZONE ||= 'America/Los_Angeles'
MAGENTO_LANGUAGE ||= 'en_US'
MAGENTO_CURRENCY ||= 'USD'
MAGENTO_SAMPLE_DATA ||= 'Y'
AUTH_NAME ||= ''
AUTH_PASS ||= ''
TIMEZONE ||= 'America/Los_Angeles'

Vagrant.configure(2) do |config|
    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://atlas.hashicorp.com/search.
    config.vm.box = "ubuntu/trusty64"

    # Disable automatic box update checking. If you disable this, then
    # boxes will only be checked for updates when the user runs
    # `vagrant box outdated`. This is not recommended.
    config.vm.box_check_update = true

    # Set hostname
    config.vm.hostname = DOMAIN

    # Private network due to NFS
    config.vm.network "private_network", ip: "192.168.56.6"

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

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    # config.vm.synced_folder "../data", "/vagrant_data"

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

    # Provider-specific configuration so you can fine-tune various
    # backing providers for Vagrant. These expose provider-specific options.
    # Example for VirtualBox:
    #
    config.vm.provider "virtualbox" do |vb|
    #   # Display the VirtualBox GUI when booting the machine
    #   vb.gui = true
    #
    # Customize the amount of memory on the VM:
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    # Customize the number of CPUs on the VM:
    vb.customize ["modifyvm", :id, "--cpus", "2"]

    # Required for 64 bit guest
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    end

    # Setup Vagrant Cachier (saves bandwidth when re-provisioning)
    if Vagrant.has_plugin?("vagrant-cachier")
        # Configure cached packages to be shared between instances of the same base box.
        config.cache.scope = :box
    end

    # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
    # such as FTP and Heroku are also available. See the documentation at
    # https://docs.vagrantup.com/v2/push/atlas.html for more information.
    # config.push.define "atlas" do |push|
    #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
    # end

    # Enable provisioning with a shell script. Additional provisioners such as
    # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
    # documentation for more information about their specific syntax and use.
    # config.vm.provision "shell", inline <<-SHELL
    #   sudo apt-get install apache2
    # SHELL
    config.vm.provision "shell" do |s|
        s.path = "vagrant/provision.sh"
        s.args = [
            DOMAIN,             #1
            MYSQL_DBNAME,       #2
            MYSQL_USER,         #3
            MYSQL_PASSWORD,     #4
            TIMEZONE,           #5
        ]
    end

    if MAGENTO_INSTALL == 'Y'
        config.vm.provision "shell" do |s|
            s.path = "vagrant/install_magento.sh"
            s.args = [
                MAGENTO_TIMEZONE,   #1
                MAGENTO_LANGUAGE,   #2
                MAGENTO_CURRENCY,   #3
                MAGENTO_SAMPLE_DATA,#4
                AUTH_NAME,          #5
                AUTH_PASS,          #6
                DOMAIN,             #7
            ]
            s.privileged = false
        end
    end
end

