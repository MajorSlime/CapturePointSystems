# CapturePointSystems Makefile

ifeq ($(wildcard config.mak),)
$(error Missing 'config.mak'; please run ./configure first)
endif

include config.mak

ZIP ?= zip
ACC ?= acc
BCC ?= bcc

PK3_NAME = CapturePointSystems.pk3

SRC_PATH=.
BUILD_DIR=build

ACC_FULLPATH = $(shell command -v $(ACC))
ACC_FLAGS += -i $(dir $(ACC_FULLPATH))

BCC_FULLPATH = $(shell command -v $(BCC))
BCC_FLAGS += -i $(dir $(BCC_FULLPATH))

include $(SRC_PATH)/rules.mak

include $(SRC_PATH)/Makefile.objs

dummy := $(call unnest-vars,, acs-y pk3-y)

acs-build = $(addprefix $(BUILD_DIR)/,$(acs-y))
pk3-build = $(addprefix $(BUILD_DIR)/,$(pk3-y))

all: pk3

$(BUILD_DIR)/.check-req-zip:
	$(if $(shell command -v $(ZIP) 2>/dev/null),,$(error Missing requirement; please install `zip`))
	$(call quiet-command,touch $@,,)

$(BUILD_DIR)/.check-req-acc:
	$(if $(ACC_FULLPATH),,$(error "Missing requirement; please install `acc` - can be found at https://github.com/ZDoom/acc"))
	$(call quiet-command,touch $@,,)

$(BUILD_DIR)/.check-req-bcc:
	$(if $(BCC_FULLPATH),,$(error "Missing requirement; please install `bcc` - can be found at https://github.com/zeta-group/zt-bcc"))
	$(call quiet-command,touch $@,,)

$(BUILD_DIR)/.check-config: config.mak
	$(call quiet-command,rm -rf $(BUILD_DIR)/pk3 && mkdir -p $(BUILD_DIR)/pk3,"MKDIR","$@")
	$(call quiet-command,touch $@,,)

$(BUILD_DIR)/pk3/acs/%.o: $(SRC_PATH)/pk3/acs/%.acs $(BUILD_DIR)/.check-req-acc $(BUILD_DIR)/.check-config
	$(call quiet-command,mkdir -p $(dir $@),,)
	$(call quiet-command,$(ACC) $(ACC_FLAGS) $< $@,"ACC","$@")

$(BUILD_DIR)/pk3/acs/%.o: $(SRC_PATH)/pk3/acs/%.bcs $(BUILD_DIR)/.check-req-bcc $(BUILD_DIR)/.check-config
	$(call quiet-command,mkdir -p $(dir $@),,)
	$(call quiet-command,$(BCC) $(BCC_FLAGS) $< $@,"BCC","$@")

$(BUILD_DIR)/pk3/%: $(SRC_PATH)/pk3/% $(BUILD_DIR)/.check-config
	$(call quiet-command,mkdir -p $(dir $@),,)
	$(call quiet-command,cp $< $@,"CP","$@")

$(BUILD_DIR)/$(PK3_NAME): $(acs-build) $(pk3-build) $(BUILD_DIR)/.check-req-zip
	$(call quiet-command,$(ZIP) -r $@ $(BUILD_DIR)/pk3,"ZIP","$@")

pk3: $(BUILD_DIR)/$(PK3_NAME)

acs: $(acs-build)

clean:
	rm -rf $(BUILD_DIR)/pk3
	rm -f $(BUILD_DIR)/$(PK3_NAME)
	rm -f $(BUILD_DIR)/.check-req-*
	rm -f $(BUILD_DIR)/.check-config
