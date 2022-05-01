variable "output_directory" {
    type = string
}

variable "rancheros_version" {
    type = string
}

variable "ssh_key" {
    type = string
}

locals {
    vm_name = "rancheros"
    http_directory = "${path.root}/http"
    iso_url = "https://github.com/rancher/os/releases/download/v${var.rancheros_version}/rancheros.iso"
    iso_checksum = "none"
    shutdown_command = "echo 'rancher' | sudo -S shutdown -P now"
    boot_command = [
        "wget -P /tmp http://{{ .HTTPIP }}:{{ .HTTPPort }}/cloud-config.yml<enter><wait1s>",
        "sudo ros install -d /dev/sda -c /tmp/cloud-config.yml -a rancher.password=rancher -f<enter><wait30>"
    ]
}

source "virtualbox-iso" "rancheros" {
    boot_command = local.boot_command
    boot_wait = "50s"
    cpus = 2
    memory = 2048
    disk_size = 10240
    guest_os_type = "Linux_64"
    guest_additions_mode = "disable"
    hard_drive_interface = "sata"
    headless = false
    http_content = {
         "/cloud-config.yml" = templatefile("${path.root}/http/cloud-config.yml.pkrtpl", { ssh_key = var.ssh_key})
    }
    iso_checksum = local.iso_checksum
    iso_url = local.iso_url
    output_directory = "${var.output_directory}/packer-build/output/artifacts/${local.vm_name}/${var.rancheros_version}/virtualbox/"
    shutdown_command = local.shutdown_command
    ssh_port = 22
    ssh_timeout = "10000s"
    ssh_username = "rancher"
    ssh_password = "rancher"
    virtualbox_version_file = ".vbox_version"
    vm_name = "${local.vm_name}"
    vboxmanage = [
        ["modifyvm", "{{.Name}}", "--vram", "128"],
        ["modifyvm", "{{.Name}}", "--graphicscontroller", "vmsvga"],
        ["modifyvm", "{{.Name}}", "--vrde", "off"],
        ["modifyvm", "{{.Name}}", "--rtcuseutc", "on"]
    ]
}

build {
    name = "builder"

    sources = [
        "source.virtualbox-iso.rancheros",

    ]

   provisioner "shell" {
        scripts = [
            "${path.root}/setup-os-scripts/upgrade-os.sh"
        ] 
    }

    post-processors {
        post-processor "vagrant" {
          keep_input_artifact = false
          output = "${var.output_directory}/packer-build/output/boxes/${local.vm_name}/${var.rancheros_version}/{{.Provider}}/{{.BuildName}}.box"
          vagrantfile_template = "${path.root}/vagrantfile.rb"
        }
    }

}