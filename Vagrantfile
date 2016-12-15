# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER']='virtualbox'

CONFIG = File.expand_path("config.rb")
if File.exist?(CONFIG)
  require CONFIG
end

# create a randomn cluster token or read from cluster-token if exists
if File.exist?("cluster-token") 
  cluster_token=File.read("cluster-token")
else
  t1=`cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 6 | head -n 1`.chomp
  t2=`cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 16 | head -n 1`.chomp
  cluster_token="#{t1}.#{t2}"
  File.write("cluster-token", cluster_token)
end

Vagrant.configure(2) do |config|
config.ssh.insert_key = false
#config.vm.provider :virtualbox do |v|
#  v.check_guest_additions = false
#  v.functional_vboxsf     = false
#end
config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.box = "dmcc/alpine-3.4.6-docker-1.12.3-kubernetes-#{$kubernetes_version}"

  # disable vbguest updates as this does not work on alpine.
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  config.vm.define :master do |master01_config|
      master01_config.vm.network "private_network", ip:"10.250.250.2", auto_config: false
      master01_config.vm.network "forwarded_port", guest_ip: "127.0.0.1", guest: 8080, host: 8080
      # Can't use 192.168.100.1 - this is probably assigned to vagrant host as gw
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      master01_config.vm.provision :shell, path: "shared.sh", :privileged => true, env: {"SET_HOSTNAME" => "master.example.com"}
      #master01_config.vm.provision :file, source: "canal.yaml", destination: "~/canal.yaml"
      master01_config.vm.provision :shell, path: "master.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token, "KUBERNETES_VERSION" => $kubernetes_version  }
  end

  config.vm.define :minion01 do |minion01_config|
      minion01_config.vm.network "private_network", ip:"10.250.250.10", auto_config: false

      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      minion01_config.vm.provision :shell, path: "shared.sh", :privileged => true, env: {"SET_HOSTNAME" => "minion01.example.com"}
      minion01_config.vm.provision :shell, path: "minion.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token }
  end

  config.vm.define :minion02 do |minion02_config|
      minion02_config.vm.network "private_network", ip:"10.250.250.11", auto_config: false
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      minion02_config.vm.provision :shell, path: "shared.sh", :privileged => true, env: {"SET_HOSTNAME" => "minion02.example.com"}
      minion02_config.vm.provision :shell, path: "minion.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token }
  end
end

