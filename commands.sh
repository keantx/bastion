#!/bin/bash

fn_setup_all() {

    # fundamental tools
    fn_extract_data_dir
    fn_fix_sshd # this have to be done before any APT installation (order matters)
    fn_fix_sudo
    fn_update_system
    fn_install_session
    fn_install_apt_tooling

    # security fixes
    fn_configure_login_umask

    fn_(redacted)_configuration
    fn_set_sshd_keys

    # install EIT developed tools
    fn_install_dotnet_dependencies
    fn_install_eit_tool sqltool '2.5.4'
    fn_install_eit_tool cosmos-explorer '1.1.0'
    fn_install_eit_tool servicebus-cleaner '1.1.0'
    fn_install_eit_tool eventhub-publish '1.0.1'

    # user tools
    fn_apt_common_tools
    fn_install_kubectl '1.29'
    fn_install_kubelogin '0.1.1'
    fn_install_kubectx_kubens '0.9.5'
    fn_install_k9s '0.32.5'
    fn_install_azure_cli
    fn_install_azcopy
    fn_install_blob_fuse
    apt-get install -y python3-pip python3-venv
    python3 -m venv /opt/venv
    /opt/venv/bin/pip install --no-cache-dir azure-servicebus azure-cosmos yq
    ln -sf /opt/venv/bin/yq /usr/local/bin/yq
    # fn_install_mongo '8.0' # disabled, not yet supported for ubuntu 26.04 per 202611
    fn_install_helm
    fn_install_postgresql
    fn_install_redis
    fn_install_flux_cli '2.1.2'
}

# extract data directory from the tarball
fn_extract_data_dir() {
    tar xz -C /tmp -f /tmp/data.tar.gz
    rm /tmp/data.tar.gz
    chown -R root:root /tmp/data
    chmod -R 0644 /tmp/data
    echo 'data dir extracted:'
    find /tmp/data -type f
}

fn_fix_sshd() {
    # do not update SSHD service - apt-get might try to update it as an dependency of other packages and would get stuck in configuration conflicts
    apt-mark hold openssh-server

    # fix vulnerability https://blog.qualys.com/vulnerabilities-threat-research/2024/07/01/regresshion-remote-unauthenticated-code-execution-vulnerability-in-openssh-server
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # Set LoginGraceTime to 0
    if grep -q "^LoginGraceTime" $SSHD_CONFIG; then
        sed -i 's/^LoginGraceTime.*/LoginGraceTime 0/' $SSHD_CONFIG
    else
        echo "LoginGraceTime 0" >> $SSHD_CONFIG
    fi
}

fn_fix_sudo() {
    sudo apt-get update || {
        echo "Failed to update package metadata"
        exit 5
    }

    sudo apt-get install -y --only-upgrade sudo || {
        echo "Failed to upgrade sudo"
        exit 5
    }

    dpkg-query -W -f='${Version}\n' sudo || {
        echo "Failed to verify sudo installation"
        exit 5
    }

    # Hold sudo to prevent automatic upgrades
    sudo apt-mark hold sudo
}

fn_install_mongo() {
    set -euo pipefail
    local version="${1:-8.0}"
    local codename="$(lsb_release -cs)"
    local keyring="/usr/share/keyrings/mongodb-org-${version}.gpg"

    curl -fsSL "https://www.mongodb.org/static/pgp/server-${version}.asc" \
      | sudo gpg --dearmor --yes -o "$keyring"

    gpg --show-keys --with-colons "$keyring" | grep -q 'F366D55B602E502D' \
      || echo "WARN: expected signing key not in keyring" >&2

    echo "deb [arch=amd64,arm64 signed-by=${keyring}] https://repo.mongodb.org/apt/ubuntu ${codename}/mongodb-org/${version} multiverse" \
      | sudo tee "/etc/apt/sources.list.d/mongodb-org-${version}.list"

    sudo apt-get update
    sudo apt-get install -y mongodb-mongosh
}

fn_install_apt_tooling() {
    apt-get update
    apt-get install -y apt-transport-https gnupg2
}

fn_update_system() {
    apt-get update
    apt-get upgrade -y
}

fn_install_kubectl() {
    local version="$1"

    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$version/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$version/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubectl
    apt-mark hold kubectl

    ln -s /usr/bin/kubectl /usr/bin/k

    kubectl completion bash > /etc/bash_completion.d/kubectl
    chmod 0644 /etc/bash_completion.d/kubectl
    echo 'complete -o default -F __start_kubectl k' >> /etc/profile.d/k_completion.sh
    chmod 0644 /etc/profile.d/k_completion.sh
}

fn_install_kubelogin() {
    local version="$1"
    apt-get update
    apt-get install -y unzip
    local tmp_dir=$(mktemp -d)
    wget -O "$tmp_dir/kubelogin-linux-amd64.zip" https://github.com/Azure/kubelogin/releases/download/v${version}/kubelogin-linux-amd64.zip

    unzip "$tmp_dir/kubelogin-linux-amd64.zip"
    sudo mv bin/linux_amd64/kubelogin /usr/bin
    rm -rf "$tmp_dir"
}

fn_install_azure_cli() {
    # add APT repository
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list
    apt-get update

    # install
    apt-get install -y azure-cli
}

fn_install_helm() {
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    helm completion bash > /etc/bash_completion.d/helm
    chmod 0644 /etc/bash_completion.d/helm
}

fn_yellow_echo() {
    echo -e "\e[33m$*\e[0m"
}
fn_green_echo() {
    echo -e "\e[32m$*\e[0m"
}
fn_red_echo() {
    echo -e "\e[31m$*\e[0m"
}

