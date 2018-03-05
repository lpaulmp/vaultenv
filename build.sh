#!/bin/bash

function bootstrap() {
  if [ ! -d "build" ]; then
      echo ":: Creating chroot for building.."
      sudo debootstrap --variant=buildd --arch=amd64 xenial $(pwd)/chroot http://archive.ubuntu.com/ubuntu
	fi

}

function mount_filesystems() {
  sudo mount -t proc proc  ./chroot/proc
  sudo mount --rbind /dev  ./chroot/dev
  sudo mount --make-rslave ./chroot/dev
  sudo mount --rbind /sys  ./chroot/sys
  sudo mount --make-rslave ./chroot/sys
}

function shell_config() {
	sudo tee ./chroot/root/.bashrc << EOF
# If not running interactively, don't do anything
[ -z "$PS1" ] && return
EOF

	sudo tee ./chroot/root/.profile <<'EOF'
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

export TERM="xterm"
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
}

function setup() {
  sudo tee ./chroot/setup.sh <<'EOF'
#!/bin/bash
apt install tee

tee > /etc/apt/sources.list << EOS
deb http://archive.ubuntu.com/ubuntu xenial main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu xenial-backports main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu xenial-security main restricted universe multiverse
EOS

cat /etc/apt/sources.list

apt update
apt install -y netbase
apt install -y ca-certificates
apt install -y curl
apt install -y gettext

cd
curl -sSL https://get.haskellstack.org/ | sh
EOF

  sudo chmod +x ./chroot/setup.sh
  in_chroot "/setup.sh"
}

function remove() {
  sudo umount ./chroot/proc
  sudo umount -R ./chroot/dev
  sudo umount -R ./chroot/sys
  sudo umount ./chroot/root/vaultenv

  sudo rm -rf ./chroot
}

function in_chroot() {
  sudo chroot \
    --userspec=root:root \
    ./chroot \
    /usr/bin/env -i \
    HOME=/root \
    USER=root \
    /bin/bash -l $1
}

function mount_source_dir() {
  if ! sudo test -f "./chroot/root/vaultenv/LICENSE"; then
    sudo mkdir ./chroot/root/vaultenv
    sudo mount --bind ./vaultenv ./chroot/root/vaultenv
  fi
}

case "$1" in
  create)
      bootstrap
      mount_filesystems
			shell_config
      setup
      ;;

  rerun-setup)
			shell_config
      setup
      ;;

  shell)
      mount_source_dir
      in_chroot $2
      ;;

  package)
      mount_source_dir
      in_chroot "/root/vaultenv/package/build_package.sh"
      ;;

  remove)
      remove
      ;;
  *)
      echo "Usage: ./build.sh {create|rerun-setup|chroot|remove}"
      exit 1
esac
