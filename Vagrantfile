# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER']='virtualbox'
MASTER_LB_IP="10.250.250.2" # Load balanced VIP/IP for the master API

# Defaults
$master_cpu=1
$master_memory=1024
$minion_cpu=1
$minion_memory=2048

CONFIG = File.expand_path("config.rb")
if File.exist?(CONFIG)
  require CONFIG
end

# create a random cluster token or read from cluster-token if exists
if File.exist?("cluster-token") 
  cluster_token=File.read("cluster-token")
else
  t1=`cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 6 | head -n 1`.chomp
  t2=`cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 16 | head -n 1`.chomp
  cluster_token="#{t1}.#{t2}"
  File.write("cluster-token", cluster_token)
end

def minionIP(num)
  return "10.250.250.#{num+9}"
end

def masterIP(num)
  return "10.250.250.#{num+1}"
end

Vagrant.configure(2) do |config|
config.ssh.insert_key = false
#config.vm.provider :virtualbox do |v|
#  v.check_guest_additions = false
#  v.functional_vboxsf     = false
#end
config.vm.synced_folder ".", "/vagrant", disabled: true
config.vm.box = "dmcc/alpine-3.5.0-docker-1.12.6-kubernetes-#{$kubernetes_version}"

  # disable vbguest updates as this does not work on alpine.
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  (1..$master_count).each do |i|
    config.vm.define vm_name = "master#{i}" do |master|

      master.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", $master_memory]
        vb.customize ["modifyvm", :id, "--cpus", $master_cpu]   
      end

      masterIP = masterIP(i)
      master.vm.network :private_network, ip: masterIP, auto_config: false
      master.vm.network "forwarded_port", guest_ip: "127.0.0.1", guest: 8080, host: 8080

      master.vm.provision :shell, path: "shared.sh", :privileged => true, env: { "SET_HOSTNAME": "master#{i}.example.com", "MY_IP": masterIP }
      master.vm.provision :shell, path: "master.sh", :privileged => true, env: { "KUBE_TOKEN": cluster_token, "KUBERNETES_VERSION": $kubernetes_version,
	 "MY_IP": masterIP, "MASTER_LB_IP": MASTER_LB_IP }
    end
  end

  (1..$minion_count).each do |i|
    config.vm.define vm_name = "minion#{i}" do |minion|

      minion.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", $minion_memory]
        vb.customize ["modifyvm", :id, "--cpus", $minion_cpu]   
      end

      minionIP = minionIP(i)
      minion.vm.network :private_network, ip: minionIP, auto_config: false

      minion.vm.provision :shell, path: "shared.sh", :privileged => true, env: { "SET_HOSTNAME": "minion#{i}.example.com", "MY_IP": minionIP }
      minion.vm.provision :shell, path: "minion.sh", :privileged => true, env: { "KUBE_TOKEN": cluster_token, "MASTER_LB_IP": MASTER_LB_IP }
    end
  end
end

