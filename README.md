# cka-practice

Labs for the CKA prep track on [kwamib.dev](https://kwamib.dev/resources/cka):
a three-machine Kubernetes cluster you build yourself with kubeadm, as close
to the Certified Kubernetes Administrator exam's clusters as you can get for free.

You need [Vagrant](https://developer.hashicorp.com/vagrant) and VMware Fusion
or VirtualBox. The three machines use about 6 GB of
memory between them.

    vagrant up            # builds cp1, worker1 and worker2 (about 10 minutes)
    vagrant ssh cp1       # then follow the lesson to create the cluster
    vagrant destroy -f    # start over

`node-setup.sh` prepares each machine (swap, kernel modules, containerd,
kubeadm at v1.34) but leaves creating the cluster to you. That part is the lesson:
[A practice cluster: three machines with kubeadm](https://kwamib.dev/resources/cka/a-practice-cluster).
