# Vagrant

## Prerequisites

Please install the following:

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)

### General

1. Install `vagrant` as per <https://developer.hashicorp.com/vagrant/downloads>
2. Configure a provider
3. Run `vagrant up` and then `vagrant ssh`

### MacOS

```bash
brew cask install virtualbox
brew cask install vagrant
```

### ARM hosts (Apple M1, and so on)

You'll need to use QEMU instead of VirtualBox to use Vagrant on ARM. The following instructions will assume an M1 Mac as the host:

1. Install QEMU: `brew install qemu`
2. Install the QEMU vagrant provider: `vagrant plugin install vagrant-qemu`
3. Provision the VM with the provider: `vagrant up --provider=qemu`

## Setting up

You can set up the Vagrant environment with just one command:

```bash
vagrant up
```

After successfull installation you can ssh to the virtual machine with:

```bash
vagrant ssh
```

NOTICE: The directory with fluentd-output-sumologic repository on the host is synced with `/sumologic/` directory on the virtual machine.

## Runing tests

You can run tests using following commands:

```bash
cd /sumologic
bundle install
bundle exec rake
```