fn_install_eit_tool() {
    local tool_name="$1"
    local version="$2"
    local platform='linux-x64'
    local url_tgz="https://(redacted).blob.core.windows.net/releases/$tool_name/$version/$tool_name-$version-$platform.tgz"
    local url_sha="https://(redacted).blob.core.windows.net/releases/$tool_name/$version/$tool_name-$version-$platform.tgz.sha256"

    # write yellow header message
    fn_yellow_echo "Installing $tool_name $version"

    local tmp_dir=$(mktemp -d)
    wget --show-progress=off -O "$tmp_dir/$tool_name.tgz" "$url_tgz?$RELEASES_KEY"
    tar -C "$tmp_dir" -xzvf "$tmp_dir/$tool_name.tgz"

    chown -R root:root "$tmp_dir"
    chmod -R 755 "$tmp_dir"
    local target_dir="/usr/local/bin/$tool_name-$platform"
    local exec_path="/usr/local/bin/$tool_name-$platform/$tool_name"
    mv "$tmp_dir/$tool_name-$platform" "$target_dir"

    mkdir -p /var/log/$tool_name
    chown root:users /var/log/$tool_name
    chmod 733 /var/log/$tool_name

    if [ -f "$exec_path" ]; then
        chmod 755 "$exec_path"
        ln -s "$exec_path" "/usr/local/bin/$tool_name"
        fn_green_echo "$tool_name $version successfully installed"
    else
        fn_red_echo "$tool_name $version installation failed" >&2
        exit 1
    fi
}

fn_install_azcopy() {
    local tmp_dir=$(mktemp -d)
    local target_path='/usr/local/bin/azcopy'

    wget -O "$tmp_dir/azcopy.tar.gz" https://aka.ms/downloadazcopy-v10-linux
    tar -C "$tmp_dir" -xzvf "$tmp_dir/azcopy.tar.gz"
    mv $(find "$tmp_dir" -type f -name azcopy) "$target_path"

    chown root:root "$target_path"
    chmod 755 "$target_path"
}

fn_install_redis() {
    apt-get install -y redis-tools
    apt-get install -y stunnel4
}

fn_install_k9s() {
    local version="$1"
    local tmp_dir=$(mktemp -d)

    fn_yellow_echo "Installing k9s ${version} (deb)"

    wget -O "$tmp_dir/k9s.deb" \
      "https://github.com/derailed/k9s/releases/download/v${version}/k9s_linux_amd64.deb"

    apt-get install -y "$tmp_dir/k9s.deb"
    rm -rf "$tmp_dir"
}

fn_install_flux_cli() {
    local version="$1"
    local tmp_path=$(mktemp)
    local tmp_dir=$(mktemp -d)
    wget -O "$tmp_path" "https://github.com/fluxcd/flux2/releases/download/v${version}/flux_${version}_linux_amd64.tar.gz"
    tar -C "$tmp_dir" -xzf "$tmp_path"
    mv $(find "$tmp_dir" -type f -name flux) /usr/local/bin/flux
    chown root:root /usr/local/bin/flux
    chmod 755 /usr/local/bin/flux
    rm -f "$tmp_path"
    rm -rf "$tmp_dir"

    flux completion bash > /etc/bash_completion.d/flux
    chmod 0644 /etc/bash_completion.d/flux
}

fn_install_blob_fuse() {
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    apt-get update
    apt-get install -y fuse3 blobfuse2
    ln -sf /usr/bin/blobfuse2 /usr/bin/blobfuse
}

fn_install_session() {
    mkdir /var/log/session
    chmod 333 /var/log/session
    wget https://(redacted).blob.core.windows.net/script/script_2.37.1-16_amd64.deb
    dpkg --force-all -i script_2.37.1-16_amd64.deb
}

fn_install_postgresql() {
    apt-get install -y postgresql-client-common

    install -d -m 0755 /usr/share/keyrings
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg

    echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list

    apt-get update
    apt-get install -y postgresql-client-17
}

fn_configure_login_umask() {
    sed -i -r 's/^(UMASK\\s*)[0-9]+/\\1077/' /etc/login.defs
}

(redacted)() {
    chmod 555 /tmp/data/bin/*
    chown root:root /tmp/data/bin/*

    cp -fR /tmp/data/bin/* /bin
    cp -fR /tmp/data/etc/* /etc

    echo 'source /bin/(redacted)' >> /etc/profile
}

fn_set_sshd_keys() {
chmod 600 /etc/ssh/(redacted)*
}

fn_install_dotnet_dependencies() {
    apt-get update
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libc6 \
    libgcc-s1 \
    libicu78 \ # updated from 70 during u22->u26
    libssl3 \
    libstdc++6 \
    tzdata \
    zlib1g
}

fn_apt_common_tools() {
    apt-get install -y \
    jq wget curl
}

fn_install_kubectx_kubens() {
    local version="$1"
    [ -z "$version" ] && {
        echo "Version not provided"
        exit 1
    }

    cd $(mktemp -d)
    wget "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubectx_v${version}_linux_x86_64.tar.gz" -O kubectx.tgz
    wget "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubens_v${version}_linux_x86_64.tar.gz" -O kubens.tgz

    tar xvzpf kubectx.tgz
    tar xvzpf kubens.tgz
    chmod 0755 kubectx kubens
    chown root:root kubectx kubens
    mv kubectx kubens /usr/local/bin
    cd -
}

echo "RELEASES_KEY length: ${#RELEASES_KEY}"
if [ -z "$RELEASES_KEY" ]; then
  fn_red_echo "RELEASES_KEY is empty inside provisioner. Env var names present:"
  env | cut -d= -f1 | sort
  exit 1
fi


set -x
alias wget='wget --show-progress=off'
fn_setup_all || exit 1

mkdir -p /var/log/packer
sw_report | tee /var/log/packer/sw_report.md || exit 1
set +x
