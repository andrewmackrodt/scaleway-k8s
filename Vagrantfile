# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  if ! File.exists?(".env")
    begin
      require "dotenv"
      Dotenv.load "vagrant.env"
    rescue LoadError
      $stderr.puts "Could not load .env file because dotenv is not installed.\nRun `gem install dotenv` or `vagrant plugin install vagrant-env`."
      exit
    end
  end

  config.vm.box = "ubuntu/xenial64"

  config.vm.network "forwarded_port", guest: 80  , host: 8080, auto_correct: true
  config.vm.network "forwarded_port", guest: 443 , host: 8443, auto_correct: true

  # use nfs if specified by config or the mac or daemon is running and not disallowed by config
  nfs_env=ENV.fetch('VAGRANT_CONFIG_VM_NFS') { "" }
  nfs_enabled=0
  synced_folder_options = {}
  unless nfs_env.match(/^(0|off|false|no)$/)
    if nfs_env.match(/^(1|on|true|yes)$/) or `ps aux | grep [n]fsd` != ''
      synced_folder_options[:type] = "nfs"
      synced_folder_options[:mount_options] = ["rw", "vers=3", "tcp", "fsc"]
      nfs_enabled=1
    end
  end

  config.vm.synced_folder ".", "/vagrant", synced_folder_options

  # allocate 1/4 memory and all cpus
  host = RbConfig::CONFIG['host_os']
  if host =~ /darwin/
    cpus = ENV.fetch('VAGRANT_CONFIG_VM_CPUS'  ) { `sysctl -n hw.ncpu`.to_i }
    mem  = ENV.fetch('VAGRANT_CONFIG_VM_MEMORY') { `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4 }
  elsif host =~ /linux/
    cpus = ENV.fetch('VAGRANT_CONFIG_VM_CPUS'  ) { `nproc`.to_i }
    mem  = ENV.fetch('VAGRANT_CONFIG_VM_MEMORY') { `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4 }
  else
    cpus = ENV.fetch('VAGRANT_CONFIG_VM_CPUS'  ) { `wmic cpu get NumberOfCores`.split("\n")[2].to_i }
    mem  = ENV.fetch('VAGRANT_CONFIG_VM_MEMORY') { `wmic OS get TotalVisibleMemorySize`.split("\n")[2].to_i / 1024 / 4 }
  end

  config.vm.provider "virtualbox" do |p, override|
    p.customize ["modifyvm", :id, "--memory", mem]
    p.customize ["modifyvm", :id, "--cpus", cpus]
    p.customize ["modifyvm", :id, "--audio", "none"]

    override.vm.network "private_network", type: "dhcp"
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope ||= :machine
  end

  config.vm.provision "kernel", type: "shell", inline: <<-BASH
    sed -i -E "s/^#(net.ipv4.ip_forward=1)/\1/" /etc/sysctl.conf
    sysctl -w net.ipv4.ip_forward=1

    for m in ip_vs nf_conntrack_ipv4 dm_thin_pool; do
      if ! `grep -q "$m" /etc/modules`; then
        echo "$m" >> /etc/modules
      fi

      modprobe "$m"
    done
  BASH

  if nfs_enabled
    config.vm.provision "cachefilesd", type: "shell", inline: <<-BASH
      if ! `cachefilesd --version >/dev/null 2>&1`; then
        apt install -qqy cachefilesd
      fi
      if ! `grep -q -E "^RUN=yes" /etc/default/cachefilesd`; then
        sed -i -E "s/^#(RUN=yes)/\1/" /etc/default/cachefilesd
        systemctl restart cachefilesd
      fi
    BASH
  end

  config.vm.provision "docker", type: "shell", inline: <<-BASH
    if ! `docker --version >/dev/null 2>&1`; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      apt update -qqy
      apt install -qqy docker-ce
    fi

    usermod -aG docker ubuntu

    if ! `docker-compose --version >/dev/null 2>&1`; then
      curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
    fi
  BASH

  config.vm.provision "ansible", type: "shell", inline: <<-BASH
    if ! `ansible --version >/dev/null 2>&1`; then
      apt install -qqy python-pip
      pip install ansible
    fi
  BASH

  config.vm.provision "boot", type: "shell", privileged: false, run: "always", inline: <<-BASH
    if [ ! -f ~/.ssh/id_rsa ]; then
      ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
    fi
    cd /vagrant
    if [ -f docker-compose.yml ]; then
      docker-compose up -d
    fi
  BASH
end
