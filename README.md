## Setup
```bash
git clone https://github.com/chmod666org/scaleway-k8s.git
cd scaleway-k8s/terraform
```

## Terraform
```bash
terraform apply
rm -rf ~/.ssh/known_hosts
ssh-keyscan $(terraform output -json public_ip | jq -r '.value[0]') > ~/.ssh/known_hosts
export ANSIBLE_HOST_KEY_CHECKING=false
export public_ip=$(terraform output -json public_ip | jq -r '.value[0]')
```

## Ansible
To install the k8s cluster run:
```bash
cd ..

ANSIBLE_HOST_KEY_CHECKING=false "scaleway_token=SCW_TOKEN scaleway_orga=SCW_ORGA basic_auth_user=MYUSER basic_auth_password=MYPASSWORD" ansible-playbook -i inventories/scaleway.inv k8s.yml
```

Replace:
  - SCW_TOKEN by your Scaleway token
  - SCW_ORGA by your Scaleway organization
  - basic_auth_user: by a username if you want the k8s dashboard to be protected by a basic auth
  - basic_auth_password: by a password if you want the k8s dashboard to be protected by a basi auth 

_scaleway_token_ and _scaleway_orga_ extra vars are only needed if you want an HA ingress. They allow _keepalived_ to move your Scaleway floating ip on a running proxy if one of the proxy fails.
_basic_auth_user_ and _basic_auth_password_ extra vars are only needed if you want the k8s dashbaord to be proctect by a basic_auth. Set basic_auth to True in roles/kubernetes_dashboard/defaults/main.yml to enable basic auth.

## Playbook development

### Local docker-in-docker
A docker-compose file and image utilizing the scaleway Ubuntu Xenial image is
provided for quick provisioning any to make it easier to test scenarios like
failover, unexpected node disconnections and adding new nodes to the cluster.

#### Mac OS
_**Or Linux if you don't want to affect the host kernel**_

A `Vagrantfile` is provided:
```bash
export VAGRANT_CONFIG_VM_NFS=1 # optional
vagrant up
vagrant ssh
```

Subsequent commands from the usage section should be executed in the `/vagrant`
folder of the VM.

#### Linux Native
The containers require several admin capabilities and various kernel modules to
be loaded: 
```bash
# enable ip forwarding (reset on reboot)
sudo sysctl -w net.ipv4.ip_forward=1

# load modules in the host kernel (reset on reboot)
echo "ip_vs nf_conntrack_ipv4 dm_thin_pool" | sudo xargs -n1 modprobe
```

#### Usage
Copy a composer from `docker/composers/*.yml` to the project root, name the file
`docker-compose.yml`, e.g.
```bash
cp docker/composers/multimaster.yml docker-compose.yml
```

**Generate the inventory and run the playbooks**

```bash
# prepare the containers
docker-compose build
bash docker/inventory.sh

# run the playbook
public_ip="127.0.0.1 -p 2222" ansible-playbook -i inventories/docker.yml main.yml
```

If you intend to recreate the environment repeatedly you may wish to paste the
following function and then call `sk8s_reset` whenever you need to:

```bash
sk8s_reset () {
    echo -n "Waiting for containers to be ready ... "
    docker-compose down -v --remove-orphans >/dev/null 2>&1
    docker-compose build >/dev/null 2>&1 
    docker/inventory.sh >/dev/null 2>&1
    echo "OK"
    public_ip="127.0.0.1 -p 2222" ansible-playbook -i inventories/docker.yml main.yml
}
```

#### Issues
- Pulling images sometimes hangs, if this happens you'll need to enter a
  container, e.g. `docker-compose exec master0 bash -l` and restart the docker
  daemon by running `systemctl restart docker` and then running the playbook
  again. Alternatively, restart docker on all containers by running:
  ```bash
  public_ip="127.0.0.1 -p 2222" ansible all -i inventories/docker.yml -a 'systemctl restart docker'
  ```
