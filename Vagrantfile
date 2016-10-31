# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER']='virtualbox'

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
  config.vm.box = "dmcc/alpine-3.4.5-docker-1.12.3-kubernetes-v1.4.5"

  if Vagrant.has_plugin?("vagrant-cachier")
      # Configure cached packages to be shared between instances of the same base box.
      # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
      config.cache.scope = :box
  end

  config.vm.define :master do |master01_config|
      master01_config.vm.network "private_network", ip:"10.250.250.2", auto_config: false
      # Can't use 192.168.100.1 - this is probably assigned to vagrant host as gw
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      master01_config.vm.provision :shell, path: "shared.sh", :privileged => true, env: {"SET_HOSTNAME" => "master.example.com"}
      master01_config.vm.provision :file, source: "canal.yaml", destination: "~/canal.yaml"
      master01_config.vm.provision :shell, path: "master.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token }
  end

  config.vm.define :minion01 do |minion01_config|
      minion01_config.vm.network "private_network", ip:"10.250.250.10"
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      minion01_config.vm.provision :shell, path: "shared.sh", :privileged => true
      minion01_config.vm.provision :shell, path: "minion.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token }
  end

  config.vm.define :minion02 do |minion02_config|
      minion02_config.vm.network "private_network", ip:"10.250.250.11"
      config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", "2"]   
      end  
      minion02_config.vm.provision :shell, path: "shared.sh", :privileged => true
      minion02_config.vm.provision :shell, path: "minion.sh", :privileged => true, env: { "KUBE_TOKEN" => cluster_token }
  end
end

