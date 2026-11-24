# The CKA practice cluster: one control plane and two workers, Ubuntu 24.04.
#   vagrant up                 build all three (runs node-setup.sh on each)
#   vagrant ssh cp1            log in to the control plane (or worker1, worker2)
#   vagrant halt               shut them down, keeping everything
#   vagrant destroy -f         delete them, to start over
#
# node-setup.sh prepares each machine but does NOT create the cluster.
# Creating it with kubeadm is the lesson.
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provision "shell", path: "node-setup.sh"

  NODES = { "cp1" => 2048, "worker1" => 2048, "worker2" => 2048 }

  NODES.each do |name, memory|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.provider "vmware_desktop" do |v|
        v.memory = memory
        v.cpus = 2                       # kubeadm refuses a control plane with fewer than 2
        v.vmx["ethernet0.pcislotnumber"] = "160"
      end
      node.vm.provider "virtualbox" do |v|
        v.memory = memory
        v.cpus = 2
      end
    end
  end
end
