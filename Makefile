PACKAGE = pve-microvm
VERSION = 0.1.0

# Resolve once inside the shared helper before changing TMPDIR. On this host the
# local default is /workspace/tmp/pve-microvm. PROJECT_TMP_BASE or compatible
# PROJECT_TMP_ROOT override it; CI uses runner/original TMPDIR/system temp.
ENV_HELPER := bash tools/pve-microvm-env.sh --exec

.PHONY: test-profile all build install install-internal clean deb kernel test

all: build

build:
	@echo "Nothing to compile (kernel built separately via CI or kernel/build-kernel.sh)"

test:
	$(ENV_HELPER) tests bash tests/run-tests.sh

test-profile:
	$(ENV_HELPER) tests bash scripts/test-profile.sh

kernel:
	$(ENV_HELPER) kernel bash kernel/build-kernel.sh --version 6.12.22

install:
	$(ENV_HELPER) install $(MAKE) install-internal

install-internal:
	# Patches
	install -d $(DESTDIR)/usr/share/pve-microvm/patches
	install -m 644 debian/patches/*.patch $(DESTDIR)/usr/share/pve-microvm/patches/

	# Patch tool and MicroVM module
	install -d $(DESTDIR)/usr/share/pve-microvm
	install -m 755 tools/pve-microvm-patch $(DESTDIR)/usr/share/pve-microvm/
	install -d $(DESTDIR)/usr/share/pve-microvm/lib
	install -m 644 tools/lib/project-tmp.sh $(DESTDIR)/usr/share/pve-microvm/lib/
	install -m 644 tools/pve-microvm-env.sh $(DESTDIR)/usr/share/pve-microvm/
	install -m 644 tools/MicroVM.pm $(DESTDIR)/usr/share/pve-microvm/
	install -m 644 doc/microvm-defaults.conf $(DESTDIR)/usr/share/pve-microvm/

	# OCI import tool
	install -d $(DESTDIR)/usr/bin
	install -m 755 tools/pve-oci-import $(DESTDIR)/usr/bin/

	# Kernel binary (if built)
	if [ -f "$(PVE_MICROVM_KERNEL_DIR)/vmlinuz-microvm" ]; then \
		install -m 644 $(PVE_MICROVM_KERNEL_DIR)/vmlinuz-microvm $(DESTDIR)/usr/share/pve-microvm/vmlinuz; \
	fi

	# Kernel build tooling
	install -d $(DESTDIR)/usr/share/pve-microvm/kernel
	install -m 755 kernel/build-kernel.sh $(DESTDIR)/usr/share/pve-microvm/kernel/
	install -m 644 kernel/base-x86_64-6.1.config $(DESTDIR)/usr/share/pve-microvm/kernel/
	install -m 644 tests/landlock-smoke.c $(DESTDIR)/usr/share/pve-microvm/kernel/
	install -m 755 kernel/check-landlock.sh $(DESTDIR)/usr/share/pve-microvm/kernel/
	install -m 755 kernel/check-erofs.sh $(DESTDIR)/usr/share/pve-microvm/kernel/
	install -m 644 kernel/pve-microvm-overlay.config $(DESTDIR)/usr/share/pve-microvm/kernel/

deb:
	$(ENV_HELPER) deb bash scripts/build-deb.sh

# Run only after jobs stop and retained reports are preserved.
clean:
	@test "$(CONFIRM_IDLE)" = yes || { echo 'Use make clean CONFIRM_IDLE=yes after stopping jobs'; exit 1; }
	$(ENV_HELPER) cleanup bash -c 'rm -rf "$$PROJECT_TMP_ROOT/cache" "$$PROJECT_TMP_ROOT/build" "$$PROJECT_TMP_ROOT/tests" "$$PROJECT_TMP_ROOT/logs" "$$PROJECT_TMP_ROOT/runs"'
