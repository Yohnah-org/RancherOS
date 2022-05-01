CURRENT_BOX_VERSION := $(subst ", ,$(shell curl -sS "https://app.vagrantup.com/api/v1/box/Yohnah/RancherOS" | jq '.current_version.version'))
CURRENT_RANCHEROS_VERSION := $(shell curl -sS https://github.com/rancher/os/releases | grep "Release " | sed -e 's/<[^>]*>//g' | grep "v" | awk '{print $2}' | head -n 1 | sed 's/Release //g' | sed 's/ //g')
VAGRANT_KEY_CONTENT := $(shell curl -sS https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub)
OUTPUT_DIRECTORY := /tmp
DATETIME := $(shell date "+%Y-%m-%d %H:%M:%S")
PROVIDER := virtualbox

.PHONY: all version test clean_test clean

all: version build test

version: 
	@echo "========================="
	@echo Current RancherOS Version: $(CURRENT_RANCHEROS_VERSION)
	@echo Current Box Version: $(CURRENT_BOX_VERSION)
	@echo Provider: $(PROVIDER)
	@echo "========================="
	@echo ""

build:
ifeq ($(shell echo "$(CURRENT_RANCHEROS_VERSION)" | sed 's/ //g'),$(shell echo "$(CURRENT_BOX_VERSION)" | sed 's/ //g'))
	@echo Nothing to do
else
	cd packer; packer build -var "output_directory=/tmp" -var "rancheros_version=$(CURRENT_RANCHEROS_VERSION)" -var "ssh_key=$(VAGRANT_KEY_CONTENT)" -only builder.$(PROVIDER)-iso.rancheros packer.pkr.hcl
endif

test:
ifeq ($(shell echo "$(CURRENT_RANCHEROS_VERSION)" | sed 's/ //g'),$(shell echo "$(CURRENT_BOX_VERSION)" | sed 's/ //g'))
	@echo Nothing to do
else
	vagrant box add -f --name "testing-rancheros-box" $(OUTPUT_DIRECTORY)/packer-build/output/boxes/rancheros/$(CURRENT_RANCHEROS_VERSION)/$(PROVIDER)/rancheros.box
	mkdir -p $(OUTPUT_DIRECTORY)/vagrant-rancheros-test; cd $(OUTPUT_DIRECTORY)/vagrant-rancheros-test; vagrant init testing-rancheros-box; \
	vagrant up --provider $(PROVIDER); \
	vagrant ssh -- docker run hello-world; \
	vagrant destroy -f 
endif

clean_test:
	vagrant box remove testing-rancheros-box || true
	rm -fr $(OUTPUT_DIRECTORY)/vagrant-rancheros-test || true

upload:
ifeq ($(shell echo "$(CURRENT_DOCKER_VERSION)" | sed 's/ //g'),$(shell echo "$(CURRENT_BOX_VERSION)" | sed 's/ //g'))
	@echo Nothing to do
else
	cd Packer; packer build -var "input_directory=$(OUTPUT_DIRECTORY)" -var "version=$(CURRENT_RANCHEROS_VERSION)" -var "version_description=$(DATETIME)" -var "provider=$(PROVIDER)" upload-box-to-vagrant-cloud.pkr.hcl
endif

clean: clean_test
	rm -fr $(OUTPUT_DIRECTORY)/packer-build || true